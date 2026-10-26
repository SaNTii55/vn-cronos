extends Node

# --- Ajustes de tiempos (en segundos) ---
const DURACION_FUNDIDO := 0.4       # cuánto tarda en aclararse la pantalla
const PAUSA_TRAS_FUNDIDO := 0.1     # respiro entre que termina el fundido y aparece la caja
# ----------------------------------------

const RUTA_INICIO := "res://escenas/Inicio.tscn"

# Escenas especiales que una línea del JSON puede abrir con "escena_especial": "nombre".
# Cada una debe tener un script con:
#   signal terminada
#   func iniciar(principal: Node, linea: Dictionary) -> void
const ESCENAS_ESPECIALES := {
	"laboratorio": "res://escenas/Laboratorio.tscn",
}

@onready var caja_dialogo: DialogueBox = $CajaDialogo
@onready var escenario: CharacterStage = $Escenario
@onready var menu_opciones: ChoiceMenu = $MenuOpciones

var fondo_imagen: TextureRect
var runner: DialogueRunner
var pausa: MenuPausa
var esperando_opcion: bool = false
var bloqueado: bool = false
var dia_cerrado: bool = false
var escena_especial_activa: Node = null
var _saliendo: bool = false   # true cuando ya se está yendo a otra escena

func _ready() -> void:
	bloqueado = true   # ignorar clics hasta que arranque el diálogo (B1)
	_crear_fondo()

	pausa = MenuPausa.new()
	add_child(pausa)

	runner = DialogueRunner.new()
	runner.line_ready.connect(_on_line_ready)
	runner.choices_ready.connect(_on_choices_ready)
	runner.scene_ended.connect(_on_scene_ended)
	menu_opciones.opcion_elegida.connect(_on_opcion_elegida)

	if runner.cargar_json(GameState.ruta_json_actual):
		var reanudar_en_escena := false
		if GameState.punto_valido():
			runner.opciones_leidas = GameState.punto_lecturas.duplicate(true)
			if runner.posicionar_en_id(GameState.punto_id):
				reanudar_en_escena = GameState.punto_en_escena and runner.linea_actual().has("escena_especial")
				if GameState.punto_en_escena and not reanudar_en_escena:
					push_warning("El punto guardado no abre una escena especial; se reinicia este diálogo.")
					GameState.limpiar_punto()
					runner.cargar_json(GameState.ruta_json_actual)
			else:
				GameState.limpiar_punto()
		_aplicar_fondo(runner.fondo)
		await SceneTransition.fundir_entrada(DURACION_FUNDIDO)
		await get_tree().create_timer(PAUSA_TRAS_FUNDIDO).timeout
		if reanudar_en_escena:
			await _lanzar_escena_especial(runner.linea_actual())
		else:
			await caja_dialogo.entrar()
			bloqueado = false
			runner.iniciar()
	else:
		bloqueado = false
		SceneTransition.fundir_entrada(DURACION_FUNDIDO)

func _crear_fondo() -> void:
	fondo_imagen = TextureRect.new()
	fondo_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo_imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo_imagen)
	move_child(fondo_imagen, 0)
	fondo_imagen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _aplicar_fondo(ruta: String) -> void:
	if ruta == "":
		fondo_imagen.texture = null
		return
	if ResourceLoader.exists(ruta):
		fondo_imagen.texture = load(ruta)
	else:
		push_warning("No se encontró el fondo: " + ruta)

# Para las escenas especiales: cambia el fondo de la escena.
func cambiar_fondo(ruta: String) -> void:
	_aplicar_fondo(ruta)

func _bloquear() -> void:
	bloqueado = true
	pausa.permitido = false

