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
const ProcGfx := preload("res://scripts/world/proc_gfx.gd")

func _ready() -> void:
	_build_lighting()
	_build_room()
	_build_floor_markings()
	_build_props()
	var player := _spawn_player()
	_spawn_enemies(player)
	_spawn_hud(player)

func _build_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.29, 0.38, 0.55)
	sky_mat.sky_horizon_color = Color(0.62, 0.60, 0.56)
	sky_mat.sky_curve = 0.15
	sky_mat.ground_bottom_color = Color(0.14, 0.14, 0.15)
	sky_mat.ground_horizon_color = Color(0.42, 0.40, 0.37)
	sky_mat.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2

	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 1.4

	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.05

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.65, 0.72, 0.85)
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)

func _build_room() -> void:
	_add_box(Vector3(ARENA_WIDTH, WALL_THICKNESS, ARENA_DEPTH), Vector3(0, -WALL_THICKNESS / 2.0, 0), Color(0.17, 0.18, 0.20), 0.95)
	_add_box(Vector3(ARENA_WIDTH, ARENA_HEIGHT, WALL_THICKNESS), Vector3(0, ARENA_HEIGHT / 2.0, -ARENA_DEPTH / 2.0), Color(0.36, 0.38, 0.42))
	_add_box(Vector3(ARENA_WIDTH, ARENA_HEIGHT, WALL_THICKNESS), Vector3(0, ARENA_HEIGHT / 2.0, ARENA_DEPTH / 2.0), Color(0.36, 0.38, 0.42))
	_add_box(Vector3(WALL_THICKNESS, ARENA_HEIGHT, ARENA_DEPTH), Vector3(-ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0, 0), Color(0.32, 0.34, 0.38))
	_add_box(Vector3(WALL_THICKNESS, ARENA_HEIGHT, ARENA_DEPTH), Vector3(ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0, 0), Color(0.32, 0.34, 0.38))
	_build_wall_trim()

func _build_wall_trim() -> void:
	var trim_color := Color(0.1, 0.1, 0.11)
	var h := 0.22
	_add_marking(Vector3(ARENA_WIDTH, h, 0.08), Vector3(0, h / 2.0, -ARENA_DEPTH / 2.0 + 0.2), trim_color)
	_add_marking(Vector3(ARENA_WIDTH, h, 0.08), Vector3(0, h / 2.0, ARENA_DEPTH / 2.0 - 0.2), trim_color)
	_add_marking(Vector3(0.08, h, ARENA_DEPTH), Vector3(-ARENA_WIDTH / 2.0 + 0.2, h / 2.0, 0), trim_color)
	_add_marking(Vector3(0.08, h, ARENA_DEPTH), Vector3(ARENA_WIDTH / 2.0 - 0.2, h / 2.0, 0), trim_color)

func _build_floor_markings() -> void:
	_add_marking(Vector3(0.15, 0.02, ARENA_DEPTH - 1.0), Vector3(0, 0.011, 0), Color(0.75, 0.68, 0.15))
	_add_marking(Vector3(7.0, 0.02, 0.15), Vector3(-4.5, 0.011, 4.0), Color(0.72, 0.16, 0.12))
	_add_marking(Vector3(7.0, 0.02, 0.15), Vector3(4.5, 0.011, 4.0), Color(0.14, 0.34, 0.72))

func _add_marking(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_props() -> void:
	_add_box(Vector3(1.4, 1.1, 1.4), Vector3(-3.0, 0.55, 2.0), Color(0.30, 0.27, 0.20))
	_add_box(Vector3(1.4, 1.1, 1.4), Vector3(3.0, 0.55, 2.0), Color(0.30, 0.27, 0.20))
	_add_box(Vector3(1.6, 1.3, 1.6), Vector3(-5.0, 0.65, -1.0), Color(0.26, 0.28, 0.31))
	_add_box(Vector3(1.6, 1.3, 1.6), Vector3(5.0, 0.65, -1.0), Color(0.26, 0.28, 0.31))
	_add_box(Vector3(1.2, 0.9, 1.2), Vector3(0.0, 0.45, -5.0), Color(0.30, 0.27, 0.20))
	_add_cylinder(0.45, 1.0, Vector3(-1.8, 0.5, -5.5), Color(0.36, 0.24, 0.13))
	_add_cylinder(0.45, 1.0, Vector3(1.8, 0.5, -5.5), Color(0.33, 0.22, 0.12))
	_add_cylinder(0.4, 0.85, Vector3(-6.5, 0.425, 3.5), Color(0.32, 0.33, 0.35))
	_add_cylinder(0.4, 0.85, Vector3(6.5, 0.425, 3.5), Color(0.32, 0.33, 0.35))

func _add_box(size: Vector3, pos: Vector3, color: Color, roughness: float = 0.88) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = ProcGfx.make_noise_material(color, roughness, 0.16, max(size.x, size.z) * 0.7)
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body

func _add_cylinder(radius: float, height: float, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh_instance.mesh = cyl
	mesh_instance.material_override = ProcGfx.make_noise_material(color, 0.7, 0.22, 2.0)
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = height
	shape.shape = cyl_shape
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
