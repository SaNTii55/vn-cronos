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
	var resultado: Dictionary = _leer_bloque(ruta, true)
	if resultado.is_empty():
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


## true si existe el archivo y, cuando la ruta lleva "#clave", también esa clave.
static func existe(ruta: String) -> bool:
	return not _leer_bloque(ruta, false).is_empty()


## Separa "archivo.json#clave" en [archivo, clave]. Sin "#", la clave queda vacía.
static func _partir_ruta(ruta: String) -> Array:
	var pos: int = ruta.find("#")
	if pos == -1:
		return [ruta, ""]
	return [ruta.substr(0, pos), ruta.substr(pos + 1)]


## Lee el archivo completo o el bloque identificado por una clave.
## Devuelve {} si algo falla. Con avisar = true, deja el motivo en la consola.
static func _leer_bloque(ruta: String, avisar: bool) -> Dictionary:
	var partes: Array = _partir_ruta(ruta)
	var ruta_archivo: String = partes[0]
	var clave: String = partes[1]

	if not FileAccess.file_exists(ruta_archivo):
		if avisar:
			push_error("No se encontró el archivo de diálogo: " + ruta_archivo)
		return {}

	var archivo := FileAccess.open(ruta_archivo, FileAccess.READ)
	if archivo == null:
		if avisar:
			push_error("No se pudo abrir el archivo de diálogo: " + ruta_archivo)
		return {}
	var resultado = JSON.parse_string(archivo.get_as_text())
	archivo.close()

	if typeof(resultado) != TYPE_DICTIONARY:
		if avisar:
			push_error("JSON inválido en " + ruta_archivo)
		return {}

	if clave == "":
		return resultado

	var bloque = resultado.get(clave)
	if typeof(bloque) != TYPE_DICTIONARY:
		if avisar:
			push_error("No existe la clave '%s' en %s" % [clave, ruta_archivo])
		return {}
	return bloque


func _reconstruir_mapa_ids() -> void:
	mapa_ids.clear()
	for i in range(datos_dialogos.size()):
		var linea = datos_dialogos[i]
		if linea.has("id"):
			mapa_ids[int(linea["id"])] = i


func iniciar() -> void:
	mostrar_linea_actual()


## Coloca el diálogo en un id guardado sin mostrarlo todavía.
func posicionar_en_id(id_linea: int) -> bool:
	if not mapa_ids.has(id_linea):
		push_error("ID de diálogo no encontrado al reanudar: %d" % id_linea)
		return false
	indice_actual = mapa_ids[id_linea]
	decision_pendiente = false
	return true


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

	# Línea lógica: no se muestra. Salta al resultado según las opciones ya leídas.
	if linea.has("segun_lecturas"):
		_saltar_segun_lecturas(linea["segun_lecturas"])
		return

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

	# Se muestran solo las opciones que no están ocultas por "oculta_si_leida".
	var visibles: Array = []
	for op in linea.get("opciones", []):
		if not _opcion_oculta(op):
			visibles.append(op)
	if visibles.is_empty():
		push_warning("Todas las opciones de la decisión %d están ocultas; se muestran todas." % id_decision)
		visibles = linea.get("opciones", [])

	choices_ready.emit(id_decision, pista, visibles, leidas)


## Una opción con "oculta_si_leida": 20 no se muestra si la respuesta con id 20
## ya se leyó, en cualquier decisión de este día. Sirve para ofrecer en una segunda
## pregunta solo lo que no se eligió en la primera.
func _opcion_oculta(op) -> bool:
	if not op.has("oculta_si_leida"):
		return false
	var id_leido: int = int(op["oculta_si_leida"])
	for ids in opciones_leidas.values():
		if ids.has(id_leido):
			return true
	return false


## Elige un destino según cuántas opciones de una decisión se leyeron.
## Se puede indicar "otro" como destino alternativo si el conteo no está enumerado.
func _saltar_segun_lecturas(regla) -> void:
	if typeof(regla) != TYPE_DICTIONARY:
		push_error("'segun_lecturas' tiene que ser un diccionario.")
		_continuar_tras_error_logico()
		return

	var id_decision: int = int(regla.get("decision", -1))
	var leidas: Array = opciones_leidas.get(id_decision, [])
	var clave: String = str(leidas.size())
	if not regla.has(clave):
		clave = "otro"
	if not regla.has(clave):
		push_error("'segun_lecturas' no tiene destino para %d lecturas de la decisión %d." % [leidas.size(), id_decision])
		_continuar_tras_error_logico()
		return
	ir_exacto_a_id(regla[clave])


# Si una línea lógica está mal configurada, continúa con la siguiente línea.
func _continuar_tras_error_logico() -> void:
	if indice_actual >= datos_dialogos.size() - 1:
		scene_ended.emit(ruta_siguiente_escena)
		return
	indice_actual += 1
	mostrar_linea_actual()