func _on_line_ready(linea: Dictionary, id_linea: int) -> void:
	esperando_opcion = false

	# Guarda el punto y las respuestas ya leídas del diálogo principal.
	# Las líneas internas de una escena especial no cambian el punto de reanudación.
	if escena_especial_activa == null:
		GameState.punto_ruta = GameState.ruta_json_actual
		GameState.punto_id = id_linea
		GameState.punto_en_escena = false
		GameState.punto_lecturas = runner.opciones_leidas.duplicate(true)

	var personaje = str(linea.get("personaje", ""))
	var centrado = bool(linea.get("centrado", false))
	var texto = str(linea.get("texto", "")).replace("{nombre}", GameState.nombre_jugador)

	# Personajes que salen de escena en esta línea: "sale": "Vera" o "sale": ["Vera", "Iris"]
	var sale = linea.get("sale", "")
	if typeof(sale) == TYPE_ARRAY:
		for nombre_que_sale in sale:
			escenario.retirar(str(nombre_que_sale))
	elif str(sale) != "":
		escenario.retirar(str(sale))

	var nombre_mostrado = personaje
	if centrado:
		nombre_mostrado = ""
		escenario.ocultar_todos()
	else:
		var oculto: bool = runner.nombre_oculto(id_linea) or bool(linea.get("nombre_oculto", false))
		if personaje != "" and oculto:
			nombre_mostrado = "..."
		escenario.mostrar(personaje, int(linea.get("expresion", 0)), str(linea.get("lado", "")))

	caja_dialogo.mostrar_linea(nombre_mostrado, texto, centrado)

	# Cierre de día: la línea marcada con "fin_de_dia" guarda el progreso
	if bool(linea.get("fin_de_dia", false)):
		_guardar_fin_de_dia()

func _guardar_fin_de_dia() -> void:
	dia_cerrado = true
	GameState.limpiar_punto()   # el día siguiente empieza desde su primera línea
	# El punto de guardado pasa a ser el comienzo de lo que sigue (si ya existe).
	# Solo si es un JSON de diálogo: una escena .tscn no se puede cargar como diálogo (B6).
	if runner.ruta_siguiente_escena.ends_with(".json"):
		GameState.ruta_json_actual = runner.ruta_siguiente_escena
	GameState.guardar_partida()

func _on_choices_ready(id_decision: int, pista: String, opciones: Array, leidas: Array) -> void:
	esperando_opcion = true

	# Sobre el menú aparece quien habla en la línea de decisión, salvo que la línea
	# indique otro con "foco_opciones" (y, opcionalmente, su "expresion_foco").
	var linea = runner.linea_actual()
	var personaje_foco = str(linea.get("foco_opciones", linea.get("personaje", "")))
	var texto_pista = pista.replace("{nombre}", GameState.nombre_jugador)

	await caja_dialogo.salir()

	# Si se indicó otro personaje, se le pone la expresión elegida mientras la caja está cerrada
	if linea.has("foco_opciones"):
		escenario.mostrar(personaje_foco, int(linea.get("expresion_foco", 0)))

	menu_opciones.mostrar_opciones(id_decision, texto_pista, opciones, leidas)
	var borde_superior = await menu_opciones.medir_borde_superior()
	await escenario.entrar_modo_opciones(personaje_foco, borde_superior)
	await menu_opciones.entrar()

func _on_opcion_elegida(siguiente_id: int, id_decision: int, es_salto: bool) -> void:
	# esperando_opcion sigue en true: los clics se ignoran mientras el menú se cierra (B2).
	# _on_line_ready lo pone en false cuando llega la siguiente línea.
	await menu_opciones.salir()
	await escenario.salir_modo_opciones()

	runner.elegir(id_decision, siguiente_id, es_salto)

	# Guarda la elección y el punto actualizado, sin mostrar una notificación.
	if escena_especial_activa == null and not _saliendo:
		GameState.punto_lecturas = runner.opciones_leidas.duplicate(true)
		GameState.guardar_partida(true)

	# Si lo que sigue es otra decisión (volver al menú), _on_choices_ready ya puso
	# esperando_opcion en true y no hay que abrir la caja (B3).
	if not esperando_opcion:
		await caja_dialogo.entrar()

func _on_scene_ended(ruta: String) -> void:
	if ruta != "":
		_saliendo = true
		_bloquear()
		SceneTransition.ir_a(ruta)
	elif dia_cerrado:
		# Fin del contenido disponible: se vuelve a la pantalla de inicio
		_saliendo = true
		_bloquear()
		SceneTransition.ir_a(RUTA_INICIO)
	else:
		print("Fin del capítulo o escena.")

# ---------------------------------------------------------------
# ESCENAS ESPECIALES
# ---------------------------------------------------------------

