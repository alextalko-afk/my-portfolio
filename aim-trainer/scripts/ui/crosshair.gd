class_name Crosshair
extends Control
## Dynamic cross that widens with the active weapon's current spread cone.

var gap: float = 6.0
var line_length: float = 6.0
var thickness: float = 2.0
var color: Color = Color(0.15, 1.0, 0.25, 0.9)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + line_length, 0), color, thickness)
	draw_line(center - Vector2(gap, 0), center - Vector2(gap + line_length, 0), color, thickness)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + line_length), color, thickness)
	draw_line(center - Vector2(0, gap), center - Vector2(0, gap + line_length), color, thickness)
