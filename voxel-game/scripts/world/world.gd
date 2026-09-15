class_name VoxelWorld
extends Node3D
## Owns all loaded chunks, generates terrain via noise and streams chunks
## in/out around the player. Chunk data generation is cheap and stays on
## the main thread; mesh building (the expensive part) is dispatched to
## WorkerThreadPool and only the final node assignment is deferred back.

@export var render_distance: int = 4
@export var world_seed: int = 1337
@export var player_path: NodePath

var chunks: Dictionary = {}
var _pending_chunks: Dictionary = {}
var _pending_task_ids: Dictionary = {}
var _chunks_mutex: Mutex = Mutex.new()
## Block data keyed by chunk coord, kept separate from the Chunk nodes.
## Worker threads read only from here (under _chunks_mutex) so a chunk's
## visual node can be freed on the main thread without ever racing a
## background mesh-build task that is reading it as a border neighbor —
## PackedByteArray is a copy-on-write value type, so a copy fetched here
## stays valid even if the dictionary entry is erased right after.
var _chunk_blocks: Dictionary = {}
var noise: FastNoiseLite = FastNoiseLite.new()
var biome_noise: FastNoiseLite = FastNoiseLite.new()
var cave_noise: FastNoiseLite = FastNoiseLite.new()
var tree_noise: FastNoiseLite = FastNoiseLite.new()

enum Biome { PLAINS, DESERT }

const SEA_LEVEL := 38
const LAVA_LEVEL := 10
const CAVE_THRESHOLD := 0.55
const CAVE_MIN_DEPTH := 4
const TREE_TRUNK_HEIGHT := 5
const TREE_CANOPY_RADIUS := 2

var _grass_id: int = 0
var _dirt_id: int = 0
var _stone_id: int = 0
var _sand_id: int = 0
var _water_id: int = 0
var _lava_id: int = 0
var _wood_id: int = 0
var _leaves_id: int = 0
var _workbench_id: int = 0

## World positions currently holding a workbench block, so crafting can
## check proximity in O(number of workbenches) instead of scanning blocks.
var _workbench_positions: Dictionary = {}

var _player: Node3D
var _last_player_chunk: Vector2i = Vector2i(999999, 999999)

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5

	biome_noise.seed = world_seed + 1
	biome_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	biome_noise.frequency = 0.003

	cave_noise.seed = world_seed + 2
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = 0.06
	cave_noise.fractal_octaves = 3

	tree_noise.seed = world_seed + 3
	tree_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	tree_noise.frequency = 0.6

	_grass_id = BlockRegistry.get_id_by_name("grass")
	_dirt_id = BlockRegistry.get_id_by_name("dirt")
	_stone_id = BlockRegistry.get_id_by_name("stone")
	_sand_id = BlockRegistry.get_id_by_name("sand")
	_water_id = BlockRegistry.get_id_by_name("water")
	_lava_id = BlockRegistry.get_id_by_name("lava")
	_wood_id = BlockRegistry.get_id_by_name("wood")
	_leaves_id = BlockRegistry.get_id_by_name("leaves")
	_workbench_id = BlockRegistry.get_id_by_name("workbench")

	if player_path != NodePath():
		_player = get_node(player_path)

func is_near_workbench(world_pos: Vector3, radius: float) -> bool:
	for pos in _workbench_positions:
		var block_center: Vector3 = Vector3(pos) + Vector3(0.5, 0.5, 0.5)
		if world_pos.distance_to(block_center) <= radius:
			return true
	return false

func _process(_delta: float) -> void:
	if _player == null:
		var candidates: Array = get_tree().get_nodes_in_group("player")
		if candidates.is_empty():
			return
		_player = candidates[0]

	var player_chunk: Vector2i = world_pos_to_chunk_coord(_player.global_position)
	if player_chunk != _last_player_chunk:
		_last_player_chunk = player_chunk
		_update_loaded_chunks(player_chunk)

func world_pos_to_chunk_coord(world_pos: Vector3) -> Vector2i:
	return Vector2i(_floor_div(int(floor(world_pos.x)), Chunk.SIZE_X), _floor_div(int(floor(world_pos.z)), Chunk.SIZE_Z))

