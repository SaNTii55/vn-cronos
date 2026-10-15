extends Control
## Laboratorio como escena especial (se abre desde un JSON con "escena_especial": "laboratorio").
## Muestra el fondo del laboratorio (el que ya puso main) con tres zonas clicables, una por estación.
## - Modo guiado (la primera evidencia): una sola zona habilitada a la vez, en orden, con pulso.
## - Modo libre: las tres zonas habilitadas; el jugador elige el orden y cuándo terminar.
## Los diálogos de orientación, instrucción y devolución son JSON cortos que se reproducen
## con main.reproducir_dialogo(). Todos son opcionales: si el archivo no existe, se salta.
## En el modo guiado, Iris orienta hacia la siguiente estación; al abrirla, explica cómo
## trabajar con ella y los controles quedan bloqueados hasta que termina de hablar.
##
## Campos de la línea del JSON que lo abre:
##   "id_evidencia": "hueso_vaca"   (opcional, es el valor por defecto)
##   "guiado": true/false           (opcional; si falta, se usa "laboratorio_guiado" de la ficha)

signal terminada

const ID_EVIDENCIA_DEFECTO := "hueso_vaca"
const CARPETA_DIALOGOS := "res://data/laboratorio/"

# Orden del modo guiado
const ORDEN_GUIADO := ["reconstruccion", "composicion", "microscopio"]

# Zonas clicables sobre el fondo, en fracciones de la pantalla (0 a 1):
# Rect2(x, y, ancho, alto). Ajustalas a ojo; con DEPURAR = true se dibujan siempre.
const ZONAS := {
	"reconstruccion": Rect2(0.41, 0.42, 0.255, 0.36), # camilla central con los brazos robóticos
	"composicion": Rect2(0.19, 0.56, 0.22, 0.27),     # terminal con la plaqueta que brilla (izquierda)
	"microscopio": Rect2(0.665, 0.55, 0.14, 0.30),    # microscopio (derecha)
}
const DEPURAR := false

# Fondo propio de cada estación (cuando no existe la imagen, se ve un gris provisorio)
const FONDOS_ESTACION := {
	"composicion": "res://assets/backgrounds/estaciones/Composicion.png",
	"microscopio": "res://assets/backgrounds/estaciones/Microscopio.png",
	"reconstruccion": "res://assets/backgrounds/estaciones/Reconstruccion.png",
}
const COLOR_FONDO_PROVISORIO := Color(0.20, 0.21, 0.24)

# Duración (en segundos) del difuminado entre el laboratorio y cada minijuego
const DURACION_FUNDIDO := 0.35

signal _minijuego_cerrado


class Zona extends Control:
	signal elegida(estacion: String)

	const CIAN := Color(0.30, 0.85, 0.95)
	const VERDE := Color(0.45, 0.85, 0.50)

	var estacion: String = ""
	var titulo: String = ""
	var estado: String = "libre"   # libre, guiada, bloqueada, hecha
	var depurar: bool = false
	var _hover: bool = false
	var _pulso: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_on_entrar)
		mouse_exited.connect(_on_salir)
		set_process(false)

	func set_estado(nuevo: String) -> void:
		estado = nuevo
		set_process(estado == "guiada")
		var activa: bool = estado == "libre" or estado == "guiada"
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if activa else Control.CURSOR_ARROW
		queue_redraw()

	func _on_entrar() -> void:
		_hover = true
		queue_redraw()

	func _on_salir() -> void:
		_hover = false
		queue_redraw()

	func _process(delta: float) -> void:
		_pulso += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if estado == "libre" or estado == "guiada":
				accept_event()
				elegida.emit(estacion)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match estado:
			"guiada":
				var a: float = 0.5 + 0.5 * sin(_pulso * 4.0)
				draw_rect(r, Color(CIAN, 0.08 + 0.14 * a), true)
				draw_rect(r, Color(CIAN, 0.55 + 0.45 * a), false, 4.0)
				_etiqueta(titulo, CIAN)
			"libre":
				if _hover:
					draw_rect(r, Color(CIAN, 0.20), true)
					draw_rect(r, Color(CIAN, 1.0), false, 4.0)
					_etiqueta(titulo, CIAN)
				else:
					draw_rect(r, Color(CIAN, 0.28), false, 2.0)
			"hecha":
				draw_rect(r, Color(VERDE, 0.40), false, 3.0)
				_etiqueta(titulo + "  (hecho)", VERDE)
		if depurar:
			draw_rect(r, Color(1, 1, 0, 0.9), false, 2.0)
			_etiqueta(estacion, Color(1, 1, 0))

	func _etiqueta(texto: String, color: Color) -> void:
		var fuente: Font = get_theme_default_font()
		var tam: int = 30
		var ancho: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var caja := Rect2(8, 8, ancho + 24, tam + 16)
		draw_rect(caja, Color(0.05, 0.07, 0.12, 0.88), true)
		draw_rect(caja, color, false, 2.0)
		draw_string(fuente, Vector2(20, 8 + tam + 1), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0.95, 0.95, 0.98))


