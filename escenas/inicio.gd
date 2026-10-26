extends Control

const RUTA_INTRO := "res://data/C1_E0.json"
const RUTA_JUEGO := "res://main.tscn"

# --- Ajustes: cambiá estos valores a gusto ---
const TITULO_MENU := ""                 # texto sobre los botones (vacío = sin título)
const DESPLAZAMIENTO_MENU_Y := 0.0      # positivo = el menú baja, negativo = sube
# ---------------------------------------------

@export var imagen_fondo: Texture2D

var _menu_abierto: bool = false
var _en_submenu: bool = false
var _iniciando: bool = false
var _centro: CenterContainer
var _panel: MenuPanel
var _prompt: Control = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fondo := TextureRect.new()
	fondo.texture = imagen_fondo
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	move_child(fondo, 0)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Si la escena tiene un Label llamado "LabelPresionar" ("Presioná una tecla..."),
	# se desvanece cuando aparece el menú.
	_prompt = get_node_or_null("LabelPresionar")

	SceneTransition.fundir_entrada(1.0)

func _input(event: InputEvent) -> void:
	if _iniciando:
		return

	if not _menu_abierto:
		var es_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		var es_tecla = event is InputEventKey and event.pressed and not event.echo
		if es_click or es_tecla:
			get_viewport().set_input_as_handled()
			_abrir_menu()
	elif _en_submenu and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_mostrar_principal()

func _abrir_menu() -> void:
	_menu_abierto = true

	if _prompt:
		var tween := create_tween()
		tween.tween_property(_prompt, "modulate:a", 0.0, 0.3)

	_centro = CenterContainer.new()
	_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_centro)
	_centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_centro.offset_top = DESPLAZAMIENTO_MENU_Y * 2.0

	_panel = MenuPanel.new()
	_centro.add_child(_panel)

	_mostrar_principal()

func _mostrar_principal() -> void:
	_en_submenu = false
	var items: Array = []
	if GameState.hay_partida_guardada():
		items.append({"texto": "Continuar", "accion": _continuar})
	items.append({"texto": "Nueva partida", "accion": _nueva_partida})
	items.append({"texto": "Opciones", "accion": _mostrar_opciones})
	items.append({"texto": "Salir", "accion": _salir})
	_panel.mostrar_lista(TITULO_MENU, items)

func _mostrar_opciones() -> void:
	_en_submenu = true
	_panel.mostrar_opciones(_mostrar_principal)

func _continuar() -> void:
	if _iniciando:
		return
	if GameState.cargar_partida():
		_iniciando = true
		SceneTransition.ir_a(RUTA_JUEGO)
	else:
		Notificaciones.mostrar("No se pudo cargar la partida", true)

func _nueva_partida() -> void:
	if GameState.hay_partida_guardada():
		_en_submenu = true
		_panel.mostrar_confirmacion(
			"¿Empezar de nuevo?",
			"Ya hay una partida guardada. Se reemplaza cuando se guarde la nueva.",
			"Empezar de nuevo", _empezar,
			"Cancelar", _mostrar_principal)
	else:
		_empezar()

func _empezar() -> void:
	if _iniciando:
		return
	_iniciando = true
	GameState.nombre_jugador = "Viajero"
	GameState.ruta_json_actual = RUTA_INTRO
	GameState.limpiar_punto()
	Evidencias.reiniciar_todo()
	SceneTransition.ir_a(RUTA_JUEGO)

func _salir() -> void:
	get_tree().quit()
