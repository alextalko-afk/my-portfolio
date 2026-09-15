class_name VoxelPlayer
extends CharacterBody3D
## Simple FPS controller: WASD movement, mouse look, jump, sprint.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 6.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.0025
@export var world_path: NodePath

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var pitch: float = 0.0
var mouse_captured: bool = false

var _world: Node
## Chunk meshing/collision finishes asynchronously after the world starts
## up, so gravity stays off until the spawn chunk actually has a collider —
## otherwise the player free-falls through the not-yet-built ground.
var _spawn_ready: bool = false

func _ready() -> void:
	add_to_group("player")
	_capture_mouse()
	if world_path != NodePath():
		_world = get_node(world_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		var motion: InputEventMouseMotion = event
		rotate_y(-motion.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - motion.relative.y * mouse_sensitivity, -1.55, 1.55)
		head.rotation.x = pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_release_mouse()
	elif event is InputEventMouseButton and event.pressed and not mouse_captured:
		_capture_mouse()

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

func _physics_process(delta: float) -> void:
	if not _spawn_ready:
		if _world != null and _world.is_position_ready(global_position):
			_spawn_ready = true
		else:
			return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction.length() > 0.01:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
