class_name MJReconstruccion
extends MinijuegoBase
## Mesa de reconstrucción: el hueso se rompió en fragmentos que aparecen sueltos sobre la mesa,
## girados. El jugador los arrastra a su lugar sobre la silueta tenue del hueso.
## Clic izquierdo = arrastrar. Clic derecho = girar un cuarto de vuelta.
## Un fragmento se pega solo cuando está cerca de su lugar Y bien girado.
##
## Datos (JSON):
##   imagen      el hueso entero (PNG transparente)
##   mapa        un PNG del mismo tamaño donde cada fragmento está pintado de un color plano
##   instruccion texto de ayuda
##   lectura[]   líneas que se agregan al terminar

const MIN_PIXELS := 300          # una mancha de color más chica que esto no cuenta como fragmento
const FACTOR_SILUETA := 0.58     # cuánto del tablero ocupa la silueta
const SNAP := 36.0               # distancia a la que un fragmento "se pega" a su lugar
const TOLERANCIA_CLIC := 5       # píxeles de la imagen alrededor del dibujo donde todavía se puede agarrar

# Las piezas se calculan una sola vez por hueso y se guardan acá.
static var _cache: Dictionary = {}


class Pieza extends TextureRect:
	signal soltada(pieza)
	signal girada(pieza)
	var destino: Vector2 = Vector2.ZERO   # esquina de su lugar correcto (sin girar)
	var img: Image
	var escala: float = 1.0
	var giros: int = 0                    # cuartos de vuelta (crece sin límite; se usa módulo 4)
	var limite: Vector2 = Vector2.ZERO    # tamaño del tablero
	var colocada: bool = false
	var _arrastrando: bool = false
	var _agarre: Vector2 = Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	## Solo se puede agarrar donde hay dibujo (o muy cerca), no en los huecos transparentes.
	func _has_point(p: Vector2) -> bool:
		if img == null or escala <= 0.0:
			return true
		var x: int = int(p.x / escala)
		var y: int = int(p.y / escala)
		var t: int = MJReconstruccion.TOLERANCIA_CLIC
		for dy in [-t, 0, t]:
			for dx in [-t, 0, t]:
				var px: int = x + dx
				var py: int = y + dy
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					if img.get_pixel(px, py).a > 0.1:
						return true
		return false

	func cuartos() -> int:
		return posmod(giros, 4)

	## Mitad del ancho y del alto que ocupa a la vista (con el giro puesto).
	func extension() -> Vector2:
		var m: Vector2 = size * 0.5
		return Vector2(m.y, m.x) if cuartos() % 2 == 1 else m

	func mover_a(pos: Vector2) -> void:
		var centro: Vector2 = pos + size * 0.5
		var e: Vector2 = extension()
		centro.x = clampf(centro.x, e.x, maxf(e.x, limite.x - e.x))
		centro.y = clampf(centro.y, e.y, maxf(e.y, limite.y - e.y))
		position = centro - size * 0.5

	func girar() -> void:
		giros += 1
		var tween := create_tween()
		tween.tween_property(self, "rotation", giros * PI / 2.0, 0.12)
		mover_a(position)
		girada.emit(self)

	func _gui_input(event: InputEvent) -> void:
		if colocada:
			return
		var padre := get_parent_control()
		if padre == null:
			return
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_arrastrando = true
					_agarre = padre.get_local_mouse_position() - position
					move_to_front()
				elif _arrastrando:
					_arrastrando = false
					soltada.emit(self)
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				girar()
		elif event is InputEventMouseMotion and _arrastrando:
			mover_a(padre.get_local_mouse_position() - _agarre)


var _area: Control
var _piezas: Array[Pieza] = []
var _etq_estado: Label
var _boton: Button


func _construir() -> void:
	var caja := crear_marco_central(Vector2(1740, 900), true)
	caja.add_child(crear_titulo(str(datos.get("titulo", "Mesa de reconstrucción"))))
	caja.add_child(crear_label(
		str(datos.get("instruccion", "Arrastrá cada fragmento a su lugar. Clic derecho para girarlo.")),
		t_texto(), COLOR_APAGADO))

	_area = Control.new()
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.custom_minimum_size = Vector2(0, 400)
	_area.clip_contents = true
	caja.add_child(_area)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 20)
	caja.add_child(fila)
	_etq_estado = crear_label("", t_texto(), COLOR_TEXTO)
	poner_en_estado(_etq_estado, fila)
	_boton = crear_boton("Registrar resultado", 380)
	_boton.pressed.connect(_finalizar)
	poner_en_estado(_boton, fila)
	_actualizar_estado()

	_preparar_tablero()


