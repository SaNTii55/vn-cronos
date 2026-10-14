extends Node
## Opciones del jugador: pantalla completa, velocidad del texto y volumen.
## Se guardan en un archivo aparte de la partida y se recuerdan al reabrir el juego.

const RUTA := "user://ajustes.cfg"

# Segundos que tarda en escribirse cada letra. 0 = el texto aparece de golpe.
const VELOCIDADES := [0.035, 0.018, 0.008, 0.0]
const NOMBRES_VELOCIDAD := ["Lenta", "Normal", "Rápida", "Instantánea"]

var pantalla_completa: bool = false
var velocidad_indice: int = 1
var volumen: float = 1.0   # de 0.0 a 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cargar()
	aplicar()

func segundos_por_caracter() -> float:
	return float(VELOCIDADES[velocidad_indice])

func nombre_velocidad() -> String:
	return str(NOMBRES_VELOCIDAD[velocidad_indice])

func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	pantalla_completa = bool(cfg.get_value("ajustes", "pantalla_completa", false))
	velocidad_indice = clampi(int(cfg.get_value("ajustes", "velocidad_indice", 1)), 0, VELOCIDADES.size() - 1)
	volumen = clampf(float(cfg.get_value("ajustes", "volumen", 1.0)), 0.0, 1.0)

func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ajustes", "pantalla_completa", pantalla_completa)
	cfg.set_value("ajustes", "velocidad_indice", velocidad_indice)
	cfg.set_value("ajustes", "volumen", volumen)
	cfg.save(RUTA)

func aplicar() -> void:
	if pantalla_completa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volumen <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volumen, 0.001)))

func set_pantalla_completa(valor: bool) -> void:
	pantalla_completa = valor
	aplicar()
	guardar()

func ciclar_velocidad() -> void:
	velocidad_indice = (velocidad_indice + 1) % VELOCIDADES.size()
	guardar()

func set_volumen(valor: float) -> void:
	volumen = clampf(valor, 0.0, 1.0)
	aplicar()
	guardar()
