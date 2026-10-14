class_name MinijuegoBase
extends Control
## Base de todos los minijuegos y paneles del laboratorio.
## Uso desde otra escena:
##   var mj := MJComposicion.new()
##   mj.configurar(datos)          # un Dictionary leído del JSON (con "estacion" para elegir el color)
##   mj.terminado.connect(...)     # recibe un Dictionary con el resultado
##   mj.cancelado.connect(...)     # el jugador apretó "Volver" (no se gasta muestra)
##   add_child(mj)
##
## Cada estación tiene su propia paleta (ver PALETAS) y su propio marco (ver MARCOS).

signal terminado(resultado: Dictionary)
signal cancelado

# --- Paletas por estación: cambiá los colores a gusto ---
const PALETAS := {
	# cian: la identidad de CRONOS (holograma)
	"reconstruccion": {"acento": Color(0.30, 0.85, 0.95), "lineas": false},
	# verde fósforo: el terminal
	"composicion": {"acento": Color(0.42, 0.95, 0.50), "lineas": true},
	# ámbar: el microscopio
	"microscopio": {"acento": Color(1.00, 0.70, 0.26), "lineas": false},
	# por defecto (ficha de evidencia, etc.)
	"": {"acento": Color(0.30, 0.85, 0.95), "lineas": false},
}
# ---------------------------------------------------------

# --- Marco de cada estación (imagen de fondo). Poné la extensión real de tus archivos ---
const MARCOS := {
	"reconstruccion": "res://assets/backgrounds/estaciones/Reconstruccion.png",
	"composicion": "res://assets/backgrounds/estaciones/Composicion.png",
	"microscopio": "res://assets/backgrounds/estaciones/Microscopio.png",
	"": "res://assets/backgrounds/estaciones/Reconstruccion.png",
}
## Zonas del marco, como fracción de la pantalla: Rect2(x, y, ancho, alto).
## Se midieron sobre el arte (las tres imágenes tienen las zonas en el mismo lugar).
## Si cambiás el arte, cambiá solo estos números.
const AREA_JUEGO := Rect2(0.1940, 0.0925, 0.6119, 0.8190)    # el cuadrado grande del medio
const AREA_VOLVER := Rect2(0.8241, 0.0925, 0.1475, 0.1406)   # recuadro de arriba a la derecha
const AREA_ESTADO := Rect2(0.8241, 0.5651, 0.1475, 0.3464)   # recuadro de abajo a la derecha
## Aire entre el borde de cada zona y lo que se pone adentro (píxeles de pantalla).
const AIRE_MARCO := 8.0

const COLOR_PANEL := Color(0.030, 0.060, 0.100, 1.0)
const COLOR_PANEL_OSCURO := Color(0.020, 0.040, 0.070, 1.0)
const COLOR_TEXTO := Color(0.88, 0.95, 1.00, 1.0)
const COLOR_OK := Color(0.45, 0.90, 0.55, 1.0)
const COLOR_ERROR := Color(1.00, 0.45, 0.40, 1.0)
const COLOR_APAGADO := Color(0.50, 0.63, 0.74, 1.0)

# Colores que dependen de la estación (se fijan en aplicar_paleta)
static var COLOR_ACENTO: Color = Color(0.30, 0.85, 0.95, 1.0)
static var COLOR_TITULO: Color = Color(0.62, 0.93, 1.00, 1.0)
static var COLOR_BORDE: Color = Color(0.13, 0.42, 0.52, 1.0)

var datos: Dictionary = {}
## Los paneles de ficha no necesitan el botón "Volver" si no querés.
var mostrar_volver: bool = true
var _lineas_terminal: bool = false
var _con_marco: bool = false   # true si se cargó la imagen del marco
var _vbox_estado: VBoxContainer   # contenido del recuadro de abajo a la derecha


func configurar(d: Dictionary) -> void:
	datos = d