func _preparar_tablero() -> void:
	# Esperamos a que el panel tenga su tamaño final. Mientras el minijuego está
	# oculto (por ejemplo, mientras Iris explica) Godot no calcula el tamaño,
	# así que también esperamos a que sea visible.
	await get_tree().process_frame
	await get_tree().process_frame
	while is_inside_tree() and (not is_visible_in_tree() or _area.size.x < 100.0):
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame

	var ruta_hueso: String = str(datos.get("imagen", ""))
	var ruta_mapa: String = str(datos.get("mapa", ""))
	var tex_hueso: Texture2D = cargar_textura(ruta_hueso)
	var tex_mapa: Texture2D = cargar_textura(ruta_mapa)
	if tex_hueso == null or tex_mapa == null:
		push_error("Reconstrucción: faltan 'imagen' o 'mapa' en el JSON, o no existen los archivos.")
		_etq_estado.text = "Faltan las imágenes de esta mesa."
		return
	var frag: Dictionary = _fragmentar(tex_hueso, tex_mapa, ruta_hueso + "|" + ruta_mapa)
	if frag.is_empty():
		push_error("Reconstrucción: el mapa no tiene fragmentos reconocibles.")
		_etq_estado.text = "El mapa de fragmentos no es válido."
		return

	var tablero: Vector2 = _area.size
	_agregar_fondo(tablero)

	# Silueta opaca negra del hueso entero, en el centro.
	var caja_hueso: Rect2i = frag["bbox"]
	var esc: float = minf(FACTOR_SILUETA * tablero.x / caja_hueso.size.x, FACTOR_SILUETA * tablero.y / caja_hueso.size.y)
	var tam_sil: Vector2 = Vector2(caja_hueso.size) * esc
	var origen: Vector2 = (tablero - tam_sil) / 2.0
	var recorte := AtlasTexture.new()
	recorte.atlas = tex_hueso
	recorte.region = Rect2(caja_hueso)
	var silueta := TextureRect.new()
	silueta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	silueta.stretch_mode = TextureRect.STRETCH_SCALE
	silueta.texture = recorte
	silueta.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	silueta.position = origen
	silueta.size = tam_sil
	silueta.modulate = Color(0, 0, 0, 1)
	silueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(silueta)

	# Las piezas
	var lista: Array = frag["piezas"]
	for d in lista:
		var im: Image = d["img"]
		var pieza := Pieza.new()
		pieza.texture = d["tex"]
		pieza.img = im
		pieza.escala = esc
		pieza.size = Vector2(im.get_width(), im.get_height()) * esc
		pieza.pivot_offset = pieza.size * 0.5
		pieza.limite = tablero
		pieza.destino = origen + Vector2(Vector2i(d["pos"]) - caja_hueso.position) * esc
		pieza.soltada.connect(_on_soltada)
		pieza.girada.connect(_on_girada)
		_piezas.append(pieza)
	_repartir(Rect2(origen, tam_sil), tablero)
	for pieza in _piezas:
		_area.add_child(pieza)
	_actualizar_estado()


func _agregar_fondo(tam: Vector2) -> void:
	var fondo := Panel.new()
	fondo.add_theme_stylebox_override("panel", crear_estilo(Color(0.03, 0.05, 0.08, 0.55), COLOR_BORDE, 6, 0))
	fondo.position = Vector2.ZERO
	fondo.size = tam
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(fondo)


