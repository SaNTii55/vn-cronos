class_name CharacterStage
extends Control

const CARPETA_PERSONAJES := "res://assets/personajes/"

# --- Animaciones: cambiá estos números a gusto ---
const ENTRADA_DISTANCIA := 160.0     # desde cuántos píxeles más afuera entra un personaje
const ENTRADA_DURACION := 0.35       # segundos que tarda en entrar
const SALIDA_DISTANCIA := 160.0      # cuántos píxeles se desliza hacia afuera al irse
const SALIDA_DURACION := 0.30        # segundos que tarda en irse
const DESVANECER_DURACION := 0.20    # cuando se oculta a todos juntos (cierre de la caja, línea centrada)
const CRUCE_DURACION := 0.45         # segundos que tarda un personaje en cambiar de lado
# --------------------------------------------------

# Personajes que miran de frente: no se espejan cuando están a la derecha.
# El resto se supone que mira hacia la derecha, y se espeja al ir del lado derecho.
const DE_FRENTE := ["archiv"]

var sprite_izquierda: TextureRect
var sprite_derecha: TextureRect

var personaje_izquierda: String = ""
var personaje_derecha: String = ""

var posicion_inicial_izquierda: Vector2
var posicion_inicial_derecha: Vector2

var tween_mover: Tween = null
var cache_personajes: Dictionary = {}

# Sprite que está sobre el menú de opciones (mientras el menú está abierto)
var _sprite_foco: TextureRect = null

# Animación en curso de cada sprite (entrada o cambio de lado)
var _anims: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	sprite_izquierda = _crear_sprite()
	sprite_derecha = _crear_sprite()

	await get_tree().process_frame
	_calcular_posiciones_iniciales()
	sprite_izquierda.position = posicion_inicial_izquierda
	sprite_derecha.position = posicion_inicial_derecha

func _calcular_posiciones_iniciales() -> void:
	var borde_superior_caja = size.y - UIEstilo.ALTO_CAJA_DIALOGO - UIEstilo.MARGEN_INFERIOR
	var y_personaje = borde_superior_caja - UIEstilo.ALTO_SPRITE + UIEstilo.SUPERPOSICION

	var x_izquierda = UIEstilo.MARGEN_LATERAL + 40.0
	var x_derecha = size.x - UIEstilo.MARGEN_LATERAL - 40.0 - UIEstilo.ANCHO_SPRITE

	posicion_inicial_izquierda = Vector2(x_izquierda, y_personaje)
	posicion_inicial_derecha = Vector2(x_derecha, y_personaje)

func _crear_sprite() -> TextureRect:
	var rect := TextureRect.new()
	rect.size = Vector2(UIEstilo.ANCHO_SPRITE, UIEstilo.ALTO_SPRITE)
	rect.pivot_offset = rect.size / 2.0   # para el giro al cambiar de lado
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.visible = false
	add_child(rect)
	return rect

func _obtener_personaje(nombre: String) -> CharacterData:
	var clave = nombre.to_lower()
	if cache_personajes.has(clave):
		return cache_personajes[clave]

	var ruta = CARPETA_PERSONAJES + clave + ".tres"
	var datos: CharacterData = null
	if ResourceLoader.exists(ruta):
		datos = load(ruta) as CharacterData
	else:
		push_warning("No se encontró el personaje: " + ruta)

	cache_personajes[clave] = datos
	return datos

func reiniciar_lados() -> void:
	personaje_izquierda = ""
	personaje_derecha = ""
	ocultar_todos()

func _lado_de(nombre_personaje: String) -> String:
	# Si ya está en escena, se queda en su lado.
	if personaje_izquierda == nombre_personaje:
		return "izquierda"
	if personaje_derecha == nombre_personaje:
		return "derecha"
	# Si es nuevo, ocupa el primer lado libre.
	if personaje_izquierda == "":
		personaje_izquierda = nombre_personaje
		return "izquierda"
	if personaje_derecha == "":
		personaje_derecha = nombre_personaje
		return "derecha"
	return "izquierda"