static func aplicar_paleta(estacion: String) -> void:
	var p: Dictionary = PALETAS.get(estacion, PALETAS[""])
	var a: Color = p["acento"]
	COLOR_ACENTO = a
	COLOR_TITULO = a.lerp(Color.WHITE, 0.45)
	COLOR_BORDE = Color(a.r * 0.45, a.g * 0.45, a.b * 0.45, 1.0)


func _ready() -> void:
	var estacion: String = str(datos.get("estacion", ""))
	aplicar_paleta(estacion)
	_lineas_terminal = bool(PALETAS.get(estacion, PALETAS[""]).get("lineas", false))

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var tex_marco: Texture2D = cargar_textura(str(MARCOS.get(estacion, MARCOS[""])))
	if tex_marco != null:
		_con_marco = true
		var imagen := TextureRect.new()
		imagen.texture = tex_marco
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_SCALE
		imagen.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(imagen)
		imagen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		var fondo := FondoHUD.new()
		add_child(fondo)
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_construir()

	if mostrar_volver:
		var volver: Button
		if _con_marco:
			volver = crear_boton_volver()
			add_child(volver)
			var r: Rect2 = _rect_px(AREA_VOLVER).grow(-AIRE_MARCO)
			volver.position = r.position
			volver.size = r.size
		else:
			volver = crear_boton("Volver", 200)
			add_child(volver)
			volver.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			volver.offset_left = -230.0
			volver.offset_right = -30.0
			volver.offset_top = 14.0
			volver.offset_bottom = 14.0 + UIEstilo.ALTO_BOTON
		volver.pressed.connect(func(): cancelado.emit())


## Pasa una zona (fracción de la pantalla) a píxeles de pantalla.
func _rect_px(zona: Rect2) -> Rect2:
	var pantalla: Vector2 = get_viewport_rect().size
	return Rect2(zona.position * pantalla, zona.size * pantalla)


## Pone un control (etiqueta o botón) en el recuadro de abajo a la derecha del marco.
## Sin marco de imagen, lo agrega a `alternativo`: el lugar donde estaba antes.
func poner_en_estado(c: Control, alternativo: Node) -> void:
	if not _con_marco:
		alternativo.add_child(c)
		return
	if c is Button:
		c.custom_minimum_size.x = 0.0
		c.size_flags_horizontal = Control.SIZE_FILL
		c.add_theme_font_size_override("font_size", t_texto() - 6)
	elif c is Label:
		c.add_theme_font_size_override("font_size", t_texto() - 6)
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _vbox_estado == null:
		var r: Rect2 = _rect_px(AREA_ESTADO).grow(-AIRE_MARCO)
		_vbox_estado = VBoxContainer.new()
		_vbox_estado.add_theme_constant_override("separation", 12)
		_vbox_estado.position = r.position
		_vbox_estado.size = r.size
		add_child(_vbox_estado)
	_vbox_estado.add_child(c)


## Cada minijuego lo reemplaza para armar su interfaz.
func _construir() -> void:
	pass


# ---------------------------------------------------------------
# DECORADOS (clases internas)
# ---------------------------------------------------------------

## Fondo de pantalla (solo si falta la imagen del marco): azul oscuro con cuadrícula y círculos.
class FondoHUD extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var a: Color = MinijuegoBase.COLOR_ACENTO
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.025, 0.045, 0.94), true)
		var paso: float = 80.0
		var x: float = 0.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(a, 0.035), 1.0)
			x += paso
		var y: float = 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(a, 0.035), 1.0)
			y += paso
		var c: Vector2 = size * 0.5
		for radio in [300.0, 520.0, 760.0]:
			draw_arc(c, radio, 0.0, TAU, 128, Color(a, 0.07), 2.0)


