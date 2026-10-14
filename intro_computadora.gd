extends Control

# --- Ajustes visuales: cambiá estos números a gusto ---
const TAMANO_FUENTE_INPUT := 40
const TAMANO_FUENTE_ESTADO := 40
const TAMANO_FUENTE_AVISO := 30
const DESPLAZAMIENTO_VERTICAL_ESTADO := 6.0
const AVISO_OFFSET_Y := -70.0   # negativo = el aviso aparece arriba del campo; positivo = abajo
const COLOR_AVISO := Color(1.0, 0.5, 0.5)
const LARGO_MAXIMO_NOMBRE := 20

# Zona de la imagen de la pantalla (en píxeles de PC.png) donde está dibujado el botón ACEPTAR
const REGION_BOTON := Rect2(593, 461, 190, 48)

# Brillo del botón según su estado (1.0 = igual que la imagen original)
const BRILLO_VACIO := 0.7        # campo de nombre vacío
const BRILLO_NORMAL := 1.0       # con nombre escrito
const BRILLO_HOVER := 1.3        # mouse encima
const BRILLO_PRESIONADO := 0.8   # mientras se aprieta
# -------------------------------------------------------

# Dónde empieza el juego después de ingresar el nombre (también es el punto de guardado)
const RUTA_PRIMER_DIA := "res://data/C1_E1.json"

@onready var input_nombre = $InputNombre
@onready var label_estado = $LabelEstado
@onready var pantalla = $Pantalla
@onready var boton_aceptar = $BotonAceptar
@onready var computadora = $Computadora

@export var textura_verde: Texture2D

var estilo_celeste = StyleBoxFlat.new()
var estilo_vacio = StyleBoxEmpty.new()
var texto_placeholder = "Escribe tu nombre aquí..."
var textura_azul: Texture2D

var label_aviso: Label
var imagen_boton: TextureRect
var tween_aviso: Tween = null
var tween_sacudida: Tween = null
var tween_color: Tween = null
var tween_boton: Tween = null
var posicion_input: Vector2
var procesando: bool = false
var _boton_hover: bool = false
var _boton_presionado: bool = false

func _ready():
	SceneTransition.fundir_entrada(1.0)

	textura_azul = pantalla.texture
	posicion_input = input_nombre.position

	# La pantalla y el label empiezan ocultos y no capturan el mouse,
	# así no tapan los clics del botón de la computadora.
	pantalla.visible = false
	pantalla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_estado.visible = false
	label_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	input_nombre.visible = false
	boton_aceptar.visible = false

	# --- LABEL DE ESTADO: centrado en toda la pantalla ---
	label_estado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_estado.offset_top = DESPLAZAMIENTO_VERTICAL_ESTADO
	label_estado.offset_bottom = DESPLAZAMIENTO_VERTICAL_ESTADO
	label_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_estado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_estado.add_theme_font_size_override("font_size", TAMANO_FUENTE_ESTADO)

	# --- INPUT DEL NOMBRE ---
	input_nombre.add_theme_font_size_override("font_size", TAMANO_FUENTE_INPUT)
	input_nombre.max_length = LARGO_MAXIMO_NOMBRE

	# --- AVISO DE NOMBRE VACÍO (se crea por código, no hay que agregar nodos) ---
	label_aviso = Label.new()
	label_aviso.text = "Escribí tu nombre para continuar"
	label_aviso.add_theme_font_size_override("font_size", TAMANO_FUENTE_AVISO)
	label_aviso.add_theme_color_override("font_color", COLOR_AVISO)
	label_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_aviso.modulate.a = 0.0
	add_child(label_aviso)

	# --- BOTÓN DE LA COMPUTADORA: invisible pero clickeable ---
	var estilo_invisible = StyleBoxEmpty.new()
	computadora.add_theme_stylebox_override("normal", estilo_invisible)
	computadora.add_theme_stylebox_override("hover", estilo_invisible)
	computadora.add_theme_stylebox_override("pressed", estilo_invisible)
	computadora.add_theme_stylebox_override("focus", estilo_invisible)
	computadora.add_theme_stylebox_override("disabled", estilo_invisible)
	computadora.text = ""

	estilo_celeste.bg_color = Color(0.53, 0.81, 0.92, 0.35)

	input_nombre.add_theme_stylebox_override("normal", estilo_celeste)
	input_nombre.add_theme_stylebox_override("focus", estilo_vacio)
	input_nombre.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	input_nombre.placeholder_text = texto_placeholder
	input_nombre.alignment = HORIZONTAL_ALIGNMENT_CENTER

	input_nombre.focus_entered.connect(_on_input_focus_entered)
	input_nombre.focus_exited.connect(_on_input_focus_exited)
	input_nombre.text_changed.connect(_on_texto_cambiado)

	_preparar_boton_aceptar()

	input_nombre.text_submitted.connect(_on_aceptar_pressed)
	boton_aceptar.pressed.connect(_on_aceptar_pressed)
	computadora.pressed.connect(_on_computadora_pressed)

