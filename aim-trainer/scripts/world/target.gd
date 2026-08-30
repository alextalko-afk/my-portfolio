class_name TargetUnit
extends Node3D
## Pop-style training target: any hit (body or head) instantly retires it,
## it respawns shortly after at a random point from its spawn pool. Built
## entirely from primitives -- no external art assets.

const BODY_COLOR := Color(0.82, 0.22, 0.16)
const HEAD_COLOR := Color(0.65, 0.16, 0.12)

@export var respawn_delay: float = 1.1

var alive: bool = true
var spawn_points: Array = []
var body: StaticBody3D
var head: StaticBody3D

func setup(points: Array) -> void:
	spawn_points = points
	if spawn_points.size() > 0:
		global_position = spawn_points[randi() % spawn_points.size()]
	_build_mesh(BODY_COLOR, HEAD_COLOR)

func _build_mesh(body_color: Color, head_color: Color) -> void:
	body = StaticBody3D.new()
	body.add_to_group("target_body")
	body.collision_layer = 1 << 2
	body.collision_mask = 0
	add_child(body)

	var body_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.1
	body_mesh.mesh = capsule
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0, 0.75, 0)
	body.add_child(body_mesh)

	var body_shape := CollisionShape3D.new()
	var body_capsule_shape := CapsuleShape3D.new()
	body_capsule_shape.radius = 0.28
	body_capsule_shape.height = 1.1
	body_shape.shape = body_capsule_shape
	body_shape.position = Vector3(0, 0.75, 0)
	body.add_child(body_shape)

	head = StaticBody3D.new()
	head.add_to_group("target_head")
	head.collision_layer = 1 << 2
	head.collision_mask = 0
	add_child(head)

	var head_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	head_mesh.mesh = sphere
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = head_color
	head_mesh.material_override = head_mat
	head_mesh.position = Vector3(0, 1.55, 0)
	head.add_child(head_mesh)

	var head_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.16
	head_shape.shape = sphere_shape
	head_shape.position = Vector3(0, 1.55, 0)
	head.add_child(head_shape)

func hit(zone: String, points: int) -> void:
	if not alive:
		return
	alive = false
	visible = false
	_set_collision_enabled(false)
	GameState.register_hit(zone, points)
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()

func _set_collision_enabled(enabled: bool) -> void:
	if body:
		body.set_collision_layer_value(3, enabled)
	if head:
		head.set_collision_layer_value(3, enabled)

func _respawn() -> void:
	if spawn_points.size() > 0:
		global_position = spawn_points[randi() % spawn_points.size()]
	alive = true
	visible = true
	_set_collision_enabled(true)
