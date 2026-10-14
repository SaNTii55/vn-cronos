extends CanvasLayer

var _rect: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 1.0
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Se puede usar con await para esperar a que el fundido termine.
func fundir_entrada(duracion: float = 0.4) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", 0.0, duracion)
	await _tween.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func ir_a(ruta: String, duracion: float = 0.8) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", 1.0, duracion)
	await _tween.finished
	_cambiar(ruta)

func _cambiar(ruta: String) -> void:
	if ruta.ends_with(".tscn"):
		get_tree().change_scene_to_file(ruta)
	elif ruta.ends_with(".json"):
		GameState.ruta_json_actual = ruta
		get_tree().reload_current_scene()
	else:
		push_error("Extensión no reconocida en la transición: " + ruta)
		fundir_entrada()