## Marco del panel (solo si falta la imagen): borde con resplandor, corchetes y pestañas.
class Marco extends PanelContainer:
	var liso: bool = false   # con el marco de imagen no hace falta dibujar adornos

	func _draw() -> void:
		if liso:
			return
		var a: Color = MinijuegoBase.COLOR_ACENTO
		var r := Rect2(Vector2.ZERO, size)
		# borde interior fino
		draw_rect(r.grow(-9.0), Color(a, 0.16), false, 1.0)
		# corchetes en las cuatro esquinas
		var largo: float = 38.0
		var grosor: float = 4.0
		var m: float = 2.0
		var col: Color = Color(a, 1.0)
		draw_line(Vector2(m, m), Vector2(m + largo, m), col, grosor)
		draw_line(Vector2(m, m), Vector2(m, m + largo), col, grosor)
		draw_line(Vector2(size.x - m, m), Vector2(size.x - m - largo, m), col, grosor)
		draw_line(Vector2(size.x - m, m), Vector2(size.x - m, m + largo), col, grosor)
		draw_line(Vector2(m, size.y - m), Vector2(m + largo, size.y - m), col, grosor)
		draw_line(Vector2(m, size.y - m), Vector2(m, size.y - m - largo), col, grosor)
		draw_line(Vector2(size.x - m, size.y - m), Vector2(size.x - m - largo, size.y - m), col, grosor)
		draw_line(Vector2(size.x - m, size.y - m), Vector2(size.x - m, size.y - m - largo), col, grosor)
		# pestañas brillantes arriba y abajo al centro
		draw_rect(Rect2(size.x * 0.5 - 70.0, -3.0, 140.0, 7.0), Color(a, 0.95), true)
		draw_rect(Rect2(size.x * 0.5 - 70.0, size.y - 4.0, 140.0, 7.0), Color(a, 0.95), true)
		# tres cuadritos arriba a la derecha
		for i in range(3):
			draw_rect(Rect2(size.x - 80.0 + i * 16.0, 16.0, 8.0, 8.0), Color(a, 0.35 + 0.25 * i), true)


## Líneas horizontales finas encima del panel (efecto de pantalla de terminal).
class Lineas extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y: float = 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.18), 1.0)
			y += 4.0


# ---------------------------------------------------------------
# AYUDAS DE INTERFAZ (static: se pueden usar también desde el laboratorio)
# ---------------------------------------------------------------

static func t_texto() -> int:
	return int(UIEstilo.FUENTE_TEXTO * 0.7)


static func t_titulo() -> int:
	return UIEstilo.FUENTE_NOMBRE


static func crear_estilo(fondo: Color, borde: Color = COLOR_BORDE, radio: int = 8, margen: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(2)
	s.set_corner_radius_all(radio)
	s.set_content_margin_all(margen)
	return s


## Panel con resplandor (lo usa también el laboratorio para su cuadro de muestras).
static func crear_panel(tam: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = tam
	var s := crear_estilo(COLOR_PANEL, COLOR_ACENTO, 2, 16)
	s.shadow_color = Color(COLOR_ACENTO, 0.28)
	s.shadow_size = 14
	p.add_theme_stylebox_override("panel", s)
	return p


static func crear_label(texto: String, tam: int = 0, color: Color = COLOR_TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam if tam > 0 else t_texto())
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Encabezado de un panel: el título en mayúsculas, una línea que se estira y una etiqueta chica.
static func crear_titulo(texto: String) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	var t := crear_label(texto.to_upper(), t_titulo(), COLOR_TITULO)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fila.add_child(t)
	var linea := ColorRect.new()
	linea.color = Color(COLOR_ACENTO, 0.55)
	linea.custom_minimum_size = Vector2(0, 3)
	linea.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linea.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(linea)
	var etq := crear_label("CRONOS // ANÁLISIS", t_texto() - 6, Color(COLOR_ACENTO, 0.55))
	etq.autowrap_mode = TextServer.AUTOWRAP_OFF
	etq.size_flags_horizontal = Control.SIZE_SHRINK_END
	fila.add_child(etq)
	return fila


static func crear_boton(texto: String, ancho: int = 260, tam_fuente: int = 0) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, UIEstilo.ALTO_BOTON)
	b.add_theme_font_size_override("font_size", tam_fuente if tam_fuente > 0 else t_texto())
	b.add_theme_color_override("font_color", COLOR_TITULO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.30, 0.38, 0.45))
	var normal := crear_estilo(Color(0.04, 0.09, 0.14), Color(COLOR_ACENTO, 0.65), 2, 10)
	var hover := crear_estilo(Color(COLOR_ACENTO, 0.16), COLOR_ACENTO, 2, 10)
	hover.shadow_color = Color(COLOR_ACENTO, 0.35)
	hover.shadow_size = 8
	var pulsado := crear_estilo(Color(COLOR_ACENTO, 0.32), COLOR_ACENTO, 2, 10)
	var inactivo := crear_estilo(Color(0.03, 0.05, 0.08), Color(0.16, 0.22, 0.28), 2, 10)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pulsado)
	b.add_theme_stylebox_override("hover_pressed", pulsado)
	b.add_theme_stylebox_override("disabled", inactivo)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## Botón "Volver" transparente: solo se ve el texto, y se ilumina al pasar el mouse.
