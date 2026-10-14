extends Node

const RUTA_GUARDADO := "user://partida.save"
const VERSION_GUARDADO := 2

var ruta_json_actual: String = "res://data/C1_E0.json"
var nombre_jugador: String = "Viajero"

# Guarda el progreso en disco (ruta, nombre y estado de las evidencias).
# silencioso = true: no muestra el aviso "Partida guardada" (para autoguardados internos).
func guardar_partida(silencioso: bool = false) -> bool:
	var datos := {
		"version": VERSION_GUARDADO,
		"nombre_jugador": nombre_jugador,
		"ruta_json_actual": ruta_json_actual,
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
	# Si el guardado es viejo y no trae evidencias, queda todo en cero.
	Evidencias.importar(resultado.get("evidencias", {}))
	return true

func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)