# Saca a un personaje de escena (su lado queda libre). Se desliza hacia afuera y se desvanece.
func retirar(nombre_personaje: String) -> void:
	var clave := nombre_personaje.to_lower()
	if clave == "":
		return
	if personaje_izquierda.to_lower() == clave:
		personaje_izquierda = ""
		_salir(sprite_izquierda, -1.0)
	elif personaje_derecha.to_lower() == clave:
		personaje_derecha = ""
		_salir(sprite_derecha, 1.0)

# Intercambia de lado a los dos personajes (nombres y estado visual de los sprites).
# Cada personaje cruza al lado opuesto; si cambia de orientación, da un giro al pasar.
func _intercambiar_lados() -> void:
	_detener_anim(sprite_izquierda)
	_detener_anim(sprite_derecha)

	# Dónde se ve hoy cada uno, para que el movimiento arranque desde ahí.
	var pos_izq: Vector2 = sprite_izquierda.position
	var pos_der: Vector2 = sprite_derecha.position
	var flip_izq: bool = sprite_izquierda.flip_h
	var flip_der: bool = sprite_derecha.flip_h

	var nombre_tmp: String = personaje_izquierda
	personaje_izquierda = personaje_derecha
	personaje_derecha = nombre_tmp

	var tex_tmp: Texture2D = sprite_izquierda.texture
	var vis_tmp: bool = sprite_izquierda.visible
	var mod_tmp: Color = sprite_izquierda.modulate
	sprite_izquierda.texture = sprite_derecha.texture
	sprite_izquierda.visible = sprite_derecha.visible
	sprite_izquierda.modulate = sprite_derecha.modulate
	sprite_derecha.texture = tex_tmp
	sprite_derecha.visible = vis_tmp
	sprite_derecha.modulate = mod_tmp
	_actualizar_orientacion()

	# El que ahora está en el lado izquierdo venía del derecho, y al revés.
	if sprite_izquierda.visible:
		_animar_cruce(sprite_izquierda, pos_der, flip_der, sprite_izquierda.flip_h)
	if sprite_derecha.visible:
		_animar_cruce(sprite_derecha, pos_izq, flip_izq, sprite_derecha.flip_h)

# Fuerza a un personaje a un lado ("izquierda" o "derecha").
# Si ya estaba en escena en el otro lado, se pasa al lado pedido (y el otro, al opuesto).
# Si es nuevo y el lado está ocupado, el que estaba pasa al lado opuesto si está libre.
func _forzar_lado(nombre_personaje: String, lado: String) -> void:
	var en_izq: bool = personaje_izquierda == nombre_personaje
	var en_der: bool = personaje_derecha == nombre_personaje

	if lado == "izquierda":
		if en_izq:
			return
		if en_der:
			_intercambiar_lados()
			return
		# Es nuevo en escena
		if personaje_izquierda != "" and personaje_derecha == "":
			_intercambiar_lados()   # el que estaba se va a la derecha
		personaje_izquierda = nombre_personaje
	elif lado == "derecha":
		if en_der:
			return
		if en_izq:
			_intercambiar_lados()
			return
		if personaje_derecha != "" and personaje_izquierda == "":
			_intercambiar_lados()   # el que estaba se va a la izquierda
		personaje_derecha = nombre_personaje

# Los que van a la derecha se espejan para mirar al centro (salvo los de frente).
# Un sprite que está dando el giro del cambio de lado conserva su orientación hasta terminarlo.
func _actualizar_orientacion() -> void:
	if not bool(sprite_izquierda.get_meta("girando", false)):
		sprite_izquierda.flip_h = false
	if not bool(sprite_derecha.get_meta("girando", false)):
		sprite_derecha.flip_h = not DE_FRENTE.has(personaje_derecha.to_lower())