var _p: Node
var _id: String = ""
var _ficha: Dictionary = {}
var _guiado: bool = false
var _ocupado: bool = true
var _termino: bool = false
var _guia_dicha: Dictionary = {}
var _ultimo_resultado: Dictionary = {}

var _zonas: Dictionary = {}
var _capa_estacion: Control
var _fondo_color: ColorRect
var _fondo_imagen: TextureRect
var _etq_estacion: Label
var _hud: Control
var _etq_muestras: Label
var _boton_terminar: Button
var _velo: ColorRect   # pantalla negra que se desvanece en las transiciones


## Lo llama main justo después de agregar la escena.
func iniciar(principal: Node, linea: Dictionary) -> void:
	_p = principal
	_id = str(linea.get("id_evidencia", ID_EVIDENCIA_DEFECTO))
	_ficha = Evidencias.ficha(_id)

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Espera un cuadro para que main ya esté esperando la señal "terminada".
	await get_tree().process_frame

	if _ficha.is_empty():
		push_error("Laboratorio: no se pudo cargar la ficha " + _id)
		_terminar()
		return

	_guiado = bool(linea.get("guiado", _ficha.get("laboratorio_guiado", false)))
	_construir()
	await _mostrar_hub()


# ---------------------------------------------------------------
# CONSTRUCCIÓN
# ---------------------------------------------------------------

func _construir() -> void:
	# Fondo de estación (arriba de todo lo demás del laboratorio, abajo de los minijuegos)
	_capa_estacion = Control.new()
	_capa_estacion.mouse_filter = Control.MOUSE_FILTER_STOP
	_capa_estacion.visible = false
	add_child(_capa_estacion)
	_capa_estacion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_fondo_color = ColorRect.new()
	_fondo_color.color = COLOR_FONDO_PROVISORIO
	_fondo_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_estacion.add_child(_fondo_color)
	_fondo_color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_fondo_imagen = TextureRect.new()
	_fondo_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fondo_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fondo_imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_estacion.add_child(_fondo_imagen)
	_fondo_imagen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_etq_estacion = MinijuegoBase.crear_label("", MinijuegoBase.t_titulo(), MinijuegoBase.COLOR_APAGADO)
	_etq_estacion.autowrap_mode = TextServer.AUTOWRAP_OFF
	_etq_estacion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etq_estacion.position = Vector2(60, 40)
	_capa_estacion.add_child(_etq_estacion)

	# Zonas clicables
	for estacion: String in ZONAS:
		var r: Rect2 = ZONAS[estacion]
		var z := Zona.new()
		z.estacion = estacion
		z.titulo = str(Evidencias.NOMBRES_ESTACION.get(estacion, estacion))
		z.depurar = DEPURAR
		add_child(z)
		z.anchor_left = r.position.x
		z.anchor_top = r.position.y
		z.anchor_right = r.end.x
		z.anchor_bottom = r.end.y
		z.offset_left = 0.0
		z.offset_top = 0.0
		z.offset_right = 0.0
		z.offset_bottom = 0.0
		z.elegida.connect(_on_zona_elegida)
		_zonas[estacion] = z

	# Indicador de muestras y botón de ficha (arriba a la izquierda)
	var panel := MinijuegoBase.crear_panel(Vector2(0, 0))
	_hud = panel
	add_child(panel)
	panel.position = Vector2(30, 24)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)
	_etq_muestras = MinijuegoBase.crear_label("")
	_etq_muestras.autowrap_mode = TextServer.AUTOWRAP_OFF
	caja.add_child(_etq_muestras)
	var ficha := MinijuegoBase.crear_boton("Ficha", 220)
	ficha.pressed.connect(_abrir_ficha)
	caja.add_child(ficha)

	# Botón para terminar (solo modo libre)
	_boton_terminar = MinijuegoBase.crear_boton("Terminar análisis", 380)
	_boton_terminar.visible = false
	_boton_terminar.pressed.connect(_on_terminar_pulsado)
	add_child(_boton_terminar)
	_boton_terminar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_boton_terminar.offset_left = -420.0
	_boton_terminar.offset_right = -40.0
	_boton_terminar.offset_top = -110.0
	_boton_terminar.offset_bottom = -110.0 + UIEstilo.ALTO_BOTON

	# Velo negro para el difuminado. Va en su propia capa, por encima de todo.
	var capa_velo := CanvasLayer.new()
	capa_velo.layer = 90
	add_child(capa_velo)
	_velo = ColorRect.new()
	_velo.color = Color.BLACK
	_velo.modulate.a = 0.0
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_velo.add_child(_velo)
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# Pasa a negro (a_negro = true) o vuelve a mostrar la pantalla (a_negro = false).
# Mientras la pantalla está oscura o en transición, los clics no llegan a nada.
func _fundido(a_negro: bool) -> void:
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_velo, "modulate:a", 1.0 if a_negro else 0.0, DURACION_FUNDIDO)
	await tween.finished
	if not a_negro:
		_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---------------------------------------------------------------