## True once the chunk under world_pos has its collision mesh built. Chunk
## meshing finishes asynchronously, so anything driven by gravity/physics
## (the player) must wait for this before falling, or it will tunnel
## straight through terrain that hasn't generated a collider yet.
func is_position_ready(world_pos: Vector3) -> bool:
	var coord: Vector2i = world_pos_to_chunk_coord(world_pos)
	return chunks.has(coord) and not _pending_chunks.has(coord)

func get_terrain_height(world_x: int, world_z: int) -> int:
	var n: float = noise.get_noise_2d(float(world_x), float(world_z))
	var height: float = 40.0 + n * 16.0
	return int(round(height))

func get_biome(world_x: int, world_z: int) -> int:
	return Biome.DESERT if biome_noise.get_noise_2d(float(world_x), float(world_z)) > 0.15 else Biome.PLAINS

func is_cave(world_x: int, world_y: int, world_z: int) -> bool:
	return cave_noise.get_noise_3d(float(world_x), float(world_y), float(world_z)) > CAVE_THRESHOLD

func _is_tree_column(world_x: int, world_z: int) -> bool:
	if get_biome(world_x, world_z) != Biome.PLAINS:
		return false
	return tree_noise.get_noise_2d(float(world_x), float(world_z)) > 0.9

## Tree columns (trunk base position) within canopy reach of (world_x,
## world_z). Precompute once per column and reuse across its Y range
## instead of re-sampling tree noise per block.
func get_nearby_tree_columns(world_x: int, world_z: int) -> Array:
	var result: Array = []
	for dx in range(-TREE_CANOPY_RADIUS, TREE_CANOPY_RADIUS + 1):
		for dz in range(-TREE_CANOPY_RADIUS, TREE_CANOPY_RADIUS + 1):
			var cx: int = world_x + dx
			var cz: int = world_z + dz
			if _is_tree_column(cx, cz):
				result.append(Vector2i(cx, cz))
	return result

## Simple trunk-plus-blob tree shape, evaluated against every tree column
## that could reach this position. Deterministic and purely a function of
## world position, so it agrees at chunk borders without any special-casing.
func get_tree_block_at(world_x: int, world_y: int, world_z: int, tree_columns: Array) -> int:
	for tree_col in tree_columns:
		var cx: int = tree_col.x
		var cz: int = tree_col.y
		var trunk_base: int = get_terrain_height(cx, cz)
		if world_x == cx and world_z == cz and world_y > trunk_base and world_y <= trunk_base + TREE_TRUNK_HEIGHT:
			return _wood_id
		var canopy_center_y: int = trunk_base + TREE_TRUNK_HEIGHT
		var dy: int = world_y - canopy_center_y
		if dy >= -2 and dy <= 1:
			var dist: float = Vector2(world_x - cx, world_z - cz).length()
			var radius: float = 2.2 if dy <= 0 else 1.4
			if dist <= radius:
				return _leaves_id
	return BlockRegistry.AIR_ID

## The single "ground truth" for what belongs at a coordinate, purely from
## generation rules. Bulk chunk generation precomputes surface/biome/tree
## columns once per (x,z) column for speed; this per-block version (used
## for the rare cross-chunk fallback query) just does that itself.
func compute_terrain_block(world_x: int, world_y: int, world_z: int) -> int:
	var surface: int = get_terrain_height(world_x, world_z)
	var biome: int = get_biome(world_x, world_z)
	var tree_columns: Array = get_nearby_tree_columns(world_x, world_z)
	return compute_column_block(world_x, world_y, world_z, surface, biome, tree_columns)