## Reparte las piezas por la mesa con giros al azar, evitando amontonarlas y evitando la silueta.
func _repartir(rect_silueta: Rect2, tablero: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(datos.get("id", "reconstruccion")) + str(datos.get("mapa", "")))
	var orden: Array[Pieza] = _piezas.duplicate()
	orden.sort_custom(func(a: Pieza, b: Pieza): return a.size.x * a.size.y > b.size.x * b.size.y)
	var ocupado: Array[Rect2] = []
	for pieza in orden:
		pieza.giros = rng.randi_range(0, 3)
		pieza.rotation = pieza.giros * PI / 2.0
		var e: Vector2 = pieza.extension()
		var mejor: Rect2 = Rect2()
		var mejor_puntaje: float = INF
		for intento in range(400):
			var cx: float = rng.randf_range(e.x, maxf(e.x, tablero.x - e.x))
			var cy: float = rng.randf_range(e.y, maxf(e.y, tablero.y - e.y))
			var r := Rect2(Vector2(cx, cy) - e, e * 2.0)
			var puntaje: float = 0.0
			for o in ocupado:
				if r.grow(8.0).intersects(o):
					puntaje += 3.0 * r.grow(8.0).intersection(o).get_area()
			if r.intersects(rect_silueta):
				puntaje += 0.6 * r.intersection(rect_silueta).get_area()
			if puntaje < mejor_puntaje:
				mejor_puntaje = puntaje
				mejor = r
				if puntaje < 1.0:
					break
		ocupado.append(mejor)
		pieza.mover_a(mejor.position + mejor.size * 0.5 - pieza.size * 0.5)


# ---------------------------------------------------------------
# FRAGMENTAR: de la imagen del hueso y el mapa de colores salen las piezas
# ---------------------------------------------------------------

@warning_ignore("integer_division")
static func _fragmentar(tex_hueso: Texture2D, tex_mapa: Texture2D, clave: String) -> Dictionary:
	if _cache.has(clave):
		return _cache[clave]
	var hueso: Image = tex_hueso.get_image()
	if hueso.is_compressed():
		hueso.decompress()
	hueso.convert(Image.FORMAT_RGBA8)
	var mapa: Image = tex_mapa.get_image()
	if mapa.is_compressed():
		mapa.decompress()
	mapa.convert(Image.FORMAT_RGBA8)
	var w: int = hueso.get_width()
	var h: int = hueso.get_height()
	if mapa.get_width() != w or mapa.get_height() != h:
		mapa.resize(w, h, Image.INTERPOLATE_NEAREST)
	var dh: PackedByteArray = hueso.get_data()
	var dm: PackedByteArray = mapa.get_data()

	# 1) Color del mapa en cada píxel del hueso, y cuántos píxeles tiene cada color.
	#    Los colores se redondean un poco, así un 129 en vez de 128 no es un problema.
	var color_px := PackedInt32Array()
	color_px.resize(w * h)
	color_px.fill(-1)
	var cuenta: Dictionary = {}
	var x0: int = w
	var y0: int = h
	var x1: int = -1
	var y1: int = -1
	for y in range(h):
		var base: int = y * w
		for x in range(w):
			var i: int = base + x
			if dh[i * 4 + 3] < 16:
				continue
			if x < x0:
				x0 = x
			if x > x1:
				x1 = x
			if y < y0:
				y0 = y
			if y > y1:
				y1 = y
			var j: int = i * 4
			if dm[j + 3] > 200:
				var k: int = (((dm[j] + 16) >> 5) << 8) | (((dm[j + 1] + 16) >> 5) << 4) | ((dm[j + 2] + 16) >> 5)
				color_px[i] = k
				cuenta[k] = int(cuenta.get(k, 0)) + 1
	if x1 < 0:
		return {}

	# 2) Los colores con suficientes píxeles son fragmentos.
	var colores: Array = []
	for k in cuenta:
		if int(cuenta[k]) >= MIN_PIXELS:
			colores.append(k)
	if colores.is_empty():
		return {}
	colores.sort()
	var indice_de: Dictionary = {}
	for n in range(colores.size()):
		indice_de[colores[n]] = n
	var total: int = colores.size()

	# 3) A cada píxel del hueso le toca un fragmento. Los que quedaron sin color
	#    (bordes, grietas finas) se reparten al fragmento vecino.
	var etiqueta := PackedInt32Array()
	etiqueta.resize(w * h)
	etiqueta.fill(-1)
	var sueltos := PackedInt32Array()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i: int = y * w + x
			if dh[i * 4 + 3] < 16:
				continue
			var k: int = color_px[i]
			if indice_de.has(k):
				etiqueta[i] = int(indice_de[k])
			else:
				sueltos.append(i)
	for pasada in range(12):
		if sueltos.is_empty():
			break
		var nuevos: Array[Vector2i] = []
		var quedan := PackedInt32Array()
		for i in sueltos:
			var x: int = i % w
			var y: int = i / w
			var etq: int = -1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						var v: int = etiqueta[ny * w + nx]
						if v >= 0:
							etq = v
			if etq >= 0:
				nuevos.append(Vector2i(i, etq))
			else:
				quedan.append(i)
		for a in nuevos:
			etiqueta[a.x] = a.y
		sueltos = quedan

	# 4) Rectángulo que ocupa cada fragmento.
	var bx0 := PackedInt32Array()
	var by0 := PackedInt32Array()
	var bx1 := PackedInt32Array()
	var by1 := PackedInt32Array()
	for n in range(total):
		bx0.append(w)
		by0.append(h)
		bx1.append(-1)
		by1.append(-1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var e: int = etiqueta[y * w + x]
			if e < 0:
				continue
			if x < bx0[e]:
				bx0[e] = x
			if x > bx1[e]:
				bx1[e] = x
			if y < by0[e]:
				by0[e] = y
			if y > by1[e]:
				by1[e] = y

	# 5) Una imagen recortada por fragmento.
	var piezas: Array = []
	for e in range(total):
		var pw: int = bx1[e] - bx0[e] + 1
		var ph: int = by1[e] - by0[e] + 1
		var bytes := PackedByteArray()
		bytes.resize(pw * ph * 4)
		bytes.fill(0)
		for y in range(ph):
			for x in range(pw):
				var i: int = (by0[e] + y) * w + bx0[e] + x
				if etiqueta[i] == e:
					var s: int = i * 4
					var d: int = (y * pw + x) * 4
					bytes[d] = dh[s]
					bytes[d + 1] = dh[s + 1]
					bytes[d + 2] = dh[s + 2]
					bytes[d + 3] = dh[s + 3]
		var im: Image = Image.create_from_data(pw, ph, false, Image.FORMAT_RGBA8, bytes)
		piezas.append({
			"img": im,
			"tex": ImageTexture.create_from_image(im),
			"pos": Vector2i(bx0[e], by0[e]),
		})

	var resultado: Dictionary = {
		"bbox": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1),
		"piezas": piezas,
	}
	_cache[clave] = resultado
	return resultado