# ---------------------------------------------------------------
# BOTÓN ACEPTAR: usa un recorte de la imagen de la pantalla
# ---------------------------------------------------------------

func _preparar_boton_aceptar() -> void:
	var tam_textura: Vector2 = textura_azul.get_size()
	var escala: Vector2 = get_viewport_rect().size / tam_textura

	# El botón real no dibuja nada: todo el aspecto viene del recorte de la imagen
	var estilo_nada := StyleBoxEmpty.new()
	for nombre_estilo in ["normal", "hover", "pressed", "focus", "disabled"]:
		boton_aceptar.add_theme_stylebox_override(nombre_estilo, estilo_nada)
	boton_aceptar.text = ""
	boton_aceptar.focus_mode = Control.FOCUS_NONE
	boton_aceptar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Se ubica solo, exactamente encima del dibujo del botón en la pantalla ampliada
	boton_aceptar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	boton_aceptar.custom_minimum_size = REGION_BOTON.size * escala
	boton_aceptar.size = REGION_BOTON.size * escala
	boton_aceptar.position = REGION_BOTON.position * escala

	var recorte := AtlasTexture.new()
	recorte.atlas = textura_azul
	recorte.region = REGION_BOTON
	recorte.filter_clip = true

	imagen_boton = TextureRect.new()
	imagen_boton.texture = recorte
	imagen_boton.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen_boton.stretch_mode = TextureRect.STRETCH_SCALE
	imagen_boton.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton_aceptar.add_child(imagen_boton)
	imagen_boton.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	imagen_boton.modulate = Color(BRILLO_VACIO, BRILLO_VACIO, BRILLO_VACIO, 1.0)

	boton_aceptar.mouse_entered.connect(_on_boton_mouse_entered)
	boton_aceptar.mouse_exited.connect(_on_boton_mouse_exited)
	boton_aceptar.button_down.connect(_on_boton_down)
	boton_aceptar.button_up.connect(_on_boton_up)

func _nombre_listo() -> bool:
	return input_nombre.text.strip_edges() != ""

func _actualizar_boton_visual() -> void:
	var listo := _nombre_listo()
	var brillo: float = BRILLO_NORMAL if listo else BRILLO_VACIO
	if _boton_presionado:
		brillo = BRILLO_PRESIONADO
	elif _boton_hover:
		brillo = BRILLO_HOVER if listo else BRILLO_VACIO + 0.15

	if tween_boton:
		tween_boton.kill()
	tween_boton = create_tween()
	tween_boton.tween_property(imagen_boton, "modulate", Color(brillo, brillo, brillo, 1.0), 0.1)

func _on_boton_mouse_entered() -> void:
	_boton_hover = true
	_actualizar_boton_visual()

func _on_boton_mouse_exited() -> void:
	_boton_hover = false
	_boton_presionado = false
	_actualizar_boton_visual()

func _on_boton_down() -> void:
	_boton_presionado = true
	_actualizar_boton_visual()

func _on_boton_up() -> void:
	_boton_presionado = false
	_actualizar_boton_visual()

# ---------------------------------------------------------------
# NOMBRE
# ---------------------------------------------------------------

func _on_aceptar_pressed(_texto: String = "") -> void:
	if procesando:
		return

	var nombre = input_nombre.text.strip_edges()
	if nombre == "":
		_avisar_nombre_vacio()
		return

	procesando = true
	GameState.nombre_jugador = nombre

	# Se guarda enseguida, antes de la animación, apuntando al comienzo del primer día
	GameState.ruta_json_actual = RUTA_PRIMER_DIA
	GameState.guardar_partida()

	input_nombre.visible = false
	boton_aceptar.visible = false
	label_aviso.modulate.a = 0.0
	_secuencia_autenticacion()

