class_name DialogueRunner
extends RefCounted

signal line_ready(linea: Dictionary, id_linea: int)
signal choices_ready(id_decision: int, pista: String, opciones: Array, leidas: Array)
signal scene_ended(ruta_siguiente: String)

var datos_dialogos: Array = []
var mapa_ids: Dictionary = {}
var fondo: String = ""
var ocultar_nombre_hasta_id: int = 0
var ruta_siguiente_escena: String = ""

var indice_actual: int = 0
var opciones_leidas: Dictionary = {}
var decision_pendiente: bool = false


func cargar_json(ruta: String) -> bool:
	if not FileAccess.file_exists(ruta):
		push_error("No se encontró el archivo de diálogo: " + ruta)
		return false

	var archivo = FileAccess.open(ruta, FileAccess.READ)
	var resultado = JSON.parse_string(archivo.get_as_text())
	archivo.close()

	if not resultado:
		push_error("JSON inválido en " + ruta)
		return false

	if not resultado.has("dialogos"):
		push_error("El JSON no tiene la clave 'dialogos' en " + ruta)
		return false

	fondo = str(resultado.get("fondo", ""))
	ocultar_nombre_hasta_id = int(resultado.get("ocultar_nombre_hasta_id", 0))
	ruta_siguiente_escena = str(resultado.get("siguiente_escena", ""))
	datos_dialogos = resultado["dialogos"]

	indice_actual = 0
	opciones_leidas.clear()
	decision_pendiente = false
	_reconstruir_mapa_ids()
	return true


func _reconstruir_mapa_ids() -> void:
	mapa_ids.clear()
	for i in range(datos_dialogos.size()):
		var linea = datos_dialogos[i]
		if linea.has("id"):
			mapa_ids[int(linea["id"])] = i


func iniciar() -> void:
	mostrar_linea_actual()


func linea_actual() -> Dictionary:
	if indice_actual < datos_dialogos.size():
		return datos_dialogos[indice_actual]
	return {}


func nombre_oculto(id_linea: int) -> bool:
	return ocultar_nombre_hasta_id > 0 and id_linea < ocultar_nombre_hasta_id


func avanzar_dialogo() -> void:
	if datos_dialogos.is_empty():
		return

	if decision_pendiente:
		decision_pendiente = false
		_emitir_opciones()
		return

	var linea = datos_dialogos[indice_actual]

	if linea.has("siguiente_id"):
		ir_exacto_a_id(linea["siguiente_id"])
		return
	if linea.has("converge_a"):
		ir_exacto_a_id(linea["converge_a"])
		return

	if indice_actual >= datos_dialogos.size() - 1:
		scene_ended.emit(ruta_siguiente_escena)
		return

	indice_actual += 1
	mostrar_linea_actual()


func ir_exacto_a_id(id_destino) -> void:
	var id_int = int(id_destino)
	if mapa_ids.has(id_int):
		indice_actual = mapa_ids[id_int]
		mostrar_linea_actual()
	else:
		push_error("ID de diálogo no encontrado: %d" % id_int)


func elegir(id_decision: int, siguiente_id: int, es_salto: bool) -> void:
	if not es_salto and id_decision != -1:
		if not opciones_leidas.has(id_decision):
			opciones_leidas[id_decision] = []
		if not opciones_leidas[id_decision].has(siguiente_id):
			opciones_leidas[id_decision].append(siguiente_id)
	ir_exacto_a_id(siguiente_id)


func mostrar_linea_actual() -> void:
	if indice_actual >= datos_dialogos.size():
		return

	var linea = datos_dialogos[indice_actual]
	var id_linea = int(linea.get("id", 0))
	decision_pendiente = false

	if linea.get("es_decision", false):
		var opciones = linea.get("opciones", [])
		var leidas = opciones_leidas.get(id_linea, [])

		var opciones_reales = []
		var destino_salto = -1
		for op in opciones:
			if bool(op.get("es_salto", false)):
				destino_salto = int(op.get("siguiente_id", -1))
			else:
				opciones_reales.append(op)

		var todas_leidas = opciones_reales.size() > 0
		for op in opciones_reales:
			if not leidas.has(int(op.get("siguiente_id", -1))):
				todas_leidas = false
				break

		if todas_leidas and destino_salto != -1:
			ir_exacto_a_id(destino_salto)
			return

		if leidas.size() > 0:
			_emitir_opciones()
			return

		decision_pendiente = true

	line_ready.emit(linea, id_linea)


func _emitir_opciones() -> void:
	var linea = datos_dialogos[indice_actual]
	var id_decision = int(linea.get("id", indice_actual))
	var pista = str(linea.get("pista", linea.get("texto", "")))
	var leidas = opciones_leidas.get(id_decision, [])
	choices_ready.emit(id_decision, pista, linea.get("opciones", []), leidas)