func compute_column_block(world_x: int, world_y: int, world_z: int, surface: int, biome: int, tree_columns: Array) -> int:
	if world_y > surface:
		if world_y <= SEA_LEVEL:
			return _water_id
		if world_y <= surface + TREE_TRUNK_HEIGHT + TREE_CANOPY_RADIUS + 2:
			return get_tree_block_at(world_x, world_y, world_z, tree_columns)
		return BlockRegistry.AIR_ID

	var block_id: int
	if world_y == surface:
		block_id = _sand_id if biome == Biome.DESERT else _grass_id
	elif world_y >= surface - 3:
		block_id = _sand_id if biome == Biome.DESERT else _dirt_id
	else:
		block_id = _stone_id

	if block_id == _stone_id and world_y < surface - CAVE_MIN_DEPTH and is_cave(world_x, world_y, world_z):
		return _lava_id if world_y <= LAVA_LEVEL else BlockRegistry.AIR_ID

	return block_id

## Thread-safe: safe to call from worker threads (used as the chunk-border
## neighbor lookup during mesh building). Reads only the plain-data block
## dictionary, never the Chunk node itself.
func get_block_world(world_x: int, world_y: int, world_z: int) -> int:
	if world_y < 0 or world_y >= Chunk.HEIGHT:
		return BlockRegistry.AIR_ID
	var coord := Vector2i(_floor_div(world_x, Chunk.SIZE_X), _floor_div(world_z, Chunk.SIZE_Z))
	_chunks_mutex.lock()
	var blocks: PackedByteArray = _chunk_blocks.get(coord, PackedByteArray())
	_chunks_mutex.unlock()
	if not blocks.is_empty():
		var local_x: int = world_x - coord.x * Chunk.SIZE_X
		var local_z: int = world_z - coord.y * Chunk.SIZE_Z
		return blocks[Chunk.local_index(local_x, world_y, local_z)]
	return compute_terrain_block(world_x, world_y, world_z)

## Breaks/places a block at the given world coordinates. Returns false and
## does nothing if the target chunk isn't loaded yet or is mid-rebuild
## (its blocks array must not be mutated while a worker thread might still
## be reading it for that same chunk's mesh build).
func set_block_world(world_x: int, world_y: int, world_z: int, id: int) -> bool:
	if world_y < 0 or world_y >= Chunk.HEIGHT:
		return false
	var coord := Vector2i(_floor_div(world_x, Chunk.SIZE_X), _floor_div(world_z, Chunk.SIZE_Z))
	if _pending_chunks.has(coord):
		return false
	var chunk: Chunk = chunks.get(coord)
	if chunk == null:
		return false

	var local_x: int = world_x - coord.x * Chunk.SIZE_X
	var local_z: int = world_z - coord.y * Chunk.SIZE_Z
	var previous_id: int = chunk.get_block_local(local_x, world_y, local_z)
	chunk.set_block_local(local_x, world_y, local_z, id)

	_chunks_mutex.lock()
	_chunk_blocks[coord] = chunk.blocks
	_chunks_mutex.unlock()

	var world_pos := Vector3i(world_x, world_y, world_z)
	if id == _workbench_id and previous_id != _workbench_id:
		_workbench_positions[world_pos] = true
	elif id != _workbench_id and previous_id == _workbench_id:
		_workbench_positions.erase(world_pos)

	_request_rebuild(coord)
	if local_x == 0:
		_request_rebuild(coord + Vector2i(-1, 0))
	if local_x == Chunk.SIZE_X - 1:
		_request_rebuild(coord + Vector2i(1, 0))
	if local_z == 0:
		_request_rebuild(coord + Vector2i(0, -1))
	if local_z == Chunk.SIZE_Z - 1:
		_request_rebuild(coord + Vector2i(0, 1))
	return true

func get_block_at(world_x: int, world_y: int, world_z: int) -> int:
	return get_block_world(world_x, world_y, world_z)

func _request_rebuild(coord: Vector2i) -> void:
	var chunk: Chunk = chunks.get(coord)
	if chunk == null or _pending_chunks.has(coord):
		return
	_pending_chunks[coord] = true
	_request_mesh_build(chunk)

