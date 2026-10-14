class_name FichaEvidencia
extends MinijuegoBase
## Ficha de una evidencia (qué es / qué sabemos / qué no sabemos / nota histórica).
## Con modo_clasificar = true, a la derecha el jugador clasifica cada afirmación como
## hecho, hipótesis o desconocido.
## Regla: si para respaldar una afirmación hacía falta un análisis que NO se hizo,
## la respuesta correcta para el jugador es "desconocido" (se pierde información).

const MAX_INTENTOS := 3
const ESTADOS := [
	["hecho", "Hecho"],
	["hipotesis", "Hipótesis"],
	["desconocido", "Desconocido"],
]

var modo_clasificar: bool = false

var _id: String = ""
var _col_ficha: VBoxContainer
var _col_claims: VBoxContainer
var _scroll_claims: ScrollContainer
var _filas: Array = []
var _intentos: int = 0
var _listo: bool = false
var _boton_principal: Button
var _etq_mensaje: Label


func _construir() -> void:
	_id = str(datos.get("id", ""))
	var ficha: Dictionary = datos.get("ficha", {})
	var caja := crear_marco_central(Vector2(1740, 920))
	caja.add_child(crear_titulo(str(datos.get("nombre", "Evidencia"))))
	
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 24)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(cuerpo)

	# Columna izquierda: la ficha
	var scroll_ficha := ScrollContainer.new()
	scroll_ficha.custom_minimum_size = Vector2(640 if modo_clasificar else 0, 680)
	scroll_ficha.size_flags_horizontal = Control.SIZE_FILL if modo_clasificar else Control.SIZE_EXPAND_FILL
	scroll_ficha.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll_ficha)
	_col_ficha = VBoxContainer.new()
	_col_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_ficha.add_theme_constant_override("separation", 10)
	scroll_ficha.add_child(_col_ficha)

	_agregar_seccion(_col_ficha, "Qué es", [str(ficha.get("que_es", ""))])

	var sabemos: Array = []
	for s in ficha.get("sabemos", []):
		var req: String = str(s.get("requiere", ""))
		if req == "" or Evidencias.ya_analizada(_id, req):
			sabemos.append(str(s.get("texto", "")))
	if sabemos.is_empty():
		sabemos.append("Todavía no hay datos. Falta analizar la pieza.")
	_agregar_seccion(_col_ficha, "Qué sabemos", sabemos)

	var no_sabemos: Array = ficha.get("no_sabemos", [])
	if not no_sabemos.is_empty():
		_agregar_seccion(_col_ficha, "Qué no sabemos", no_sabemos)

	if not modo_clasificar:
		if Evidencias.esta_cerrada(_id):
			_agregar_seccion(_col_ficha, "Nota histórica", [str(ficha.get("nota_historica", ""))])
		return

	# Columna derecha: clasificación
	_scroll_claims = ScrollContainer.new()
	_scroll_claims.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_claims.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(_scroll_claims)
	_col_claims = VBoxContainer.new()
	_col_claims.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_claims.add_theme_constant_override("separation", 10)
	_scroll_claims.add_child(_col_claims)

	_col_claims.add_child(crear_label("Clasificá cada afirmación", t_texto() + 4, COLOR_ACENTO))
	_col_claims.add_child(crear_label(
		"Hecho: lo respalda un dato. Hipótesis: es una explicación posible. Desconocido: no hay con qué decidirlo.",
		t_texto() - 4, COLOR_APAGADO))
	for a in datos.get("afirmaciones", []):
		_agregar_fila(a)

	_etq_mensaje = crear_label("", t_texto(), COLOR_TEXTO)
	caja.add_child(_etq_mensaje)
	_boton_principal = crear_boton("Verificar", 320)
	_boton_principal.pressed.connect(_on_principal)
	poner_en_estado(_boton_principal, caja)

func _agregar_seccion(destino: VBoxContainer, titulo: String, lineas: Array) -> Label:
	destino.add_child(crear_label(titulo, t_texto() + 4, COLOR_ACENTO))
	var ultimo: Label = null
	for linea in lineas:
		var prefijo: String = "" if lineas.size() == 1 else "- "
		ultimo = crear_label(prefijo + str(linea), t_texto() - 2, COLOR_TEXTO)
		destino.add_child(ultimo)
	return ultimo