# HUB (la vista con las tres zonas)
# ---------------------------------------------------------------

func _siguiente_guiada() -> String:
	for estacion: String in ORDEN_GUIADO:
		if Evidencias.puede_analizar(_id, estacion):
			return estacion
	return ""


func _actualizar_hub(resaltar: bool = true) -> void:
	var sig: String = _siguiente_guiada() if _guiado else ""
	var hechas: int = 0
	var disponibles: int = 0
	for estacion: String in ZONAS:
		var z: Zona = _zonas[estacion]
		if Evidencias.ya_analizada(_id, estacion):
			z.set_estado("hecha")
			hechas += 1
		elif not Evidencias.puede_analizar(_id, estacion):
			z.set_estado("bloqueada")   # sin muestras
		elif _guiado:
			z.set_estado("guiada" if (resaltar and estacion == sig) else "bloqueada")
		else:
			z.set_estado("libre")
			disponibles += 1
	_etq_muestras.text = "Muestras: %d de %d" % [
		Evidencias.muestras_restantes(_id), Evidencias.muestras_totales(_id)]
	_boton_terminar.visible = (not _guiado) and (hechas > 0 or disponibles == 0)


func _mostrar_hub() -> void:
	var sig: String = _siguiente_guiada() if _guiado else ""
	var hay_guia: bool = _guiado and sig != "" and not _guia_dicha.has(sig)
	# Mientras Iris explica no se resalta nada: primero habla, después se ilumina la zona.
	_actualizar_hub(not hay_guia)
	_mostrar_controles_hub(false)
	if _guiado:
		if sig == "":
			_terminar()
			return
		if hay_guia:
			_guia_dicha[sig] = true
			_ocupado = true
			await _reproducir_si_existe([
				CARPETA_DIALOGOS + "lab_%s.json" % sig,
			], false)
			_actualizar_hub(true)
	# Recién ahora se cierra la caja de diálogo (si quedó abierta) y aparecen los controles.
	await _p.cerrar_dialogo()
	_mostrar_controles_hub(true)
	_ocupado = false


func _mostrar_controles_hub(mostrar: bool) -> void:
	for z: Zona in _zonas.values():
		z.visible = mostrar
	_hud.visible = mostrar


func _poner_modo_estacion(activo: bool, estacion: String) -> void:
	_capa_estacion.visible = activo
	for z: Zona in _zonas.values():
		z.visible = false
	_hud.visible = false
	if activo:
		_etq_estacion.text = str(Evidencias.NOMBRES_ESTACION.get(estacion, estacion))
		var tex: Texture2D = MinijuegoBase.cargar_textura(str(FONDOS_ESTACION.get(estacion, "")))
		_fondo_imagen.texture = tex
		_fondo_color.visible = tex == null
	else:
		_boton_terminar.visible = false


# ---------------------------------------------------------------
# ESTACIONES
# ---------------------------------------------------------------

func _on_zona_elegida(estacion: String) -> void:
	if _ocupado or _termino:
		return
	if not Evidencias.puede_analizar(_id, estacion):
		return
	if _guiado and estacion != _siguiente_guiada():
		return
	_ocupado = true
	await _hacer_estacion(estacion)