# Busca el sprite de un personaje que ya está en escena, sin asignarle lado.
func _sprite_en_escena(nombre_personaje: String) -> TextureRect:
	if nombre_personaje == "":
		return null
	var clave = nombre_personaje.to_lower()
	if clave == personaje_izquierda.to_lower():
		return sprite_izquierda
	if clave == personaje_derecha.to_lower():
		return sprite_derecha
	return null

# lado_forzado: "", "izquierda" o "derecha" (campo "lado" de la línea del JSON).
func mostrar(nombre_personaje: String, expresion: int, lado_forzado: String = "") -> void:
	if nombre_personaje == "":
		ocultar_todos()
		return

	var datos = _obtener_personaje(nombre_personaje)
	if not datos or not datos.textura:
		return

	if lado_forzado != "":
		_forzar_lado(nombre_personaje, lado_forzado)

	var es_derecha = _lado_de(nombre_personaje) == "derecha"
	var activo = sprite_derecha if es_derecha else sprite_izquierda
	var inactivo = sprite_izquierda if es_derecha else sprite_derecha
	var nombre_del_otro = personaje_izquierda if es_derecha else personaje_derecha

	var region = GrillaExpresiones.obtener_region(expresion, datos.textura.get_width(), datos.textura.get_height())

	var atlas := activo.texture as AtlasTexture
	if not atlas:
		atlas = AtlasTexture.new()
		activo.texture = atlas
	atlas.atlas = datos.textura
	atlas.region = region

	# Si no estaban a la vista, entran con animación.
	var activo_entra: bool = not activo.visible
	var inactivo_entra: bool = nombre_del_otro != "" and not inactivo.visible

	activo.visible = true
	activo.modulate = Color(1, 1, 1, 1)
	_actualizar_orientacion()

	if nombre_del_otro != "":
		inactivo.visible = true
		inactivo.modulate = Color(0.5, 0.5, 0.5, 1)
	else:
		inactivo.visible = false

	# El que habla queda por delante (importa cuando dos se cruzan).
	move_child(activo, -1)

	if activo_entra:
		_animar_entrada(activo)
	if inactivo_entra:
		_animar_entrada(inactivo)

# Oculta a los dos personajes a la vez (se desvanecen sin moverse).
func ocultar_todos() -> void:
	_salir(sprite_izquierda, 0.0)
	_salir(sprite_derecha, 0.0)

# ---------------------------------------------------------------
# ANIMACIONES
# ---------------------------------------------------------------

func _posicion_lugar(sprite: TextureRect) -> Vector2:
	return posicion_inicial_derecha if sprite == sprite_derecha else posicion_inicial_izquierda

# Cancela la animación de un sprite y lo deja derecho (sin achatar).
func _detener_anim(sprite: TextureRect) -> void:
	if _anims.has(sprite):
		var t: Tween = _anims[sprite]
		if t != null and t.is_valid():
			t.kill()
		_anims.erase(sprite)
	sprite.scale = Vector2.ONE
	sprite.set_meta("girando", false)

# Entra desde el borde de su lado (el izquierdo desde la izquierda, el derecho desde la derecha).
func _animar_entrada(sprite: TextureRect) -> void:
	_detener_anim(sprite)
	var destino: Vector2 = _posicion_lugar(sprite)
	var hacia_afuera: float = -1.0 if sprite == sprite_izquierda else 1.0
	sprite.position = destino + Vector2(hacia_afuera * ENTRADA_DISTANCIA, 0.0)
	var alfa_final: float = sprite.modulate.a
	sprite.modulate.a = 0.0

	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "position", destino, ENTRADA_DURACION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "modulate:a", alfa_final, ENTRADA_DURACION)
	_anims[sprite] = t

