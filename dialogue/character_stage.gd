class_name CharacterStage
extends Control

const CARPETA_PERSONAJES := "res://assets/personajes/"

# Personajes que miran de frente: no se espejan cuando están a la derecha.
# El resto se supone que mira hacia la derecha, y se espeja al ir del lado derecho.
const DE_FRENTE := ["archiv"]

var sprite_izquierda: TextureRect
var sprite_derecha: TextureRect

var personaje_izquierda: String = ""
var personaje_derecha: String = ""

var posicion_inicial_izquierda: Vector2
var posicion_inicial_derecha: Vector2

var tween_mover: Tween = null
var cache_personajes: Dictionary = {}

# Sprite que está sobre el menú de opciones (mientras el menú está abierto)
var _sprite_foco: TextureRect = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	sprite_izquierda = _crear_sprite()
	sprite_derecha = _crear_sprite()

	await get_tree().process_frame
	_calcular_posiciones_iniciales()
	sprite_izquierda.position = posicion_inicial_izquierda
	sprite_derecha.position = posicion_inicial_derecha

func _calcular_posiciones_iniciales() -> void:
	var borde_superior_caja = size.y - UIEstilo.ALTO_CAJA_DIALOGO - UIEstilo.MARGEN_INFERIOR
	var y_personaje = borde_superior_caja - UIEstilo.ALTO_SPRITE + UIEstilo.SUPERPOSICION

	var x_izquierda = UIEstilo.MARGEN_LATERAL + 40.0
	var x_derecha = size.x - UIEstilo.MARGEN_LATERAL - 40.0 - UIEstilo.ANCHO_SPRITE

	posicion_inicial_izquierda = Vector2(x_izquierda, y_personaje)
	posicion_inicial_derecha = Vector2(x_derecha, y_personaje)

func _crear_sprite() -> TextureRect:
	var rect := TextureRect.new()
	rect.size = Vector2(UIEstilo.ANCHO_SPRITE, UIEstilo.ALTO_SPRITE)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.visible = false
	add_child(rect)
	return rect

func _obtener_personaje(nombre: String) -> CharacterData:
	var clave = nombre.to_lower()
	if cache_personajes.has(clave):
		return cache_personajes[clave]

	var ruta = CARPETA_PERSONAJES + clave + ".tres"
	var datos: CharacterData = null
	if ResourceLoader.exists(ruta):
		datos = load(ruta) as CharacterData
	else:
		push_warning("No se encontró el personaje: " + ruta)

	cache_personajes[clave] = datos
	return datos

func reiniciar_lados() -> void:
	personaje_izquierda = ""
	personaje_derecha = ""
	ocultar_todos()

func _lado_de(nombre_personaje: String) -> String:
	# Si ya está en escena, se queda en su lado.
	if personaje_izquierda == nombre_personaje:
		return "izquierda"
	if personaje_derecha == nombre_personaje:
		return "derecha"
	# Si es nuevo, ocupa el primer lado libre.
	if personaje_izquierda == "":
		personaje_izquierda = nombre_personaje
		return "izquierda"
	if personaje_derecha == "":
		personaje_derecha = nombre_personaje
		return "derecha"
	return "izquierda"

# Saca a un personaje de escena (su lado queda libre).
func retirar(nombre_personaje: String) -> void:
	var clave := nombre_personaje.to_lower()
	if clave == "":
		return
	if personaje_izquierda.to_lower() == clave:
		personaje_izquierda = ""
		sprite_izquierda.visible = false
	elif personaje_derecha.to_lower() == clave:
		personaje_derecha = ""
		sprite_derecha.visible = false
		
# Intercambia de lado a los dos personajes (nombres y estado visual de los sprites).
func _intercambiar_lados() -> void:
	var nombre_tmp: String = personaje_izquierda
	personaje_izquierda = personaje_derecha
	personaje_derecha = nombre_tmp

	var tex_tmp: Texture2D = sprite_izquierda.texture
	var vis_tmp: bool = sprite_izquierda.visible
	var mod_tmp: Color = sprite_izquierda.modulate
	sprite_izquierda.texture = sprite_derecha.texture
	sprite_izquierda.visible = sprite_derecha.visible
	sprite_izquierda.modulate = sprite_derecha.modulate
	sprite_derecha.texture = tex_tmp
	sprite_derecha.visible = vis_tmp
	sprite_derecha.modulate = mod_tmp
	_actualizar_orientacion()

