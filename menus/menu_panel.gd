class_name MenuPanel
extends PanelContainer
## Panel de menú reutilizable (inicio, pausa, opciones y confirmaciones).
## Se arma por código con el mismo estilo que las cajas de diálogo.

const ANCHO := 760.0
const SEPARACION := 18

const COLOR_BOTON := Color(0.10, 0.13, 0.19, 0.95)
const COLOR_BOTON_HOVER := Color(0.14, 0.22, 0.30, 0.95)
const COLOR_BOTON_PRESIONADO := Color(0.07, 0.09, 0.13, 0.95)
const COLOR_BORDE := Color(0.25, 0.55, 0.70)
const COLOR_BORDE_HOVER := Color(0.40, 0.85, 1.00)

var _titulo: Label
var _contenido: VBoxContainer
var _label_volumen: Label = null
var _primer_boton: Button = null

func _init() -> void:
	custom_minimum_size = Vector2(ANCHO, 0)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = UIEstilo.COLOR_FONDO_CAJA
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = UIEstilo.PADDING_INTERNO
	estilo.content_margin_right = UIEstilo.PADDING_INTERNO
	estilo.content_margin_top = UIEstilo.PADDING_INTERNO
	estilo.content_margin_bottom = UIEstilo.PADDING_INTERNO
	add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SEPARACION)
	add_child(vbox)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", UIEstilo.FUENTE_NOMBRE)
	_titulo.add_theme_color_override("font_color", UIEstilo.COLOR_NOMBRE)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_titulo)

	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", SEPARACION)
	vbox.add_child(_contenido)

# ---------------------------------------------------------------
# PANTALLAS
# ---------------------------------------------------------------

# items: lista de {"texto": "Continuar", "accion": una_funcion}
func mostrar_lista(titulo: String, items: Array) -> void:
	_limpiar(titulo)
	for item in items:
		agregar_boton(str(item["texto"]), item["accion"])
	_terminar()

func mostrar_confirmacion(titulo: String, texto: String, texto_aceptar: String, al_aceptar: Callable, texto_cancelar: String, al_cancelar: Callable) -> void:
	_limpiar(titulo)
	agregar_texto(texto)
	agregar_boton(texto_aceptar, al_aceptar)
	var boton_cancelar := agregar_boton(texto_cancelar, al_cancelar)
	_primer_boton = boton_cancelar   # el foco empieza en la opción segura
	_terminar()

func mostrar_opciones(al_volver: Callable) -> void:
	_limpiar("Opciones")

	var boton_pantalla := agregar_boton(_texto_pantalla())
	boton_pantalla.pressed.connect(_alternar_pantalla.bind(boton_pantalla))

	var boton_velocidad := agregar_boton(_texto_velocidad())
	boton_velocidad.pressed.connect(_cambiar_velocidad.bind(boton_velocidad))

	_label_volumen = Label.new()
	_label_volumen.text = _texto_volumen()
	_label_volumen.add_theme_font_size_override("font_size", UIEstilo.FUENTE_TEXTO)
	_label_volumen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(_label_volumen)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(Ajustes.volumen * 100.0)
	slider.custom_minimum_size = Vector2(0, 40)
	slider.value_changed.connect(_on_volumen_cambiado)
	_contenido.add_child(slider)

	agregar_boton("Volver", al_volver)
	_terminar()

# ---------------------------------------------------------------
# ELEMENTOS
# ---------------------------------------------------------------

func agregar_boton(texto: String, accion: Callable = Callable()) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0, UIEstilo.ALTO_BOTON)
	boton.add_theme_font_size_override("font_size", UIEstilo.FUENTE_TEXTO)
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.add_theme_stylebox_override("normal", _caja_boton(COLOR_BOTON, COLOR_BORDE))
	boton.add_theme_stylebox_override("hover", _caja_boton(COLOR_BOTON_HOVER, COLOR_BORDE_HOVER))
	boton.add_theme_stylebox_override("pressed", _caja_boton(COLOR_BOTON_PRESIONADO, COLOR_BORDE_HOVER))
	boton.add_theme_stylebox_override("focus", _caja_boton(Color(0, 0, 0, 0), COLOR_BORDE_HOVER, false))
	if accion.is_valid():
		boton.pressed.connect(accion)
	_contenido.add_child(boton)
	if _primer_boton == null:
		_primer_boton = boton
	return boton

func agregar_texto(texto: String) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", UIEstilo.FUENTE_TEXTO)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(label)
	return label

func _caja_boton(fondo: Color, borde: Color, con_centro: bool = true) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.draw_center = con_centro
	caja.border_color = borde
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(8)
	caja.content_margin_left = 20
	caja.content_margin_right = 20
	caja.content_margin_top = 10
	caja.content_margin_bottom = 10
	return caja

func _limpiar(titulo: String) -> void:
	_titulo.text = titulo
	_titulo.visible = titulo != ""
	_primer_boton = null
	_label_volumen = null
	for hijo in _contenido.get_children():
		_contenido.remove_child(hijo)
		hijo.queue_free()

func _terminar() -> void:
	if _primer_boton:
		_primer_boton.call_deferred("grab_focus")
	if is_inside_tree():
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.15)

# ---------------------------------------------------------------
# OPCIONES
# ---------------------------------------------------------------

func _texto_pantalla() -> String:
	return "Pantalla completa: " + ("Sí" if Ajustes.pantalla_completa else "No")

func _texto_velocidad() -> String:
	return "Velocidad del texto: " + Ajustes.nombre_velocidad()

func _texto_volumen() -> String:
	return "Volumen: %d%%" % int(round(Ajustes.volumen * 100.0))

func _alternar_pantalla(boton: Button) -> void:
	Ajustes.set_pantalla_completa(not Ajustes.pantalla_completa)
	boton.text = _texto_pantalla()

func _cambiar_velocidad(boton: Button) -> void:
	Ajustes.ciclar_velocidad()
	boton.text = _texto_velocidad()

func _on_volumen_cambiado(valor: float) -> void:
	Ajustes.set_volumen(valor / 100.0)
	if _label_volumen:
		_label_volumen.text = _texto_volumen()