func _hacer_estacion(estacion: String) -> void:
	# Laboratorio -> estación: se oscurece, se cambia la pantalla y se aclara.
	await _fundido(true)
	_poner_modo_estacion(true, estacion)
	await _fundido(false)

	var resultado: Dictionary = await _jugar(estacion)

	if not resultado.is_empty():
		Evidencias.registrar_analisis(_id, estacion, resultado)

	# Estación -> laboratorio: _jugar ya dejó la pantalla en negro.
	_poner_modo_estacion(false, "")
	await _fundido(false)

	if not resultado.is_empty():
		var variante: String = _variante(float(resultado.get("calidad", 1.0)))
		# La caja queda abierta al terminar: si sigue otro diálogo (el del laboratorio),
		# continúa sin que la caja y el sprite se cierren y vuelvan a aparecer.
		await _reproducir_si_existe([
			CARPETA_DIALOGOS + "%s_%s_%s.json" % [_id, estacion, variante],
			CARPETA_DIALOGOS + "%s_%s.json" % [_id, estacion],
		], false)

	await _mostrar_hub()


func _jugar(estacion: String) -> Dictionary:
	var analisis: Dictionary = _ficha.get("analisis", {})
	if not analisis.has(estacion):
		push_error("La ficha no tiene datos para la estación: " + estacion)
		return {}
	var d: Dictionary = analisis[estacion].duplicate(true)
	d["id"] = _id
	d["estacion"] = estacion

	var mj: MinijuegoBase = null
	match estacion:
		"composicion":
			mj = MJComposicion.new()
		"microscopio":
			mj = MJMicroscopio.new()
		"reconstruccion":
			mj = MJReconstruccion.new()
	if mj == null:
		return {}

	_ultimo_resultado = {}
	mj.configurar(d)
	mj.terminado.connect(_on_minijuego_terminado)
	mj.cancelado.connect(_on_minijuego_cancelado)
	# Evita que el primer panel (p. ej. "Muestra 1 de 2") aparezca
	# durante un instante antes de que Iris dé las instrucciones.
	mj.visible = false
	add_child(mj)
	mj.bloquear_interaccion(true)
	await get_tree().process_frame
	await _reproducir_si_existe([CARPETA_DIALOGOS + "guia_%s.json" % estacion])
	# El minijuego aparece de a poco, no de golpe.
	mj.modulate.a = 0.0
	mj.visible = true
	mj.create_tween().tween_property(mj, "modulate:a", 1.0, DURACION_FUNDIDO)
	mj.bloquear_interaccion(false)
	if mj is MJComposicion:
		mj.solicitar_dialogo_ronda.connect(_on_composicion_pedir_dialogo.bind(mj))
	await _minijuego_cerrado
	# Se oscurece la pantalla antes de sacar el minijuego, para que no haya un corte.
	await _fundido(true)
	mj.queue_free()
	return _ultimo_resultado


func _on_composicion_pedir_dialogo(numero: int, mj: MJComposicion) -> void:
	mj.bloquear_interaccion(true)
	await _reproducir_si_existe([
		CARPETA_DIALOGOS + "guia_composicion_ronda_%d.json" % numero,
	])
	if not is_instance_valid(mj):
		return
	mj.bloquear_interaccion(false)
	# Un cuadro de espera: así la señal nunca se emite antes de que el
	# minijuego esté esperándola, aunque el archivo de diálogo no exista.
	await get_tree().process_frame
	if is_instance_valid(mj):
		mj.dialogo_ronda_finalizado.emit()


func _on_minijuego_terminado(resultado: Dictionary) -> void:
	_ultimo_resultado = resultado
	_minijuego_cerrado.emit()


func _on_minijuego_cancelado() -> void:
	_ultimo_resultado = {}
	_minijuego_cerrado.emit()


# alta / media / baja, según qué tan bien salió el análisis (para elegir la devolución)
func _variante(calidad: float) -> String:
	if calidad >= 0.8:
		return "alta"
	if calidad >= 0.4:
		return "media"
	return "baja"


# Reproduce el primer JSON de la lista que exista; si no hay ninguno, no hace nada.
# Con cerrar_al_final = false la caja queda abierta, para que el diálogo que sigue
# continúe sin que la caja y el sprite se cierren y vuelvan a aparecer.
func _reproducir_si_existe(rutas: Array, cerrar_al_final: bool = true) -> void:
	for ruta: String in rutas:
		if FileAccess.file_exists(ruta):
			await _p.reproducir_dialogo(ruta)
			if cerrar_al_final:
				await _p.cerrar_dialogo()
			return


# ---------------------------------------------------------------
# FICHA Y CIERRE
# ---------------------------------------------------------------

func _abrir_ficha() -> void:
	if _ocupado:
		return
	var ficha := FichaEvidencia.new()
	ficha.configurar(_ficha)
	ficha.cancelado.connect(ficha.queue_free)
	add_child(ficha)


func _on_terminar_pulsado() -> void:
	if _ocupado:
		return
	_terminar()


func _terminar() -> void:
	if _termino:
		return
	_termino = true
	terminada.emit()
