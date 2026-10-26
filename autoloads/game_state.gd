extends Node

const RUTA_GUARDADO := "user://partida.save"
const VERSION_GUARDADO := 3

# Cada vez que cambia el JSON actual, se invalida el punto de reanudación anterior.
var ruta_json_actual: String = "res://data/C1_E0.json":
	set(valor):
		limpiar_punto()
		ruta_json_actual = valor
var nombre_jugador: String = "Viajero"

# Punto de reanudación dentro del JSON actual. Si en_escena es true, el id
# identifica la línea que abre la escena especial que debe retomarse.
var punto_ruta: String = ""
var punto_id: int = 0
var punto_en_escena: bool = false
var punto_lecturas: Dictionary = {}


func limpiar_punto() -> void:
	punto_ruta = ""
	punto_id = 0
	punto_en_escena = false
	punto_lecturas = {}

# Guarda el progreso en disco (ruta, punto, nombre y estado de las evidencias).
# silencioso = true: no muestra el aviso "Partida guardada" (para autoguardados internos).
func guardar_partida(silencioso: bool = false) -> bool:
	var datos := {
		"version": VERSION_GUARDADO,
		"nombre_jugador": nombre_jugador,
		"ruta_json_actual": ruta_json_actual,
		"punto": {
			"ruta": punto_ruta,
			"id": punto_id,
			"en_escena": punto_en_escena,
			"lecturas": punto_lecturas,
		},
		"evidencias": Evidencias.exportar(),
	}

	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar la partida. Error: " + str(FileAccess.get_open_error()))
		Notificaciones.mostrar("No se pudo guardar la partida", true)
		return false

	archivo.store_string(JSON.stringify(datos))
	archivo.close()
	if not silencioso:
		Notificaciones.mostrar("Partida guardada")
	return true

func cargar_partida() -> bool:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		return false

	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if archivo == null:
		return false
	var resultado = JSON.parse_string(archivo.get_as_text())
	archivo.close()

	if typeof(resultado) != TYPE_DICTIONARY:
		return false

	nombre_jugador = str(resultado.get("nombre_jugador", nombre_jugador))
	ruta_json_actual = str(resultado.get("ruta_json_actual", ruta_json_actual))
	limpiar_punto()
	var punto = resultado.get("punto", {})
	if typeof(punto) == TYPE_DICTIONARY:
		punto_ruta = str(punto.get("ruta", ""))
		punto_id = int(punto.get("id", 0))
		punto_en_escena = bool(punto.get("en_escena", false))
		punto_lecturas = _leer_lecturas(punto.get("lecturas", {}))
	# Si el guardado es viejo y no trae evidencias, queda todo en cero.
	Evidencias.importar(resultado.get("evidencias", {}))
	_migrar_ruta_provisional_anterior()
	if punto_id != 0 and not punto_valido():
		limpiar_punto()
	return true


# En el archivo guardado las claves son texto (por ejemplo, "12"); el runner usa números.
func _leer_lecturas(crudo) -> Dictionary:
	var resultado: Dictionary = {}
	if typeof(crudo) != TYPE_DICTIONARY:
		return resultado
	for clave in crudo:
		var ids: Array = []
		if typeof(crudo[clave]) == TYPE_ARRAY:
			for id in crudo[clave]:
				ids.append(int(id))
		resultado[int(clave)] = ids
	return resultado


func punto_valido() -> bool:
	return punto_id != 0 and punto_ruta == ruta_json_actual


func _migrar_ruta_provisional_anterior() -> void:
	# Convierte partidas guardadas con el parche provisional o con la ruta vieja.
	var analisis: Dictionary = Evidencias.resultados("hueso_vaca")
	if ruta_json_actual == "res://data/C2_E2_REANUDAR.json":
		if analisis.size() >= 3:
			ruta_json_actual = "res://data/C2_E2.json"
			punto_ruta = ruta_json_actual
			punto_id = 11
			punto_en_escena = false
		elif not analisis.is_empty():
			ruta_json_actual = "res://data/C2_E2.json"
			punto_ruta = ruta_json_actual
			punto_id = 10
			punto_en_escena = true
		else:
			ruta_json_actual = "res://data/C2_E2.json"
		return

	# En partidas anteriores, el resultado de la prueba se guardaba antes que
	# la ruta de reanudación. Si quedó así, reconstruimos el punto desde la ficha.
	if ruta_json_actual != "res://data/C2_E2.json" or punto_id != 0 or analisis.is_empty():
		return
	if analisis.size() >= 3:
		punto_ruta = ruta_json_actual
		punto_id = 11
		punto_en_escena = false
	else:
		punto_ruta = ruta_json_actual
		punto_id = 10
		punto_en_escena = true

func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)
