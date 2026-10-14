class_name UIEstilo
extends RefCounted
## Medidas compartidas por la caja de diálogo, el menú de opciones y los personajes.
## Si querés cambiar el aspecto general, cambiá los números acá y se actualiza todo.

# --- Letra ---
const FUENTE_NOMBRE := 46  # nombre del personaje y pregunta del menú
const FUENTE_TEXTO := 40    # texto del diálogo y botones de opciones

# --- Colores ---
const COLOR_FONDO_CAJA := Color(0.05, 0.05, 0.08, 0.92)
const COLOR_NOMBRE := Color(1, 0.85, 0.4)

# --- Cajas ---
const MARGEN_LATERAL := 260.0            # caja de diálogo
const MARGEN_LATERAL_OPCIONES := 260.0   # menú de opciones (más alto = más angosto)
const MARGEN_INFERIOR := 40.0
const PADDING_INTERNO := 30.0
const ALTO_CAJA_DIALOGO := 260.0

# --- Botones de opciones ---
const ALTO_BOTON := 64.0
const SEPARACION := 16

# --- Personajes ---
const ANCHO_SPRITE := 400.0
const ALTO_SPRITE := 400.0
const SUPERPOSICION := 15.0   # cuánto se mete el personaje detrás de la caja para quedar apoyado