# Cruza desde donde estaba hasta su lugar. Si cambia de orientación, se achata,
# se espeja a mitad de camino y se vuelve a abrir (un giro "de moneda").
func _animar_cruce(sprite: TextureRect, desde: Vector2, flip_inicio: bool, flip_final: bool) -> void:
	_detener_anim(sprite)
	var destino: Vector2 = _posicion_lugar(sprite)
	sprite.position = desde

	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "position", destino, CRUCE_DURACION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if flip_inicio != flip_final:
		var mitad: float = CRUCE_DURACION * 0.5
		sprite.flip_h = flip_inicio
		sprite.set_meta("girando", true)
		t.tween_property(sprite, "scale:x", 0.0, mitad)
		t.tween_callback(func(): sprite.flip_h = flip_final).set_delay(mitad)
		t.tween_property(sprite, "scale:x", 1.0, mitad).set_delay(mitad)
		t.tween_callback(func(): sprite.set_meta("girando", false)).set_delay(CRUCE_DURACION)
	_anims[sprite] = t

# Saca un sprite de la vista. direccion: -1 = hacia la izquierda, 1 = hacia la derecha,
# 0 = solo se desvanece. La salida la hace una copia, así el sprite real queda libre
# enseguida para otro personaje (y no se corta la animación si entra uno nuevo).
func _salir(sprite: TextureRect, direccion: float) -> void:
	if sprite.visible:
		var copia := _crear_copia(sprite)
		var duracion: float = SALIDA_DURACION if direccion != 0.0 else DESVANECER_DURACION
		var t := create_tween().set_parallel(true)
		if direccion != 0.0:
			t.tween_property(copia, "position:x", copia.position.x + direccion * SALIDA_DISTANCIA, duracion).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(copia, "modulate:a", 0.0, duracion)
		t.chain().tween_callback(copia.queue_free)
	_detener_anim(sprite)
	sprite.visible = false

func _crear_copia(sprite: TextureRect) -> TextureRect:
	var copia := TextureRect.new()
	copia.stretch_mode = sprite.stretch_mode
	copia.texture = sprite.texture.duplicate()   # copia propia: el sprite real puede cambiar de región
	copia.flip_h = sprite.flip_h
	copia.size = sprite.size
	copia.pivot_offset = sprite.pivot_offset
	copia.position = sprite.position
	copia.scale = sprite.scale
	copia.modulate = sprite.modulate
	copia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(copia)
	return copia

# Abre el "modo opciones": el personaje que pregunta sube al centro, apoyado sobre
# el borde del menú y con colores normales. El otro se desvanece y se oculta.
func entrar_modo_opciones(nombre_personaje: String, borde_y: float) -> void:
	_sprite_foco = _sprite_en_escena(nombre_personaje)

	# Si algún personaje todavía se estaba moviendo, se corta esa animación.
	_detener_anim(sprite_izquierda)
	_detener_anim(sprite_derecha)
	_actualizar_orientacion()

	if tween_mover and tween_mover.is_running():
		tween_mover.kill()
	tween_mover = create_tween().set_parallel(true)
	var hay_animacion := false

	for sprite in [sprite_izquierda, sprite_derecha]:
		if not sprite.visible:
			continue
		if sprite == _sprite_foco:
			var y = maxf(0.0, borde_y - UIEstilo.ALTO_SPRITE + UIEstilo.SUPERPOSICION)
			var destino = Vector2(size.x / 2 - UIEstilo.ANCHO_SPRITE / 2, y)
			tween_mover.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.4)
			tween_mover.tween_property(sprite, "position", destino, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			tween_mover.tween_property(sprite, "modulate:a", 0.0, 0.3)
			tween_mover.tween_callback(sprite.hide).set_delay(0.3)
		hay_animacion = true

	if not hay_animacion:
		tween_mover.kill()
		return
	await tween_mover.finished

# Cierra el "modo opciones": el personaje vuelve a su lugar. El otro reaparece
# recién cuando la siguiente línea del JSON lo muestre (con mostrar()).
func salir_modo_opciones() -> void:
	if _sprite_foco == null:
		return

	var destino = posicion_inicial_derecha if _sprite_foco == sprite_derecha else posicion_inicial_izquierda

	if tween_mover and tween_mover.is_running():
		tween_mover.kill()
	tween_mover = create_tween()
	tween_mover.tween_property(_sprite_foco, "position", destino, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sprite_foco = null
	await tween_mover.finished