# ---------------------------------------------------------------
# JUEGO
# ---------------------------------------------------------------

func _on_soltada(pieza: Pieza) -> void:
	if pieza.colocada:
		return
	if pieza.cuartos() != 0:
		return
	if pieza.position.distance_to(pieza.destino) > SNAP:
		return
	pieza.position = pieza.destino
	pieza.colocada = true
	pieza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pieza.modulate = Color(1.7, 1.7, 1.7)
	var tween := create_tween()
	tween.tween_property(pieza, "modulate", Color.WHITE, 0.4)
	_actualizar_estado()


## Si al girarla queda justo en su lugar, también se pega.
func _on_girada(pieza: Pieza) -> void:
	if pieza.cuartos() == 0:
		_on_soltada(pieza)


func _colocadas() -> int:
	var n: int = 0
	for p in _piezas:
		if p.colocada:
			n += 1
	return n


func _completo() -> bool:
	return _piezas.size() > 0 and _colocadas() >= _piezas.size()


func _actualizar_estado() -> void:
	var total: int = _piezas.size()
	var puestas: int = _colocadas()
	if total > 0 and puestas >= total:
		_etq_estado.text = "Fragmentos ubicados: %d de %d. ¡Completo!" % [puestas, total]
	else:
		_etq_estado.text = "Fragmentos ubicados: %d de %d" % [puestas, total]
	# El botón solo se puede usar con el hueso completo.
	_boton.disabled = not _completo()


func _finalizar() -> void:
	if not _completo():
		return
	var lineas: Array = []
	for texto in datos.get("lectura", []):
		lineas.append(str(texto))
	terminado.emit({
		"estacion": "reconstruccion",
		"util": bool(datos.get("util", true)),
		"calidad": 1.0,
		"datos": lineas,
	})