static func crear_boton_volver() -> Button:
	var b := Button.new()
	b.text = "VOLVER"
	b.add_theme_font_size_override("font_size", t_titulo())
	b.add_theme_color_override("font_color", Color(COLOR_TITULO, 0.75))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := crear_estilo(Color(COLOR_ACENTO, 0.0), Color(COLOR_ACENTO, 0.0), 4, 8)
	var hover := crear_estilo(Color(COLOR_ACENTO, 0.16), COLOR_ACENTO, 4, 8)
	hover.shadow_color = Color(COLOR_ACENTO, 0.35)
	hover.shadow_size = 10
	var pulsado := crear_estilo(Color(COLOR_ACENTO, 0.32), COLOR_ACENTO, 4, 8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pulsado)
	b.add_theme_stylebox_override("hover_pressed", pulsado)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func cargar_textura(ruta: String) -> Texture2D:
	if ruta != "" and ResourceLoader.exists(ruta):
		var recurso = load(ruta)
		if recurso is Texture2D:
			return recurso
	return null


## Imagen de relleno para poder probar el minijuego antes de tener el arte.
static func textura_provisoria(w: int, h: int) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.27, 0.35, 1.0))
	for y in range(0, h, 40):
		for x in range(0, w, 40):
			if (floori(x / 40.0) + floori(y / 40.0)) % 2 == 0:
				img.fill_rect(Rect2i(x, y, 40, 40), Color(0.34, 0.36, 0.46, 1.0))
	return ImageTexture.create_from_image(img)


## Panel con un VBox adentro. Devuelve el VBox para ir agregando cosas.
## Con marco de imagen: el panel se achica (si hace falta) para entrar en el cuadrado del juego.
## Sin imagen: queda centrado y a tamaño completo, como antes.
func crear_marco_central(tam: Vector2, estirar_alto: bool = false) -> VBoxContainer:
	var panel := Marco.new()
	panel.liso = _con_marco
	panel.custom_minimum_size = tam
	var s: StyleBoxFlat
	if _con_marco:
		s = crear_estilo(Color(0.02, 0.04, 0.07, 0.35), Color(COLOR_ACENTO, 0.0), 0, 22)
		s.set_border_width_all(0)
	else:
		s = crear_estilo(COLOR_PANEL, COLOR_ACENTO, 2, 22)
		s.shadow_color = Color(COLOR_ACENTO, 0.30)
		s.shadow_size = 18
	panel.add_theme_stylebox_override("panel", s)

	if _con_marco:
		var area: Rect2 = _rect_px(AREA_JUEGO).grow(-AIRE_MARCO)
		var f: float = minf(1.0, minf(area.size.x / tam.x, area.size.y / tam.y))
		if estirar_alto:
			# El panel se estira hacia abajo hasta llenar el cuadrado del juego.
			f = minf(1.0, area.size.x / tam.x)
			tam.y = maxf(tam.y, area.size.y / f)
			panel.custom_minimum_size = tam
		add_child(panel)
		panel.size = tam
		panel.scale = Vector2(f, f)
		panel.position = area.get_center() - tam * f * 0.5
	else:
		var centro := CenterContainer.new()
		centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(centro)
		centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	if _lineas_terminal:
		panel.add_child(Lineas.new())
	return caja