# Abre la escena indicada por la línea ("escena_especial") y, cuando termina,
# sigue con la línea siguiente del diálogo.
func _lanzar_escena_especial(linea: Dictionary) -> void:
	if escena_especial_activa != null:
		return
	var nombre := str(linea.get("escena_especial", ""))
	if not ESCENAS_ESPECIALES.has(nombre):
		push_error("Escena especial desconocida: " + nombre)
		runner.avanzar_dialogo()
		return
	var ruta: String = ESCENAS_ESPECIALES[nombre]
	if not ResourceLoader.exists(ruta):
		push_error("No existe la escena especial: " + ruta)
		runner.avanzar_dialogo()
		return

	bloqueado = true
	# La caja no se cierra acá: la escena especial decide cuándo hacerlo (cerrar_dialogo).

	var escena: Node = (load(ruta) as PackedScene).instantiate()
	escena_especial_activa = escena
	add_child(escena)
	move_child(escena, 1)   # encima del fondo, debajo de los personajes y la caja
	escena.iniciar(self, linea)
	await escena.terminada

	escena.queue_free()
	escena_especial_activa = null

	runner.avanzar_dialogo()
	if not esperando_opcion and not _saliendo:
		if not caja_dialogo.visible:
			await caja_dialogo.entrar()
	if not _saliendo:
		bloqueado = false

# Reproduce un JSON corto de diálogo con el mismo motor y espera a que termine.
# Lo usan las escenas especiales (guías, devoluciones, etc.).
# Dentro de una escena especial la caja NO se cierra al terminar: así, si enseguida
# empieza otro diálogo, continúa sin cerrarse y abrirse de nuevo. La escena especial
# la cierra cuando hace falta con cerrar_dialogo().
func reproducir_dialogo(ruta: String) -> void:
	var sub := DialogueRunner.new()
	if not sub.cargar_json(ruta) or sub.datos_dialogos.is_empty():
		push_error("No se pudo reproducir el diálogo: " + ruta)
		return

	var principal := runner
	runner = sub
	sub.line_ready.connect(_on_line_ready)
	sub.choices_ready.connect(_on_choices_ready)

	if sub.fondo != "":
		_aplicar_fondo(sub.fondo)

	if caja_dialogo.visible:
		# Viene de otro diálogo: la caja ya está abierta y la línea nueva reemplaza a la anterior.
		sub.iniciar()
	else:
		# Se carga la primera línea antes de abrir la caja, así no aparece vacía.
		bloqueado = true
		sub.iniciar()
		await caja_dialogo.entrar()
	bloqueado = false
	await sub.scene_ended

	if escena_especial_activa == null:
		bloqueado = true
		await caja_dialogo.salir()
		escenario.ocultar_todos()
	runner = principal
	# Si hay una escena especial abierta, sigue bloqueado para que ella reciba los clics.
	bloqueado = escena_especial_activa != null

# Cierra la caja y oculta los sprites. Lo usan las escenas especiales cuando
# necesitan la pantalla libre (si la caja ya está cerrada, no hace nada).
func cerrar_dialogo() -> void:
	if not caja_dialogo.visible:
		return
	bloqueado = true
	await caja_dialogo.salir()
	escenario.ocultar_todos()
	bloqueado = escena_especial_activa != null

func _input(event: InputEvent) -> void:
	# Con una escena especial abierta y la caja de diálogo oculta, el clic pertenece
	# a sus controles (zonas del laboratorio o minijuegos), no al diálogo principal.
	if escena_especial_activa != null and not caja_dialogo.visible:
		return

	if esperando_opcion or bloqueado:
		return

	var es_click = event is InputEventMouseButton and event.pressed
	var es_espacio = event is InputEventKey and event.pressed and event.keycode == KEY_SPACE

	if es_click or es_espacio:
		# Con una escena especial abierta, el clic de avanzar no debe llegar a sus botones.
		if escena_especial_activa != null:
			get_viewport().set_input_as_handled()

		if caja_dialogo.esta_escribiendo:
			caja_dialogo.completar_texto()
		elif runner.linea_actual().has("escena_especial") and not runner.decision_pendiente:
			_lanzar_escena_especial(runner.linea_actual())
		else:
			runner.avanzar_dialogo()