# Fuerza a un personaje a un lado ("izquierda" o "derecha").
# Si ya estaba en escena en el otro lado, se pasa al lado pedido (y el otro, al opuesto).
# Si es nuevo y el lado está ocupado, el que estaba pasa al lado opuesto si está libre.
func _forzar_lado(nombre_personaje: String, lado: String) -> void:
	var en_izq: bool = personaje_izquierda == nombre_personaje
	var en_der: bool = personaje_derecha == nombre_personaje

	if lado == "izquierda":
		if en_izq:
			return
		if en_der:
			_intercambiar_lados()
			return
		# Es nuevo en escena
		if personaje_izquierda != "" and personaje_derecha == "":
			_intercambiar_lados()   # el que estaba se va a la derecha
		personaje_izquierda = nombre_personaje
	elif lado == "derecha":
		if en_der:
			return
		if en_izq:
			_intercambiar_lados()
			return
		if personaje_derecha != "" and personaje_izquierda == "":
			_intercambiar_lados()   # el que estaba se va a la izquierda
		personaje_derecha = nombre_personaje

# Los que van a la derecha se espejan para mirar al centro (salvo los de frente).
func _actualizar_orientacion() -> void:
	sprite_izquierda.flip_h = false
	sprite_derecha.flip_h = not DE_FRENTE.has(personaje_derecha.to_lower())

# Busca el sprite de un personaje que ya está en escena, sin asignarle lado.
func _sprite_en_escena(nombre_personaje: String) -> TextureRect:
	if nombre_personaje == "":
		return null
	var clave = nombre_personaje.to_lower()
	if clave == personaje_izquierda.to_lower():
		return sprite_izquierda
	if clave == personaje_derecha.to_lower():
		return sprite_derecha
	return null

# lado_forzado: "", "izquierda" o "derecha" (campo "lado" de la línea del JSON).
func mostrar(nombre_personaje: String, expresion: int, lado_forzado: String = "") -> void:
	if nombre_personaje == "":
		ocultar_todos()
		return

	var datos = _obtener_personaje(nombre_personaje)
	if not datos or not datos.textura:
		return

	if lado_forzado != "":
		_forzar_lado(nombre_personaje, lado_forzado)

	var es_derecha = _lado_de(nombre_personaje) == "derecha"
	var activo = sprite_derecha if es_derecha else sprite_izquierda
	var inactivo = sprite_izquierda if es_derecha else sprite_derecha
	var nombre_del_otro = personaje_izquierda if es_derecha else personaje_derecha

	var region = GrillaExpresiones.obtener_region(expresion, datos.textura.get_width(), datos.textura.get_height())

	var atlas := activo.texture as AtlasTexture
	if not atlas:
		atlas = AtlasTexture.new()
		activo.texture = atlas
	atlas.atlas = datos.textura
	atlas.region = region

	activo.visible = true
	activo.modulate = Color(1, 1, 1, 1)
	_actualizar_orientacion()

	if nombre_del_otro != "":
		inactivo.visible = true
		inactivo.modulate = Color(0.5, 0.5, 0.5, 1)
	else:
		inactivo.visible = false

func ocultar_todos() -> void:
	sprite_izquierda.visible = false
	sprite_derecha.visible = false

# Abre el "modo opciones": el personaje que pregunta sube al centro, apoyado sobre
# el borde del menú y con colores normales. El otro se desvanece y se oculta.
func entrar_modo_opciones(nombre_personaje: String, borde_y: float) -> void:
	_sprite_foco = _sprite_en_escena(nombre_personaje)

	if tween_mover and tween_mover.is_running():
		tween_mover.kill()
	tween_mover = create_tween().set_parallel(true)
	var hay_animacion := false

	for sprite in [sprite_izquierda, sprite_derecha]:
		if not sprite.visible:
			continue
		if sprite == _sprite_foco:
			var y = maxf(0.0, borde_y - UIEstilo.ALTO_SPRITE + UIEstilo.SUPERPOSICION)
			var destino = Vector2(size.x / 2 - UIEstilo.ANCHO_SPRITE / 2, y)
			tween_mover.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.4)
			tween_mover.tween_property(sprite, "position", destino, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			tween_mover.tween_property(sprite, "modulate:a", 0.0, 0.3)
			tween_mover.tween_callback(sprite.hide).set_delay(0.3)
		hay_animacion = true

	if not hay_animacion:
		tween_mover.kill()
		return
	await tween_mover.finished

# Cierra el "modo opciones": el personaje vuelve a su lugar. El otro reaparece
# recién cuando la siguiente línea del JSON lo muestre (con mostrar()).
func salir_modo_opciones() -> void:
	if _sprite_foco == null:
		return

	var destino = posicion_inicial_derecha if _sprite_foco == sprite_derecha else posicion_inicial_izquierda

	if tween_mover and tween_mover.is_running():
		tween_mover.kill()
	tween_mover = create_tween()
	tween_mover.tween_property(_sprite_foco, "position", destino, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sprite_foco = null
	await tween_mover.finished
