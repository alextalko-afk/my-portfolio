class_name PlayerController
extends CharacterBody3D
## Source/Quake-style FPS controller: ground accelerate+friction, air-strafe
## with a capped wish-speed (classic bunny-hop trick), mouse look, crouch/walk.

const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 1.05
const PITCH_LIMIT := 1.5

const WeaponScript := preload("res://scripts/player/weapon.gd")
const WeaponPresets := preload("res://scripts/weapon_presets.gd")
const WEAPON_SLOT_ACTIONS := ["weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5"]
const RESPAWN_DELAY := 2.5

@export var walk_speed: float = 6.0
@export var crouch_speed: float = 3.0
@export var slow_walk_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 12.0
@export var ground_accel: float = 14.0
@export var air_accel: float = 2.0
@export var air_speed_cap: float = 1.5
@export var ground_friction: float = 6.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_holder: Node3D = $Head/WeaponHolder

var pitch: float = 0.0
var mouse_captured := false
var weapons: Array = []
var active_weapon_index: int = 0
var is_dead := false
var _spawn_position: Vector3
var _spawn_rotation_y: float
var _audio_hurt: AudioStreamPlayer

func _ready() -> void:
	head.position.y = STAND_HEIGHT
	_capture_mouse()
	_setup_weapons()
	_spawn_position = global_position
	_spawn_rotation_y = rotation.y
	_audio_hurt = AudioStreamPlayer.new()
	_audio_hurt.stream = load("res://audio/player_hurt.wav")
	add_child(_audio_hurt)
	GameState.player_died.connect(_on_player_died)
	GameState.player_respawned.connect(_on_player_respawned)
	GameState.player_damaged.connect(_on_player_damaged)

func _on_player_damaged(_amount: int, _health: int) -> void:
	_audio_hurt.stop()
	_audio_hurt.play()

func _on_player_died() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	GameState.respawn()

func _on_player_respawned() -> void:
	is_dead = false
	global_position = _spawn_position
	rotation.y = _spawn_rotation_y
	pitch = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO

func _setup_weapons() -> void:
	_add_weapon(WeaponPresets.make_rifle())
	_add_weapon(WeaponPresets.make_pistol())
	_add_weapon(WeaponPresets.make_smg())
	_add_weapon(WeaponPresets.make_sniper())
	_add_weapon(WeaponPresets.make_knife())

	active_weapon_index = 0
	for i in range(weapons.size()):
		weapons[i].set_active(i == active_weapon_index)

func _add_weapon(stats) -> void:
	var w := WeaponScript.new()
	weapon_holder.add_child(w)
	w.setup(stats, self, camera)
	weapons.append(w)

func get_active_weapon() -> Node:
	if weapons.is_empty():
		return null
	return weapons[active_weapon_index]

func _switch_weapon(index: int) -> void:
	if index == active_weapon_index or index < 0 or index >= weapons.size():
		return
	weapons[active_weapon_index].set_active(false)
	active_weapon_index = index
	weapons[active_weapon_index].set_active(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * Settings.mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * Settings.mouse_sensitivity, -PITCH_LIMIT, PITCH_LIMIT)
		head.rotation.x = pitch
	elif event.is_action_pressed("ui_cancel"):
		_release_mouse()
	elif event is InputEventMouseButton and event.pressed and not mouse_captured:
		_capture_mouse()

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

func apply_recoil(offset: Vector2) -> void:
	pitch = clamp(pitch - deg_to_rad(offset.x), -PITCH_LIMIT, PITCH_LIMIT)
	head.rotation.x = pitch
	rotate_y(-deg_to_rad(offset.y))

func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func is_crouching() -> bool:
	return Input.is_action_pressed("crouch")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	for i in range(WEAPON_SLOT_ACTIONS.size()):
		if Input.is_action_just_pressed(WEAPON_SLOT_ACTIONS[i]):
			_switch_weapon(i)
			break

	if not is_on_floor():
		velocity.y -= gravity * delta

	var crouching := Input.is_action_pressed("crouch")
	var walking_slow := Input.is_action_pressed("walk_slow")

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif walking_slow:
		speed = slow_walk_speed

	var target_head_height := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	head.position.y = lerp(head.position.y, target_head_height, clamp(delta * 12.0, 0.0, 1.0))

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	wish_dir.y = 0.0
	wish_dir = wish_dir.normalized() if wish_dir.length() > 0.001 else Vector3.ZERO

	if is_on_floor():
		_apply_friction(delta)
		_accelerate(wish_dir, speed, ground_accel, delta)
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		_accelerate(wish_dir, min(speed, air_speed_cap), air_accel, delta)

	move_and_slide()

func _apply_friction(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var drop := speed * ground_friction * delta
	var new_speed: float = max(speed - drop, 0.0)
	var scale := new_speed / speed
	velocity.x *= scale
	velocity.z *= scale

func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir.length() < 0.001:
		return
	var current_speed := Vector3(velocity.x, 0.0, velocity.z).dot(wish_dir)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed: float = min(accel * wish_speed * delta, add_speed)
	velocity.x += accel_speed * wish_dir.x
	velocity.z += accel_speed * wish_dir.z
