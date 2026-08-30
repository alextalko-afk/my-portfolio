extends Node3D
## Builds the whole shooting range procedurally: room geometry, lighting,
## cover props, enemy squads (Terrorist + Spec Ops), and instances the
## player + HUD. Everything here is primitives/code -- no external assets.

const ARENA_WIDTH := 24.0
const ARENA_DEPTH := 16.0
const ARENA_HEIGHT := 6.0
const WALL_THICKNESS := 0.5

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")
const EnemyScript := preload("res://scripts/world/enemy.gd")

func _ready() -> void:
	_build_lighting()
	_build_room()
	_build_props()
	var player := _spawn_player()
	_spawn_enemies(player)
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
	_add_box(Vector3(1.4, 1.1, 1.4), Vector3(-3.0, 0.55, 2.0), Color(0.22, 0.24, 0.27))
	_add_box(Vector3(1.4, 1.1, 1.4), Vector3(3.0, 0.55, 2.0), Color(0.22, 0.24, 0.27))
	_add_box(Vector3(1.6, 1.3, 1.6), Vector3(-5.0, 0.65, -1.0), Color(0.22, 0.24, 0.27))
	_add_box(Vector3(1.6, 1.3, 1.6), Vector3(5.0, 0.65, -1.0), Color(0.22, 0.24, 0.27))
	_add_box(Vector3(1.2, 0.9, 1.2), Vector3(0.0, 0.45, -5.0), Color(0.22, 0.24, 0.27))

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

func _terrorist_guard_points() -> Array:
	return [Vector3(-9.0, 0.0, -7.2), Vector3(-8.0, 0.0, -6.4), Vector3(-7.0, 0.0, -7.6)]

func _terrorist_patrol_path() -> Array:
	return [Vector3(-9.5, 0.0, -3.5), Vector3(-2.0, 0.0, -3.5)]

func _specops_guard_points() -> Array:
	return [Vector3(9.0, 0.0, -7.2), Vector3(8.0, 0.0, -6.4), Vector3(7.0, 0.0, -7.6)]

func _specops_patrol_path() -> Array:
	return [Vector3(2.0, 0.0, -3.5), Vector3(9.5, 0.0, -3.5)]

func _spawn_enemies(player: Node) -> void:
	for i in range(3):
		_spawn_enemy(EnemyScript.Faction.TERRORIST, _terrorist_guard_points(), [], player)
	_spawn_enemy(EnemyScript.Faction.TERRORIST, _terrorist_patrol_path(), _terrorist_patrol_path(), player)
	_spawn_enemy(EnemyScript.Faction.TERRORIST, _terrorist_patrol_path(), _terrorist_patrol_path(), player)

	for i in range(3):
		_spawn_enemy(EnemyScript.Faction.SPEC_OPS, _specops_guard_points(), [], player)
	_spawn_enemy(EnemyScript.Faction.SPEC_OPS, _specops_patrol_path(), _specops_patrol_path(), player)
	_spawn_enemy(EnemyScript.Faction.SPEC_OPS, _specops_patrol_path(), _specops_patrol_path(), player)

func _spawn_enemy(faction: int, spawn_points: Array, patrol_points: Array, player: Node) -> void:
	var e := EnemyScript.new()
	add_child(e)
	e.setup(faction, spawn_points, patrol_points, player)

func _spawn_player() -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.05, 6.5)
	add_child(player)
	return player

func _spawn_hud(player: Node) -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(player)