func _avisar_nombre_vacio() -> void:
	input_nombre.text = ""   # descarta espacios sueltos
	input_nombre.grab_focus()
	_actualizar_boton_visual()

	# Aviso de texto junto al campo
	label_aviso.size = Vector2(input_nombre.size.x, label_aviso.get_minimum_size().y)
	label_aviso.position = Vector2(input_nombre.position.x, input_nombre.position.y + AVISO_OFFSET_Y)
	if tween_aviso:
		tween_aviso.kill()
	label_aviso.modulate.a = 1.0
	tween_aviso = create_tween()
	tween_aviso.tween_interval(2.0)
	tween_aviso.tween_property(label_aviso, "modulate:a", 0.0, 0.4)

	# Sacudida horizontal del campo
	if tween_sacudida:
		tween_sacudida.kill()
	input_nombre.position = posicion_input
	tween_sacudida = create_tween()
	for desplazamiento in [12.0, -12.0, 8.0, -8.0, 4.0, 0.0]:
		tween_sacudida.tween_property(input_nombre, "position:x", posicion_input.x + desplazamiento, 0.05)

	# Destello rojizo del campo
	if tween_color:
		tween_color.kill()
	input_nombre.modulate = COLOR_AVISO
	tween_color = create_tween()
	tween_color.tween_property(input_nombre, "modulate", Color.WHITE, 0.5)

func _on_texto_cambiado(_nuevo_texto: String) -> void:
	# En cuanto el jugador empieza a escribir, el aviso desaparece
	if label_aviso.modulate.a > 0.0:
		if tween_aviso:
			tween_aviso.kill()
		label_aviso.modulate.a = 0.0
	_actualizar_boton_visual()

# ---------------------------------------------------------------
# SECUENCIA DE AUTENTICACIÓN Y SALIDA
# ---------------------------------------------------------------

func _secuencia_autenticacion() -> void:
	label_estado.visible = true

	for i in range(4):
		label_estado.text = "Comprobando identidad" + ".".repeat(i)
		await get_tree().create_timer(0.375).timeout

	pantalla.texture = textura_verde
	label_estado.text = "Acceso autorizado"
	await get_tree().create_timer(1.5).timeout

	_cerrar_pantalla_identificacion()

func _cerrar_pantalla_identificacion() -> void:
	label_estado.visible = false
	label_estado.text = ""

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(pantalla, "position", Vector2(812, 432), 0.7)
	tween.tween_property(pantalla, "scale", Vector2(0.2122, 0.2109), 0.7)

	tween.finished.connect(_ir_a_escena_de_dialogo)

func _ir_a_escena_de_dialogo() -> void:
	SceneTransition.ir_a("res://main.tscn")

func _on_input_focus_entered():
	input_nombre.add_theme_stylebox_override("normal", estilo_vacio)
	input_nombre.placeholder_text = ""

func _on_input_focus_exited():
	input_nombre.add_theme_stylebox_override("normal", estilo_celeste)
	if input_nombre.text == "":
		input_nombre.placeholder_text = texto_placeholder

func _on_computadora_pressed() -> void:
	computadora.visible = false
	pantalla.pivot_offset = Vector2(0, 0)
	pantalla.position = Vector2(812, 432)
	pantalla.scale = Vector2(0.2122, 0.2109)
	pantalla.visible = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(pantalla, "position", Vector2(0, 0), 0.7)
	tween.tween_property(pantalla, "scale", Vector2(1.395349, 1.40625), 0.7)
	tween.finished.connect(_mostrar_input_nombre)

func _mostrar_input_nombre():
	input_nombre.visible = true
	boton_aceptar.visible = true
	_actualizar_boton_visual()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(input_nombre) or not input_nombre.is_visible_in_tree():
		return

	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed and input_nombre.has_focus():
			var rect_global = Rect2(input_nombre.global_position, input_nombre.size)
			if not rect_global.has_point(event.position):
				input_nombre.release_focus()

	if event.is_action_pressed("ui_cancel") and input_nombre.has_focus():
		input_nombre.release_focus()
