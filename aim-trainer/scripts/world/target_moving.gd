class_name TargetMoving
extends "res://scripts/world/target.gd"
## Patrol variant: walks back and forth between two points while alive.
## Colored blue so it reads as a distinct "moving" target at a glance.

const BODY_COLOR_MOVING := Color(0.18, 0.45, 0.85)
const HEAD_COLOR_MOVING := Color(0.12, 0.32, 0.65)

var patrol_a: Vector3
var patrol_b: Vector3
var patrol_speed: float = 1.6
var _dir_to_b: bool = true

func setup_patrol(a: Vector3, b: Vector3, speed: float) -> void:
	patrol_a = a
	patrol_b = b
	patrol_speed = speed
	spawn_points = [a]
	global_position = a
	_build_mesh(BODY_COLOR_MOVING, HEAD_COLOR_MOVING)

func _process(delta: float) -> void:
	if not alive:
		return
	var target_point: Vector3 = patrol_b if _dir_to_b else patrol_a
	var to_target: Vector3 = target_point - global_position
	var dist: float = to_target.length()
	if dist < 0.05:
		_dir_to_b = not _dir_to_b
		return
	global_position += to_target.normalized() * patrol_speed * delta

func _respawn() -> void:
	_dir_to_b = true
	super._respawn()
