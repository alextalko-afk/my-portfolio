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

var _grass_id: int = 0
var _dirt_id: int = 0
var _stone_id: int = 0

var _player: Node3D
var _last_player_chunk: Vector2i = Vector2i(999999, 999999)

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5

	_grass_id = BlockRegistry.get_id_by_name("grass")
	_dirt_id = BlockRegistry.get_id_by_name("dirt")
	_stone_id = BlockRegistry.get_id_by_name("stone")

	if player_path != NodePath():
		_player = get_node(player_path)

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
	return _compute_block_at(world_x, world_y, world_z)

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
	chunk.set_block_local(local_x, world_y, local_z, id)

	_chunks_mutex.lock()
	_chunk_blocks[coord] = chunk.blocks
	_chunks_mutex.unlock()

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

func _compute_block_at(world_x: int, world_y: int, world_z: int) -> int:
	var surface: int = get_terrain_height(world_x, world_z)
	if world_y > surface:
		return BlockRegistry.AIR_ID
	elif world_y == surface:
		return _grass_id
	elif world_y >= surface - 3:
		return _dirt_id
	return _stone_id

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

	var height_sampler: Callable = Callable(self, "get_terrain_height")
	chunk.generate_terrain(height_sampler, _grass_id, _dirt_id, _stone_id)

	_chunks_mutex.lock()
	chunks[coord] = chunk
	_chunk_blocks[coord] = chunk.blocks
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

func _build_chunk_mesh_task(chunk: Chunk, coord: Vector2i, neighbor_lookup: Callable) -> void:
	var data: Dictionary = chunk.build_mesh_data(neighbor_lookup)
	call_deferred("_on_mesh_built", coord, data)

func _on_mesh_built(coord: Vector2i, data: Dictionary) -> void:
	_pending_chunks.erase(coord)
	_pending_task_ids.erase(coord)
	var chunk: Chunk = chunks.get(coord)
	if chunk == null or not is_instance_valid(chunk):
		return
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
