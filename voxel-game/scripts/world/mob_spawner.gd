class_name MobSpawner
extends Node
## Spawns zombies (the base Mob) near the player at night, within a loaded
## ring of the world, and despawns them again once day breaks (a simple
## stand-in for "burns in sunlight" that also caps the population without
## extra bookkeeping).

@export var world_path: NodePath
@export var day_night_path: NodePath
@export var max_mobs: int = 4
@export var spawn_interval: float = 5.0
@export var spawn_min_distance: float = 10.0
@export var spawn_max_distance: float = 20.0

var _world: VoxelWorld
var _day_night: DayNightCycle
var _player: Node3D
var _timer: float = 0.0
var _mobs: Array = []

func _ready() -> void:
	if world_path != NodePath():
		_world = get_node(world_path)
	if day_night_path != NodePath():
		_day_night = get_node(day_night_path)

func _process(delta: float) -> void:
	if _player == null:
		var candidates: Array = get_tree().get_nodes_in_group("player")
		if candidates.is_empty():
			return
		_player = candidates[0]

	# Untyped lambda parameter: a freed mob reference still lingering in
	# _mobs would fail Godot's argument type-check against a typed "Node"
	# parameter before is_instance_valid() ever gets a chance to run.
	_mobs = _mobs.filter(func(m): return is_instance_valid(m))

	if _day_night == null or not _day_night.is_night():
		for m in _mobs:
			m.queue_free()
		_mobs.clear()
		return

	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval

	if _mobs.size() >= max_mobs:
		return
	_try_spawn()

func _try_spawn() -> void:
	if _world == null or _player == null:
		return
	var angle: float = randf() * TAU
	var dist: float = randf_range(spawn_min_distance, spawn_max_distance)
	var spawn_x: int = int(round(_player.global_position.x + cos(angle) * dist))
	var spawn_z: int = int(round(_player.global_position.z + sin(angle) * dist))
	var surface: int = _world.get_terrain_height(spawn_x, spawn_z)
	var spawn_pos := Vector3(spawn_x + 0.5, surface + 1.0, spawn_z + 0.5)

	if not _world.is_position_ready(spawn_pos):
		return
	var ground_id: int = _world.get_block_at(spawn_x, surface, spawn_z)
	if not BlockRegistry.is_solid(ground_id):
		return

	var mob := Mob.new()
	Mob.build_visuals(mob)
	mob.position = spawn_pos
	mob.set_target(_player)
	_world.add_child(mob)
	_mobs.append(mob)
