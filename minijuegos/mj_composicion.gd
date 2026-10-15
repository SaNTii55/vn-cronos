class_name MJComposicion
extends MinijuegoBase
## Analizador de material: en cada ronda se muestra el gráfico de la muestra y tres
## gráficos de referencia. El jugador elige cuál coincide. Dos intentos por ronda:
## si falla los dos, la muestra "se degrada" y esa ronda no da dato (se pierde información,
## no hay game over).
##
## Datos (JSON): rondas[{pregunta, etiquetas[], muestra[], opciones[{nombre, valores[], dato}], correcta}]

const MAX_INTENTOS := 2

signal solicitar_dialogo_ronda(numero: int)
signal dialogo_ronda_finalizado


class Grafico extends Control:
	var valores: Array = []
	var etiquetas: Array = []
	var color_barra: Color = Color(0.30, 0.85, 0.95)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.07), true)
		# líneas guía horizontales
		for k in range(1, 5):
			var yy: float = 14.0 + (size.y - 58.0) * k / 5.0
			draw_line(Vector2(6, yy), Vector2(size.x - 6, yy), Color(MinijuegoBase.COLOR_ACENTO, 0.10), 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), MinijuegoBase.COLOR_BORDE, false, 2.0)
		var n: int = valores.size()
		if n == 0:
			return
		var fuente: Font = get_theme_default_font()
		var margen: float = 14.0
		var alto_etiqueta: float = 30.0
		var ancho_col: float = (size.x - margen * 2.0) / n
		var alto_util: float = size.y - margen * 2.0 - alto_etiqueta
		for i in range(n):
			var v: float = clampf(float(valores[i]) / 100.0, 0.0, 1.0)
			var h: float = alto_util * v
			var x: float = margen + i * ancho_col
			draw_rect(Rect2(x + ancho_col * 0.15, margen + alto_util - h, ancho_col * 0.7, h), color_barra)
			if fuente != null and i < etiquetas.size():
				draw_string(fuente, Vector2(x, size.y - 9.0), str(etiquetas[i]),
					HORIZONTAL_ALIGNMENT_CENTER, ancho_col, 22, Color(0.82, 0.82, 0.88))


var _ronda: int = 0
var _aciertos: int = 0
var _lineas: Array = []
var _intentos: int = 0
var _contenido: VBoxContainer
var _etq_pregunta: Label
var _zona_graficos: HBoxContainer
var _etq_feedback: Label
var _boton_continuar: Button
var _botones_opcion: Array[Button] = []


func _construir() -> void:
	var caja := crear_marco_central(Vector2(1640, 900))
	caja.add_child(crear_titulo(str(datos.get("titulo", "Analizador de material"))))
	_etq_pregunta = crear_label("", t_texto(), COLOR_TEXTO)
	caja.add_child(_etq_pregunta)
	_zona_graficos = HBoxContainer.new()
	_zona_graficos.add_theme_constant_override("separation", 26)
	_zona_graficos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(_zona_graficos)
	_etq_feedback = crear_label("", t_texto(), COLOR_TEXTO)
	caja.add_child(_etq_feedback)
	_boton_continuar = crear_boton("Continuar", 300)
	_boton_continuar.pressed.connect(_siguiente_ronda)
	_boton_continuar.visible = false
	poner_en_estado(_boton_continuar, caja)
	_mostrar_ronda()


func _rondas() -> Array:
	return datos.get("rondas", [])


func _mostrar_ronda() -> void:
	var rondas: Array = _rondas()
	if _ronda >= rondas.size():
		_finalizar()
		return
	var r: Dictionary = rondas[_ronda]
	_intentos = 0
	_botones_opcion.clear()
	_boton_continuar.visible = false
	_etq_feedback.text = ""
	_etq_feedback.add_theme_color_override("font_color", COLOR_TEXTO)
	_etq_pregunta.text = "Muestra %d de %d. %s" % [_ronda + 1, rondas.size(), str(r.get("pregunta", ""))]
	for hijo in _zona_graficos.get_children():
		hijo.queue_free()

	var etiquetas: Array = r.get("etiquetas", [])

	# Columna de la muestra
	var col_muestra := VBoxContainer.new()
	col_muestra.add_theme_constant_override("separation", 8)
	col_muestra.custom_minimum_size = Vector2(420, 0)
	col_muestra.add_child(crear_label("Muestra", t_texto(), COLOR_ACENTO))
	var g := Grafico.new()
	g.valores = r.get("muestra", [])
	g.etiquetas = etiquetas
	g.color_barra = COLOR_ACENTO
	g.custom_minimum_size = Vector2(420, 480)
	col_muestra.add_child(g)
	_zona_graficos.add_child(col_muestra)

	# Una columna por cada referencia
	var opciones: Array = r.get("opciones", [])
	for i in range(opciones.size()):
		var op: Dictionary = opciones[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.custom_minimum_size = Vector2(320, 0)
		col.add_child(crear_label(str(op.get("nombre", "")), t_texto(), COLOR_TITULO))
		var gr := Grafico.new()
		gr.valores = op.get("valores", [])
		gr.etiquetas = etiquetas
		gr.color_barra = Color(0.78, 0.78, 0.86)
		gr.custom_minimum_size = Vector2(320, 400)
		col.add_child(gr)
		var b := crear_boton("Es esta", 320)
		b.pressed.connect(_elegir.bind(i))
		col.add_child(b)
		_botones_opcion.append(b)
		_zona_graficos.add_child(col)


func _elegir(indice: int) -> void:
	var r: Dictionary = _rondas()[_ronda]
	var opciones: Array = r.get("opciones", [])
	var correcta: int = int(r.get("correcta", 0))
	if indice == correcta:
		_aciertos += 1
		var op: Dictionary = opciones[indice]
		var dato: String = str(op.get("dato", ""))
		if dato != "":
			_lineas.append(dato)
		_etq_feedback.text = "Coincide. " + dato
		_etq_feedback.add_theme_color_override("font_color", COLOR_OK)
		_cerrar_ronda()
		return

	_intentos += 1
	if _intentos >= MAX_INTENTOS:
		_etq_feedback.text = "No coincide. La muestra se degradó y no se pudo identificar."
		_etq_feedback.add_theme_color_override("font_color", COLOR_ERROR)
		_cerrar_ronda()
	else:
		_etq_feedback.text = "No coincide. Fijate en la altura de las barras. Queda un intento."
		_etq_feedback.add_theme_color_override("font_color", COLOR_ERROR)
		_botones_opcion[indice].disabled = true


func _cerrar_ronda() -> void:
	for b in _botones_opcion:
		b.disabled = true
	_boton_continuar.visible = true
	if _ronda >= _rondas().size() - 1:
		_boton_continuar.text = "Registrar resultado"


func _siguiente_ronda() -> void:
	_ronda += 1
	if _ronda == 1:
		bloquear_interaccion(true)
		solicitar_dialogo_ronda.emit(_ronda + 1)
		await dialogo_ronda_finalizado
	_mostrar_ronda()


func _finalizar() -> void:
	var total: int = _rondas().size()
	var datos_finales: Array = _lineas.duplicate()
	if datos_finales.is_empty():
		datos_finales.append("No se pudo identificar la muestra.")
	terminado.emit({
		"estacion": "composicion",
		"util": bool(datos.get("util", true)),
		"calidad": 1.0 if total == 0 else float(_aciertos) / float(total),
		"datos": datos_finales,
	})
