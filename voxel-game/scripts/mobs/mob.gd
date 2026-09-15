class_name Mob
extends CharacterBody3D
## Base hostile mob: chases whatever target enters its sight radius by
## re-planning a path over the voxel grid every REPATH_INTERVAL seconds
## (VoxelPathfinder — see that file for why a block-grid A* replaced an
## earlier NavigationRegion3D/Recast attempt) and walking its waypoints,
## hopping up 1-block steps as needed. Attacks in melee range.

@export var max_health: float = 20.0
@export var move_speed: float = 3.0
@export var sight_radius: float = 14.0
@export var attack_range: float = 1.4
@export var attack_damage: float = 2.0
@export var attack_cooldown: float = 1.0
@export var gravity: float = 20.0
@export var jump_velocity: float = 6.0
@export var repath_interval: float = 0.5
@export var waypoint_arrival_distance: float = 0.6

var health: float
var _target: Node3D
var _attack_cooldown_left: float = 0.0
var _attack_audio: AudioStreamPlayer3D

var _world: VoxelWorld
var _current_path: Array = []
var _path_index: int = 0
var _repath_timer: float = 0.0

func _ready() -> void:
	add_to_group("mob")
	health = max_health
	_attack_audio = AudioStreamPlayer3D.new()
	_attack_audio.stream = SoundLibrary.mob_attack
	add_child(_attack_audio)
	# Mobs are always spawned as a direct child of the World node (see
	# MobSpawner) — reuse that instead of needing a separate wiring step.
	_world = get_parent() as VoxelWorld

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)

	if _target == null or not is_instance_valid(_target):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()

	if distance > sight_radius:
		velocity.x = 0.0
		velocity.z = 0.0
		_current_path.clear()
	elif distance > attack_range:
		_repath_timer -= delta
		if _repath_timer <= 0.0 and _world != null:
			_current_path = VoxelPathfinder.find_path(_world, global_position, _target.global_position)
			_path_index = 0
			_repath_timer = repath_interval

		if _current_path.is_empty():
			_move_toward(to_target.normalized(), delta)
		else:
			_follow_path(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _attack_cooldown_left <= 0.0 and _target.has_method("take_damage"):
			_target.take_damage(attack_damage)
			_attack_cooldown_left = attack_cooldown
			_attack_audio.play()

	move_and_slide()

func _follow_path(delta: float) -> void:
	if _path_index >= _current_path.size():
		_current_path.clear()
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var waypoint: Vector3 = _current_path[_path_index]
	var to_waypoint: Vector3 = waypoint - global_position
	var horizontal := Vector3(to_waypoint.x, 0.0, to_waypoint.z)

	if horizontal.length() < waypoint_arrival_distance:
		_path_index += 1
		if _path_index >= _current_path.size():
			velocity.x = 0.0
			velocity.z = 0.0
			return
		waypoint = _current_path[_path_index]
		to_waypoint = waypoint - global_position
		horizontal = Vector3(to_waypoint.x, 0.0, to_waypoint.z)

	_move_toward(horizontal.normalized() if horizontal.length() > 0.01 else Vector3.ZERO, delta)

	# The pathfinder's neighbor search allows stepping up exactly one
	# block; CharacterBody3D has no built-in step-up, so hop when the
	# next waypoint is a block higher and we're close enough horizontally
	# to actually be walking into that step.
	if waypoint.y > global_position.y + 0.6 and is_on_floor() and horizontal.length() < 1.2:
		velocity.y = jump_velocity

func _move_toward(direction: Vector3, _delta: float) -> void:
	if direction.length() > 0.01:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func set_target(target: Node3D) -> void:
	_target = target

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		queue_free()

## Builds the mob's body from primitive meshes (capsule + box head) tinted
## a zombie green — no external model needed.
static func build_visuals(root: Mob) -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	body.mesh = capsule
	body.position = Vector3(0, 0.9, 0)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.25, 0.55, 0.2)
	body.material_override = body_material
	root.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	head.mesh = box
	head.position = Vector3(0, 1.75, 0)
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(0.18, 0.42, 0.15)
	head.material_override = head_material
	root.add_child(head)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.35
	capsule_shape.height = 1.6
	collision_shape.shape = capsule_shape
	collision_shape.position = Vector3(0, 0.9, 0)
	root.add_child(collision_shape)
