class_name ChoiceMenu
extends PanelContainer

signal opcion_elegida(siguiente_id: int, id_decision: int, es_salto: bool)

var label_pista: Label
var contenedor_botones: VBoxContainer
var boton_marcado: Button = null
var tween_panel: Tween = null
var _confirmado: bool = false

func _ready() -> void:
	# Anclado abajo y centrado. Crece hacia arriba según la cantidad de opciones.
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = UIEstilo.MARGEN_LATERAL_OPCIONES
	offset_right = -UIEstilo.MARGEN_LATERAL_OPCIONES
	offset_bottom = -UIEstilo.MARGEN_INFERIOR
	offset_top = -UIEstilo.MARGEN_INFERIOR
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	visible = false
	scale = Vector2.ZERO

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = UIEstilo.COLOR_FONDO_CAJA
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = UIEstilo.PADDING_INTERNO
	estilo.content_margin_right = UIEstilo.PADDING_INTERNO
	estilo.content_margin_top = UIEstilo.PADDING_INTERNO
	estilo.content_margin_bottom = UIEstilo.PADDING_INTERNO
	add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIEstilo.SEPARACION)
	add_child(vbox)

	label_pista = Label.new()
	label_pista.add_theme_font_size_override("font_size", UIEstilo.FUENTE_NOMBRE)
	label_pista.add_theme_color_override("font_color", UIEstilo.COLOR_NOMBRE)
	label_pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_pista)

	contenedor_botones = VBoxContainer.new()
	contenedor_botones.add_theme_constant_override("separation", UIEstilo.SEPARACION)
	vbox.add_child(contenedor_botones)

func mostrar_opciones(id_decision: int, pista: String, opciones: Array, leidas: Array) -> void:
	label_pista.text = pista
	label_pista.visible = pista != ""
	boton_marcado = null
	_confirmado = false

	for hijo in contenedor_botones.get_children():
		contenedor_botones.remove_child(hijo)
		hijo.queue_free()

	for op in opciones:
		var destino = int(op.get("siguiente_id", -1))
		var es_salto = bool(op.get("es_salto", false))
		var texto_original = str(op.get("texto", "")).replace("{nombre}", GameState.nombre_jugador)

		var boton := Button.new()
		boton.text = texto_original
		boton.set_meta("texto_original", texto_original)
		boton.custom_minimum_size = Vector2(0, UIEstilo.ALTO_BOTON)
		boton.add_theme_font_size_override("font_size", UIEstilo.FUENTE_TEXTO)

		if es_salto:
			boton.pressed.connect(_on_boton.bind(boton, destino, id_decision, true))
		elif leidas.has(destino):
			boton.disabled = true
			boton.modulate = Color(1, 1, 1, 0.5)
		else:
			boton.pressed.connect(_on_boton.bind(boton, destino, id_decision, false))

		contenedor_botones.add_child(boton)

# Deja el menú armado (invisible, a escala cero) y devuelve dónde queda su borde
# superior en pantalla. Se llama después de mostrar_opciones() y antes de entrar().
func medir_borde_superior() -> float:
	scale = Vector2.ZERO
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	return position.y

func _on_boton(boton: Button, destino: int, id_decision: int, es_salto: bool) -> void:
	if _confirmado:
		return
	if es_salto:
		_confirmar(destino, id_decision, true)
		return

	if boton == boton_marcado:
		_confirmar(destino, id_decision, false)
	else:
		if boton_marcado:
			boton_marcado.text = str(boton_marcado.get_meta("texto_original"))
		boton_marcado = boton
		boton.text = "> " + str(boton.get_meta("texto_original")) + " <"

func _confirmar(destino: int, id_decision: int, es_salto: bool) -> void:
	if _confirmado:
		return
	_confirmado = true
	boton_marcado = null
	opcion_elegida.emit(destino, id_decision, es_salto)

func entrar() -> void:
	if tween_panel and tween_panel.is_running():
		tween_panel.kill()
	scale = Vector2.ZERO
	visible = true
	await get_tree().process_frame
	pivot_offset = size / 2
	tween_panel = create_tween()
	tween_panel.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween_panel.finished

func salir() -> void:
	if tween_panel and tween_panel.is_running():
		tween_panel.kill()
	pivot_offset = size / 2
	tween_panel = create_tween()
	tween_panel.tween_property(self, "scale", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween_panel.finished
	visible = false