func _agregar_fila(a: Dictionary) -> void:
	var req: String = str(a.get("requiere", ""))
	var falta: bool = req != "" and not Evidencias.ya_analizada(_id, req)
	var esperado: String = "desconocido" if falta else str(a.get("correcta", "desconocido"))

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	_col_claims.add_child(fila)

	var col_texto := VBoxContainer.new()
	col_texto.custom_minimum_size = Vector2(340, 0)
	col_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_texto.add_child(crear_label(str(a.get("texto", "")), t_texto() - 2, COLOR_TEXTO))
	if falta:
		var nombre: String = str(Evidencias.NOMBRES_ESTACION.get(req, req))
		col_texto.add_child(crear_label("(Falta el análisis de " + nombre + ")", t_texto() - 6, COLOR_APAGADO))
	fila.add_child(col_texto)

	var grupo := ButtonGroup.new()
	for par in ESTADOS:
		var b := crear_boton(str(par[1]), 165, t_texto() - 6)
		b.toggle_mode = true
		b.button_group = grupo
		b.set_meta("estado", str(par[0]))
		fila.add_child(b)

	var marca := crear_label("", t_texto() - 6, COLOR_TEXTO)
	marca.custom_minimum_size = Vector2(175, 0)
	marca.size_flags_horizontal = Control.SIZE_SHRINK_END
	fila.add_child(marca)

	var explicacion := crear_label("", t_texto() - 6, COLOR_APAGADO)
	explicacion.visible = false
	_col_claims.add_child(explicacion)

	_filas.append({
		"texto": str(a.get("texto", "")),
		"esperado": esperado,
		"explicacion_texto": str(a.get("explicacion", "")),
		"grupo": grupo,
		"marca": marca,
		"explicacion": explicacion,
		"elegido": "",
	})


func _on_principal() -> void:
	if _listo:
		_emitir_final()
	else:
		_verificar()


func _verificar() -> void:
	_intentos += 1
	var mal: int = 0
	for fila in _filas:
		var grupo: ButtonGroup = fila["grupo"]
		var marca: Label = fila["marca"]
		var boton: BaseButton = grupo.get_pressed_button()
		var elegido: String = "" if boton == null else str(boton.get_meta("estado"))
		fila["elegido"] = elegido
		if elegido == str(fila["esperado"]):
			marca.text = "Bien"
			marca.add_theme_color_override("font_color", COLOR_OK)
		else:
			mal += 1
			marca.text = "Sin clasificar" if elegido == "" else "Revisá"
			marca.add_theme_color_override("font_color", COLOR_ERROR)

	if mal == 0:
		_etq_mensaje.text = "Todo clasificado. Esto es lo que se puede sostener con la evidencia reunida."
		_etq_mensaje.add_theme_color_override("font_color", COLOR_OK)
		_cerrar_clasificacion()
	elif _intentos >= MAX_INTENTOS:
		_etq_mensaje.text = "Veamos juntos qué se puede sostener y qué no."
		_etq_mensaje.add_theme_color_override("font_color", COLOR_TEXTO)
		for fila in _filas:
			if str(fila["elegido"]) != str(fila["esperado"]):
				var marca: Label = fila["marca"]
				marca.text = "Era: " + _nombre_estado(str(fila["esperado"]))
				var explicacion: Label = fila["explicacion"]
				explicacion.text = str(fila["explicacion_texto"])
				explicacion.visible = true
		_cerrar_clasificacion()
	else:
		_etq_mensaje.text = "Hay %d sin ajustar. Podés cambiarlas y verificar de nuevo." % mal
		_etq_mensaje.add_theme_color_override("font_color", COLOR_ERROR)


func _nombre_estado(clave: String) -> String:
	for par in ESTADOS:
		if str(par[0]) == clave:
			return str(par[1])
	return clave


func _cerrar_clasificacion() -> void:
	_listo = true
	_boton_principal.text = "Continuar"
	var ficha: Dictionary = datos.get("ficha", {})
	var ultimo: Label = _agregar_seccion(_col_claims, "Nota histórica", [str(ficha.get("nota_historica", ""))])
	# Baja hasta la nota para que se vea
	await get_tree().process_frame
	if is_instance_valid(ultimo) and is_instance_valid(_scroll_claims):
		_scroll_claims.ensure_control_visible(ultimo)


func _emitir_final() -> void:
	var clasificacion: Dictionary = {}
	var correctas: int = 0
	for fila in _filas:
		clasificacion[str(fila["texto"])] = str(fila["elegido"])
		if str(fila["elegido"]) == str(fila["esperado"]):
			correctas += 1
	Evidencias.guardar_clasificacion(_id, clasificacion)
	terminado.emit({
		"estacion": "clasificacion",
		"calidad": 1.0 if _filas.is_empty() else float(correctas) / float(_filas.size()),
		"intentos": _intentos,
	})
