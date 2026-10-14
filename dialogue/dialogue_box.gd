class_name DialogueBox
extends PanelContainer

var label_nombre: Label
var label_texto: Label

var tween_texto: Tween = null
var tween_panel: Tween = null
var esta_escribiendo: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = UIEstilo.MARGEN_LATERAL
	offset_right = -UIEstilo.MARGEN_LATERAL
	offset_top = -UIEstilo.ALTO_CAJA_DIALOGO - UIEstilo.MARGEN_INFERIOR
	offset_bottom = -UIEstilo.MARGEN_INFERIOR
	pivot_offset = Vector2.ZERO
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
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	label_nombre = Label.new()
	label_nombre.add_theme_font_size_override("font_size", UIEstilo.FUENTE_NOMBRE)
	label_nombre.add_theme_color_override("font_color", UIEstilo.COLOR_NOMBRE)
	vbox.add_child(label_nombre)

	label_texto = Label.new()
	label_texto.add_theme_font_size_override("font_size", UIEstilo.FUENTE_TEXTO)
	label_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label_texto)

func mostrar_linea(nombre: String, texto: String, centrado: bool = false) -> void:
	label_nombre.text = nombre
	if centrado:
		label_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		label_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label_texto.text = texto

	if tween_texto and tween_texto.is_running():
		tween_texto.kill()

	# Velocidad elegida por el jugador en Opciones (0 = el texto aparece de golpe)
	var segundos_por_letra: float = Ajustes.segundos_por_caracter()
	if segundos_por_letra <= 0.0:
		label_texto.visible_characters = -1
		esta_escribiendo = false
		return

	label_texto.visible_characters = 0
	esta_escribiendo = true
	var duracion = texto.length() * segundos_por_letra
	tween_texto = create_tween()
	tween_texto.tween_property(label_texto, "visible_characters", texto.length(), duracion)
	tween_texto.tween_callback(func(): esta_escribiendo = false)

func completar_texto() -> void:
	if tween_texto and tween_texto.is_running():
		tween_texto.kill()
	label_texto.visible_characters = -1
	esta_escribiendo = false

func entrar() -> void:
	if tween_panel and tween_panel.is_running():
		tween_panel.kill()
	pivot_offset = Vector2.ZERO
	visible = true
	scale = Vector2.ZERO
	tween_panel = create_tween()
	tween_panel.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween_panel.finished

func salir() -> void:
	if tween_panel and tween_panel.is_running():
		tween_panel.kill()
	pivot_offset = Vector2.ZERO
	tween_panel = create_tween()
	tween_panel.tween_property(self, "scale", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween_panel.finished
	visible = false
