extends Node
## Autoload "Evidencias".
## - Lee las fichas de res://data/evidencias/<id>.json
## - Mantiene en memoria qué análisis se hicieron de cada pieza.
## - El guardado en disco lo hace GameState (partida.save): este autoload
##   solo entrega su estado con exportar() y lo recibe con importar().
## Para registrarlo: Proyecto > Configuración del proyecto > Globales (Autoload),
## ruta res://autoloads/evidencias.gd, nombre "Evidencias".

signal analisis_registrado(id_evidencia: String, estacion: String)

const CARPETA_FICHAS := "res://data/evidencias/"
const MUESTRAS_POR_PIEZA := 2
const NOMBRES_ESTACION := {
	"composicion": "Composición",
	"microscopio": "Microscopio",
	"reconstruccion": "Reconstrucción",
}

var _fichas: Dictionary = {}
var _estado: Dictionary = {}


# ---------------------------------------------------------------
# FICHAS (datos fijos del JSON)
# ---------------------------------------------------------------

func ficha(id: String) -> Dictionary:
	if _fichas.has(id):
		return _fichas[id]
	var ruta: String = CARPETA_FICHAS + id + ".json"
	if not FileAccess.file_exists(ruta):
		push_error("No existe la ficha de evidencia: " + ruta)
		return {}
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir: " + ruta)
		return {}
	var resultado = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if typeof(resultado) != TYPE_DICTIONARY:
		push_error("JSON inválido en " + ruta)
		return {}
	_fichas[id] = resultado
	return resultado


# ---------------------------------------------------------------
# ESTADO (lo que hizo el jugador)
# ---------------------------------------------------------------

## Cantidad de muestras con que arranca esta pieza (clave "muestras" de su JSON).
func muestras_totales(id: String) -> int:
	return int(ficha(id).get("muestras", MUESTRAS_POR_PIEZA))


func muestras_restantes(id: String) -> int:
	return int(_estado_de(id).get("muestras", MUESTRAS_POR_PIEZA))


func ya_analizada(id: String, estacion: String) -> bool:
	var analisis: Dictionary = _estado_de(id)["analisis"]
	return analisis.has(estacion)


func puede_analizar(id: String, estacion: String) -> bool:
	return muestras_restantes(id) > 0 and not ya_analizada(id, estacion)


func resultados(id: String) -> Dictionary:
	return _estado_de(id)["analisis"]


## Registra el resultado de una estación y gasta una muestra.
## Autoguarda en silencio dentro de la partida.
func registrar_analisis(id: String, estacion: String, resultado: Dictionary) -> void:
	var estado: Dictionary = _estado_de(id)
	var analisis: Dictionary = estado["analisis"]
	if analisis.has(estacion):
		return
	analisis[estacion] = resultado
	estado["muestras"] = maxi(0, int(estado["muestras"]) - 1)
	GameState.guardar_partida(true)
	analisis_registrado.emit(id, estacion)


func guardar_clasificacion(id: String, clasificacion: Dictionary) -> void:
	var estado: Dictionary = _estado_de(id)
	estado["clasificacion"] = clasificacion
	estado["cerrada"] = true
	GameState.guardar_partida(true)


func esta_cerrada(id: String) -> bool:
	return bool(_estado_de(id).get("cerrada", false))


## Ids de las evidencias que el jugador ya tocó (para el menú de evidencias).
func evidencias_vistas() -> Array:
	var ids: Array = []
	for id in _estado:
		var e: Dictionary = _estado[id]
		var analisis: Dictionary = e["analisis"]
		if analisis.size() > 0 or bool(e.get("cerrada", false)):
			ids.append(id)
	return ids


## Llamar al empezar una partida nueva. No escribe en disco:
## el estado limpio se guarda con el próximo guardado normal.
func reiniciar_todo() -> void:
	_estado.clear()


func reiniciar_evidencia(id: String) -> void:
	_estado.erase(id)


# ---------------------------------------------------------------
# GUARDADO (lo usa GameState)
# ---------------------------------------------------------------

## Copia del estado para meter dentro de partida.save.
func exportar() -> Dictionary:
	return _estado.duplicate(true)


## Recibe el estado leído de partida.save. Descarta lo que esté roto.
func importar(datos) -> void:
	_estado.clear()
	if typeof(datos) != TYPE_DICTIONARY:
		return
	for id in datos:
		var e = datos[id]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var analisis = e.get("analisis", {})
		var clasificacion = e.get("clasificacion", {})
		_estado[str(id)] = {
			"muestras": int(e.get("muestras", MUESTRAS_POR_PIEZA)),
			"analisis": analisis if typeof(analisis) == TYPE_DICTIONARY else {},
			"clasificacion": clasificacion if typeof(clasificacion) == TYPE_DICTIONARY else {},
			"cerrada": bool(e.get("cerrada", false)),
		}


# ---------------------------------------------------------------
# INTERNO
# ---------------------------------------------------------------

func _estado_de(id: String) -> Dictionary:
	if not _estado.has(id):
		_estado[id] = {
			"muestras": muestras_totales(id),
			"analisis": {},
			"clasificacion": {},
			"cerrada": false,
		}
	return _estado[id]
