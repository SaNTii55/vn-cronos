extends Node

@export var columnas: int = 4
@export var filas: int = 4

func obtener_region(indice: int, ancho_textura: int, alto_textura: int) -> Rect2:
	var ancho_celda = ancho_textura / float(columnas)
	var alto_celda = alto_textura / float(filas)

	var fila = indice / columnas
	var columna = indice % columnas

	var x = round(columna * ancho_celda)
	var y = round(fila * alto_celda)
	var ancho = round((columna + 1) * ancho_celda) - x
	var alto = round((fila + 1) * alto_celda) - y

	return Rect2(x, y, ancho, alto)