func _update_loaded_chunks(center: Vector2i) -> void:
	var needed: Dictionary = {}
	for dx in range(-render_distance, render_distance + 1):
		for dz in range(-render_distance, render_distance + 1):
			if Vector2(dx, dz).length() > float(render_distance):
				continue
			var coord: Vector2i = center + Vector2i(dx, dz)
			needed[coord] = true
			if not chunks.has(coord) and not _pending_chunks.has(coord):
				_load_chunk(coord)

	var unload_radius: float = float(render_distance) + 1.5
	var to_remove: Array = []
	for coord in chunks.keys():
		if not _is_safe_to_unload(coord):
			continue
		var offset: Vector2 = Vector2(coord - center)
		if offset.length() > unload_radius:
			to_remove.append(coord)
	for coord in to_remove:
		_unload_chunk(coord)

## A chunk must not be freed while its own mesh build is still in flight:
## that worker thread is actively calling methods on this exact Chunk node.
func _is_safe_to_unload(coord: Vector2i) -> bool:
	return not _pending_chunks.has(coord)

func _load_chunk(coord: Vector2i) -> void:
	_pending_chunks[coord] = true

	var chunk := Chunk.new()
	chunk.setup(coord)
	chunk.position = Vector3(coord.x * Chunk.SIZE_X, 0, coord.y * Chunk.SIZE_Z)
	add_child(chunk)

	_chunks_mutex.lock()
	chunks[coord] = chunk
	_chunks_mutex.unlock()

	_request_mesh_build(chunk)

func _request_mesh_build(chunk: Chunk) -> void:
	var neighbor_lookup: Callable = Callable(self, "get_block_world")
	var coord: Vector2i = chunk.chunk_coord
	# Bound method, not an inline lambda: WorkerThreadPool + a lambda that
	# itself calls call_deferred() corrupts engine state on scene teardown
	# (Godot 4.3 issues #84325 / #95809). A bound Callable to a real method
	# does not hit that path.
	var task_id: int = WorkerThreadPool.add_task(Callable(self, "_build_chunk_mesh_task").bind(chunk, coord, neighbor_lookup))
	_pending_task_ids[coord] = task_id

## Generation (first load only, guarded by is_generated) and mesh building
## both run here so a chunk's ~11ms of terrain generation never blocks the
## main thread — with render_distance 4 (~49 chunks) that would otherwise
## stall a single frame for half a second on initial world load.
func _build_chunk_mesh_task(chunk: Chunk, coord: Vector2i, neighbor_lookup: Callable) -> void:
	if not chunk.is_generated:
		chunk.generate_terrain(self)
		chunk.is_generated = true
	var data: Dictionary = chunk.build_mesh_data(neighbor_lookup)
	call_deferred("_on_mesh_built", coord, data)

func _on_mesh_built(coord: Vector2i, data: Dictionary) -> void:
	_pending_chunks.erase(coord)
	_pending_task_ids.erase(coord)
	var chunk: Chunk = chunks.get(coord)
	if chunk == null or not is_instance_valid(chunk):
		return
	_chunks_mutex.lock()
	_chunk_blocks[coord] = chunk.blocks
	_chunks_mutex.unlock()
	chunk.apply_mesh_data(data)

## Sent when the OS requests the window close (X button / Alt+F4). Waiting
## here for outstanding tasks guarantees the scene tree teardown that
## follows quit() never races a worker thread still building a chunk mesh.
## Each drained task already queued its own call_deferred("_on_mesh_built")
## before returning, so queuing the actual quit() the same way lets those
## run first (deferred calls execute in submission order) instead of
## landing on nodes quit() has already started freeing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for task_id in _pending_task_ids.values():
			WorkerThreadPool.wait_for_task_completion(task_id)
		call_deferred("_finish_quit")

func _finish_quit() -> void:
	get_tree().quit()

func _unload_chunk(coord: Vector2i) -> void:
	var chunk: Chunk = chunks.get(coord)
	if chunk == null:
		return
	_chunks_mutex.lock()
	chunks.erase(coord)
	_chunk_blocks.erase(coord)
	_chunks_mutex.unlock()
	_pending_chunks.erase(coord)
	chunk.queue_free()

func _floor_div(a: int, b: int) -> int:
	return int(floor(float(a) / float(b)))
