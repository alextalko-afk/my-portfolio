extends Node3D
## Builds the whole shooting range procedurally: room geometry, lighting,
## cover props, target spawn points, and instances the player + HUD.
## Everything here is primitives/code -- no external art assets.

const ARENA_WIDTH := 24.0
const ARENA_DEPTH := 16.0
const ARENA_HEIGHT := 6.0
const WALL_THICKNESS := 0.5

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")
const TargetScript := preload("res://scripts/world/target.gd")
const TargetMovingScript := preload("res://scripts/world/target_moving.gd")

func _ready() -> void:
	_build_lighting()
	_build_room()
	_build_props()
	_spawn_targets(_static_spawn_points())
	_spawn_moving_targets(_patrol_paths())
	var player := _spawn_player()
	_spawn_hud(player)

func _build_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.33, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _build_room() -> void:
	_add_box(Vector3(ARENA_WIDTH, WALL_THICKNESS, ARENA_DEPTH), Vector3(0, -WALL_THICKNESS / 2.0, 0), Color(0.16, 0.17, 0.19))
	_add_box(Vector3(ARENA_WIDTH, ARENA_HEIGHT, WALL_THICKNESS), Vector3(0, ARENA_HEIGHT / 2.0, -ARENA_DEPTH / 2.0), Color(0.34, 0.36, 0.40))
	_add_box(Vector3(ARENA_WIDTH, ARENA_HEIGHT, WALL_THICKNESS), Vector3(0, ARENA_HEIGHT / 2.0, ARENA_DEPTH / 2.0), Color(0.34, 0.36, 0.40))
	_add_box(Vector3(WALL_THICKNESS, ARENA_HEIGHT, ARENA_DEPTH), Vector3(-ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0, 0), Color(0.30, 0.32, 0.36))
	_add_box(Vector3(WALL_THICKNESS, ARENA_HEIGHT, ARENA_DEPTH), Vector3(ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0, 0), Color(0.30, 0.32, 0.36))

func _build_props() -> void:
	_add_box(Vector3(1.2, 1.0, 1.2), Vector3(-4.5, 0.5, -1.0), Color(0.22, 0.24, 0.27))
	_add_box(Vector3(1.2, 1.6, 1.2), Vector3(3.0, 0.8, -3.5), Color(0.22, 0.24, 0.27))
	_add_box(Vector3(1.0, 0.6, 1.0), Vector3(6.5, 0.3, 1.5), Color(0.22, 0.24, 0.27))

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

func _static_spawn_points() -> Array:
	var points := []
	for col in range(5):
		var x: float = -8.0 + col * 4.0
		points.append(Vector3(x, 1.0, -7.0))
		points.append(Vector3(x, 1.8, -6.2))
	return points

func _patrol_paths() -> Array:
	return [
		[Vector3(-9.0, 1.1, -4.0), Vector3(9.0, 1.1, -4.0)],
		[Vector3(-6.0, 1.4, -2.2), Vector3(6.0, 1.4, -2.2)],
	]

func _spawn_targets(points: Array) -> void:
	var count: int = min(7, points.size())
	for i in range(count):
		var t := TargetScript.new()
		add_child(t)
		t.setup(points)

func _spawn_moving_targets(paths: Array) -> void:
	for path in paths:
		var t := TargetMovingScript.new()
		add_child(t)
		t.setup_patrol(path[0], path[1], 1.8)

func _spawn_player() -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.05, 6.5)
	add_child(player)
	return player

func _spawn_hud(player: Node) -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(player)
