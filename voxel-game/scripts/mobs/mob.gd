class_name Mob
extends CharacterBody3D
## Base hostile mob: chases whatever target enters its sight radius by
## walking the straight-line vector toward it (no pathfinding — pathfinding
## around a streamed, player-editable voxel world would mean rebaking a
## NavigationRegion3D on every block edit, which is a lot of machinery for
## a single melee chaser) and attacks in melee range.

@export var max_health: float = 20.0
@export var move_speed: float = 3.0
@export var sight_radius: float = 14.0
@export var attack_range: float = 1.4
@export var attack_damage: float = 2.0
@export var attack_cooldown: float = 1.0
@export var gravity: float = 20.0

var health: float
var _target: Node3D
var _attack_cooldown_left: float = 0.0

func _ready() -> void:
	add_to_group("mob")
	health = max_health

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
	elif distance > attack_range:
		var direction: Vector3 = to_target.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _attack_cooldown_left <= 0.0 and _target.has_method("take_damage"):
			_target.take_damage(attack_damage)
			_attack_cooldown_left = attack_cooldown

	move_and_slide()

func set_target(target: Node3D) -> void:
	_target = target

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		queue_free()

## Builds the mob's body from primitive meshes (capsule + box head) tinted
## a zombie green — no external model needed.
static func build_visuals(root: CharacterBody3D) -> void:
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
