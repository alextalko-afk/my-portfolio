class_name HitMarker
extends Control
## Classic four-corner hit confirmation X, brighter/gold on a headshot.

const FLASH_TIME := 0.18

var _timer: float = 0.0
var _is_head: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func flash(is_head: bool) -> void:
	_is_head = is_head
	_timer = FLASH_TIME
	queue_redraw()

func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer = max(_timer - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	if _timer <= 0.0:
		return
	var center := size / 2.0
	var alpha: float = clamp(_timer / FLASH_TIME, 0.0, 1.0)
	var col: Color = Color(1.0, 0.85, 0.2, alpha) if _is_head else Color(1.0, 1.0, 1.0, alpha)
	var r := 11.0
	var inner := r * 0.35
	draw_line(center + Vector2(-r, -r), center + Vector2(-inner, -inner), col, 3.0)
	draw_line(center + Vector2(r, -r), center + Vector2(inner, -inner), col, 3.0)
	draw_line(center + Vector2(-r, r), center + Vector2(-inner, inner), col, 3.0)
	draw_line(center + Vector2(r, r), center + Vector2(inner, inner), col, 3.0)
