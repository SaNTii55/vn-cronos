class_name MenuPausa
extends CanvasLayer
## Menú de pausa: se abre con Esc, oscurece el juego y lo detiene mientras está abierto.

const RUTA_INICIO := "res://escenas/Inicio.tscn"
const OSCURECIDO := Color(0.0, 0.0, 0.0, 0.6)

# La escena lo pone en false cuando no se debe poder pausar (por ejemplo, al cambiar de escena)
var permitido: bool = true

var _fondo: ColorRect
var _centro: CenterContainer
var _panel: MenuPanel
var _abierto: bool = false
var _en_submenu: bool = false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS   # sigue funcionando con el juego en pausa
	visible = false

	_fondo = ColorRect.new()
	_fondo.color = OSCURECIDO
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fondo)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_centro = CenterContainer.new()
	_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_centro)
	_centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = MenuPanel.new()
	_centro.add_child(_panel)

func abrir() -> void:
	if _abierto:
		return
	_abierto = true
	get_tree().paused = true
	visible = true
	_mostrar_principal()

func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	visible = false
	get_tree().paused = false

func _mostrar_principal() -> void:
	_en_submenu = false
	_panel.mostrar_lista("Pausa", [
		{"texto": "Continuar", "accion": cerrar},
		{"texto": "Opciones", "accion": _mostrar_opciones},
		{"texto": "Volver al inicio", "accion": _confirmar_inicio},
		{"texto": "Salir del juego", "accion": _confirmar_salir},
	])

func _mostrar_opciones() -> void:
	_en_submenu = true
	_panel.mostrar_opciones(_mostrar_principal)

func _confirmar_inicio() -> void:
	_en_submenu = true
	_panel.mostrar_confirmacion(
		"¿Volver al inicio?",
		"Se pierde el avance desde el último guardado.",
		"Volver al inicio", _ir_al_inicio,
		"Cancelar", _mostrar_principal)

func _confirmar_salir() -> void:
	_en_submenu = true
	_panel.mostrar_confirmacion(
		"¿Salir del juego?",
		"Se pierde el avance desde el último guardado.",
		"Salir", _salir,
		"Cancelar", _mostrar_principal)

func _ir_al_inicio() -> void:
	permitido = false
	cerrar()
	SceneTransition.ir_a(RUTA_INICIO)

func _salir() -> void:
	get_tree().quit()

# Detecta la tecla Esc directamente, sin depender del mapa de entrada del proyecto
func _es_tecla_pausa(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE

func _input(event: InputEvent) -> void:
	if not _es_tecla_pausa(event):
		return

	if _abierto:
		get_viewport().set_input_as_handled()
		if _en_submenu:
			_mostrar_principal()
		else:
			cerrar()
	elif permitido:
		get_viewport().set_input_as_handled()
		abrir()
