class_name MJMicroscopio
extends MinijuegoBase
## Microscopio: la imagen está casi a oscuras y solo se ve bien dentro de la lupa.
## El jugador mueve la lupa y hace clic sobre los rasgos que encuentra.
##
## Datos (JSON): imagen, instruccion,
## rasgos[{nombre, pos:[x,y] (0 a 1), radio (fracción del ancho), dato}],
## conclusion (se agrega al final), util.

const ANCHO_VISOR := 1100.0
const ALTO_VISOR := 600.0
const RADIO_LUPA := 150.0

const SHADER := """
shader_type canvas_item;
uniform vec2 centro_px = vec2(-1000.0, -1000.0);
uniform vec2 tamano_px = vec2(1.0, 1.0);
uniform float radio_px = 150.0;
uniform float suavidad_px = 24.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(UV * tamano_px, centro_px);
	float k = smoothstep(radio_px, radio_px - suavidad_px, d);
	float gris = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 fuera = vec3(gris) * 0.16;
	COLOR = vec4(mix(fuera, c.rgb, k), c.a);
}
"""


class Visor extends TextureRect:
	signal clic_en(pos_px: Vector2)
	var radio_lupa: float = 150.0
	var marcas: Array = []
	var _mouse: Vector2 = Vector2(-1000, -1000)
	var _mat: ShaderMaterial

	func preparar(codigo: String, radio: float) -> void:
		radio_lupa = radio
		var sh := Shader.new()
		sh.code = codigo
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("radio_px", radio)
		material = _mat
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_CROSS
		resized.connect(_al_cambiar_tamano)
		_al_cambiar_tamano()

	func _ready() -> void:
		_al_cambiar_tamano()

	func _al_cambiar_tamano() -> void:
		if _mat != null:
			_mat.set_shader_parameter("tamano_px", size)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_mouse = event.position
			if _mat != null:
				_mat.set_shader_parameter("tamano_px", size)
				_mat.set_shader_parameter("centro_px", _mouse)
			queue_redraw()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clic_en.emit(event.position)

	func _draw() -> void:
		for m in marcas:
			draw_arc(m, 30.0, 0.0, TAU, 32, Color(0.45, 0.85, 0.50), 4.0)
		draw_arc(_mouse, radio_lupa, 0.0, TAU, 72, MinijuegoBase.COLOR_ACENTO, 3.0)

var _visor: Visor
var _encontrados: Array = []
var _etq_estado: Label
var _etq_ultimo: Label
var _boton: Button


func _construir() -> void:
	var caja := crear_marco_central(Vector2(1220, 900))
	caja.add_child(crear_titulo(str(datos.get("titulo", "Microscopio"))))
	caja.add_child(crear_label(
		str(datos.get("instruccion", "Mové la lupa sobre la pieza y hacé clic en lo que encuentres.")),
		t_texto(), COLOR_APAGADO))

	var tex: Texture2D = cargar_textura(str(datos.get("imagen", "")))
	if tex == null:
		tex = textura_provisoria(1100, 640)

	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(centro)
	_visor = Visor.new()
	_visor.preparar(SHADER, RADIO_LUPA)   # antes que el tamaño y la textura
	_visor.texture = tex
	_visor.custom_minimum_size = Vector2(ANCHO_VISOR, ALTO_VISOR)
	_visor.size = Vector2(ANCHO_VISOR, ALTO_VISOR)
	_visor.clic_en.connect(_on_clic)
	centro.add_child(_visor)

	_etq_ultimo = crear_label("", t_texto(), COLOR_OK)
	caja.add_child(_etq_ultimo)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 20)
	caja.add_child(fila)
	_etq_estado = crear_label("", t_texto(), COLOR_TEXTO)
	poner_en_estado(_etq_estado, fila)
	_boton = crear_boton("Registrar resultado", 380)
	_boton.pressed.connect(_finalizar)
	poner_en_estado(_boton, fila)
	_actualizar_estado()


func _on_clic(pos_px: Vector2) -> void:
	var rasgos: Array = datos.get("rasgos", [])
	for i in range(rasgos.size()):
		if _encontrados.has(i):
			continue
		var r: Dictionary = rasgos[i]
		var p: Array = r.get("pos", [0.5, 0.5])
		var centro: Vector2 = Vector2(float(p[0]) * _visor.size.x, float(p[1]) * _visor.size.y)
		var radio: float = float(r.get("radio", 0.06)) * _visor.size.x
		if pos_px.distance_to(centro) <= radio:
			_encontrados.append(i)
			_visor.marcas.append(centro)
			_visor.queue_redraw()
			_etq_ultimo.text = "%s: %s" % [str(r.get("nombre", "")), str(r.get("dato", ""))]
			_actualizar_estado()
			return
	_etq_ultimo.text = ""


func _actualizar_estado() -> void:
	var total: int = datos.get("rasgos", []).size()
	_etq_estado.text = "Rasgos encontrados: %d de %d" % [_encontrados.size(), total]


func _finalizar() -> void:
	var rasgos: Array = datos.get("rasgos", [])
	var lineas: Array = []
	for i in _encontrados:
		var r: Dictionary = rasgos[i]
		lineas.append(str(r.get("dato", "")))
	if lineas.is_empty():
		lineas.append("No se observó nada concluyente.")
	var conclusion: String = str(datos.get("conclusion", ""))
	if conclusion != "" and _encontrados.size() > 0:
		lineas.append(conclusion)
	var total: int = rasgos.size()
	terminado.emit({
		"estacion": "microscopio",
		"util": bool(datos.get("util", true)),
		"calidad": 1.0 if total == 0 else float(_encontrados.size()) / float(total),
		"datos": lineas,
	})
