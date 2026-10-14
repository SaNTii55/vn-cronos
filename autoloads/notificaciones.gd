extends CanvasLayer
## Mensajes breves y flotantes en la esquina superior derecha (por ejemplo "Partida guardada").
## Es un autoload: se usa desde cualquier escena con Notificaciones.mostrar("texto").

# --- Ajustes: cambiá estos números a gusto ---
const MARGEN_DERECHO := 40.0
const MARGEN_SUPERIOR := 40.0
const TAMANO_FUENTE := 28
const DURACION_ENTRADA := 0.25
const DURACION_VISIBLE := 1.8
const DURACION_SALIDA := 0.5
const COLOR_FONDO := Color(0.05, 0.05, 0.08, 0.92)
const COLOR_BORDE := Color(0.35, 0.85, 1.0)
const COLOR_BORDE_ERROR := Color(1.0, 0.45, 0.45)
# ---------------------------------------------

var _panel: PanelContainer
var _estilo: StyleBoxFlat
var _label: Label
var _tween: Tween = null

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	add_child(_panel)

	# Anclado arriba a la derecha. Si el texto es más largo, crece hacia la izquierda.
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -MARGEN_DERECHO
	_panel.offset_right = -MARGEN_DERECHO
	_panel.offset_top = MARGEN_SUPERIOR
	_panel.offset_bottom = MARGEN_SUPERIOR

	_estilo = StyleBoxFlat.new()
	_estilo.bg_color = COLOR_FONDO
	_estilo.border_color = COLOR_BORDE
	_estilo.set_border_width_all(2)
	_estilo.set_corner_radius_all(10)
	_estilo.content_margin_left = 24
	_estilo.content_margin_right = 24
	_estilo.content_margin_top = 12
	_estilo.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", _estilo)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", TAMANO_FUENTE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)

func mostrar(texto: String, es_error: bool = false) -> void:
	_label.text = texto
	_estilo.border_color = COLOR_BORDE_ERROR if es_error else COLOR_BORDE
	_panel.reset_size()

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, DURACION_ENTRADA)
	_tween.tween_interval(DURACION_VISIBLE)
	_tween.tween_property(_panel, "modulate:a", 0.0, DURACION_SALIDA)
