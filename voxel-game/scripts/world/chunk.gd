class_name Chunk
extends Node3D
## One vertical column of voxel data (SIZE_X x HEIGHT x SIZE_Z) rendered as a
## single mesh. Mesh geometry is built with face culling so only faces
## touching air/transparent blocks are emitted. Array construction can run
## on a worker thread; only apply_mesh_data() touches nodes and must run on
## the main thread.

const SIZE_X := 16
const SIZE_Z := 16
const HEIGHT := 128

## [normal, 4 corner offsets (CCW as seen from outside), neighbor delta]
const FACES := [
	{"normal": Vector3(1, 0, 0), "corners": [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)], "delta": Vector3i(1, 0, 0), "slot": "side"},
	{"normal": Vector3(-1, 0, 0), "corners": [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)], "delta": Vector3i(-1, 0, 0), "slot": "side"},
	{"normal": Vector3(0, 1, 0), "corners": [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)], "delta": Vector3i(0, 1, 0), "slot": "top"},
	{"normal": Vector3(0, -1, 0), "corners": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], "delta": Vector3i(0, -1, 0), "slot": "bottom"},
	{"normal": Vector3(0, 0, 1), "corners": [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)], "delta": Vector3i(0, 0, 1), "slot": "side"},
	{"normal": Vector3(0, 0, -1), "corners": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)], "delta": Vector3i(0, 0, -1), "slot": "side"},
]

var chunk_coord: Vector2i = Vector2i.ZERO
var blocks: PackedByteArray = PackedByteArray()
## Set once generate_terrain() has filled this chunk, so a later rebuild
## (triggered by an edit to this or a neighboring chunk) knows to rebuild
## the mesh only, never regenerate terrain over player edits.
var is_generated: bool = false

var mesh_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D

func setup(coord: Vector2i) -> void:
	chunk_coord = coord
	blocks.resize(SIZE_X * HEIGHT * SIZE_Z)
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	static_body = StaticBody3D.new()
	add_child(static_body)
	collision_shape = CollisionShape3D.new()
	static_body.add_child(collision_shape)

static func local_index(x: int, y: int, z: int) -> int:
	return x + z * SIZE_X + y * (SIZE_X * SIZE_Z)

func get_block_local(x: int, y: int, z: int) -> int:
	if x < 0 or x >= SIZE_X or y < 0 or y >= HEIGHT or z < 0 or z >= SIZE_Z:
		return BlockRegistry.AIR_ID
	return blocks[local_index(x, y, z)]

func set_block_local(x: int, y: int, z: int, id: int) -> void:
	if x < 0 or x >= SIZE_X or y < 0 or y >= HEIGHT or z < 0 or z >= SIZE_Z:
		return
	blocks[local_index(x, y, z)] = id

## Runs on the main thread (unlike mesh building, terrain generation never
## touches nodes, but World.generate is not itself thread-safe to call
## concurrently since its noise objects are shared, unguarded state).
## Fills each column via World.compute_column_block, which folds in
## biome strata, sea-level water, cave carving and tree placement.
func generate_terrain(world: VoxelWorld) -> void:
	var world_x_origin: int = chunk_coord.x * SIZE_X
	var world_z_origin: int = chunk_coord.y * SIZE_Z
	for lx in range(SIZE_X):
		for lz in range(SIZE_Z):
			var world_x: int = world_x_origin + lx
			var world_z: int = world_z_origin + lz
			var surface: int = clampi(world.get_terrain_height(world_x, world_z), 1, HEIGHT - 2)
			var biome: int = world.get_biome(world_x, world_z)
			var tree_columns: Array = world.get_nearby_tree_columns(world_x, world_z)
			var max_y: int = mini(HEIGHT - 1, maxi(surface + VoxelWorld.TREE_TRUNK_HEIGHT + VoxelWorld.TREE_CANOPY_RADIUS + 2, VoxelWorld.SEA_LEVEL))
			for ly in range(max_y + 1):
				var id: int = world.compute_column_block(world_x, ly, world_z, surface, biome, tree_columns)
				if id != BlockRegistry.AIR_ID:
					blocks[local_index(lx, ly, lz)] = id

## Pure computation, safe to call from a worker thread. neighbor_lookup is
## Callable(world_x:int, world_y:int, world_z:int) -> int, used only at the
## horizontal borders of this chunk to query adjacent chunks/terrain.
func build_mesh_data(neighbor_lookup: Callable) -> Dictionary:
	# Two independent surfaces: opaque (everything, one shared material) and
	# water (its own alpha-blended material). A block's faces go entirely
	# into one or the other — water is never mixed into the opaque surface.
	var opaque := _new_surface_arrays()
	var water := _new_surface_arrays()
	var collision_faces := PackedVector3Array()

	var world_x_origin: int = chunk_coord.x * SIZE_X
	var world_z_origin: int = chunk_coord.y * SIZE_Z

	for lx in range(SIZE_X):
		for lz in range(SIZE_Z):
			for ly in range(HEIGHT):
				var id: int = get_block_local(lx, ly, lz)
				if BlockRegistry.is_air(id):
					continue
				var block: BlockType = BlockRegistry.get_block(id)
				if block == null:
					continue
				var target: Dictionary = water if block.render_transparent else opaque
				for face in FACES:
					var delta: Vector3i = face["delta"]
					var nx: int = lx + delta.x
					var ny: int = ly + delta.y
					var nz: int = lz + delta.z
					var neighbor_id: int
					if ny < 0:
						neighbor_id = -1
					elif ny >= HEIGHT:
						neighbor_id = BlockRegistry.AIR_ID
					elif nx >= 0 and nx < SIZE_X and nz >= 0 and nz < SIZE_Z:
						neighbor_id = get_block_local(nx, ny, nz)
					else:
						neighbor_id = int(neighbor_lookup.call(world_x_origin + nx, ny, world_z_origin + nz))
					if neighbor_id == -1:
						continue
					if not BlockRegistry.is_transparent(neighbor_id):
						continue
					# Water-to-water faces would double-render the interior
					# of a lake (each side drawing its neighbor's face too,
					# visible through the alpha blend) — skip those, same
					# as the opaque surface already implicitly does since
					# solid-to-solid faces get culled above.
					if block.render_transparent and neighbor_id == id:
						continue

					var tile_index: int
					match face["slot"]:
						"top":
							tile_index = block.texture_top
						"bottom":
							tile_index = block.texture_bottom
						_:
							tile_index = block.texture_side
					var uv_rect: Rect2 = BlockRegistry.get_uv_rect(tile_index)

					var base_index: int = target["vertices"].size()
					var corners: Array = face["corners"]
					var block_origin := Vector3(lx, ly, lz)
					for corner in corners:
						target["vertices"].append(block_origin + corner)
						target["normals"].append(face["normal"])
					target["uvs"].append(Vector2(uv_rect.position.x, uv_rect.position.y))
					target["uvs"].append(Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y))
					target["uvs"].append(Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y))
					target["uvs"].append(Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y))

					target["indices"].append(base_index)
					target["indices"].append(base_index + 2)
					target["indices"].append(base_index + 1)
					target["indices"].append(base_index)
					target["indices"].append(base_index + 3)
					target["indices"].append(base_index + 2)

					if not block.render_transparent:
						collision_faces.append(target["vertices"][base_index])
						collision_faces.append(target["vertices"][base_index + 2])
						collision_faces.append(target["vertices"][base_index + 1])
						collision_faces.append(target["vertices"][base_index])
						collision_faces.append(target["vertices"][base_index + 3])
						collision_faces.append(target["vertices"][base_index + 2])

	return {
		"opaque": opaque,
		"water": water,
		"collision_faces": collision_faces,
	}

static func _new_surface_arrays() -> Dictionary:
	return {
		"vertices": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"uvs": PackedVector2Array(),
		"indices": PackedInt32Array(),
	}

## Must run on the main thread: creates the Mesh/CollisionShape resources
## and assigns them to this chunk's nodes. Builds up to two surfaces
## (opaque, water) each with its own material, since a single opaque
## StandardMaterial3D can't also render some faces alpha-blended.
func apply_mesh_data(data: Dictionary) -> void:
	if not is_instance_valid(mesh_instance):
		return
	var opaque: Dictionary = data["opaque"]
	var water: Dictionary = data["water"]

	if opaque["vertices"].is_empty() and water["vertices"].is_empty():
		mesh_instance.mesh = null
		collision_shape.shape = null
		return

	var array_mesh := ArrayMesh.new()
	if not opaque["vertices"].is_empty():
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _to_mesh_arrays(opaque))
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, BlockRegistry.chunk_material)
	if not water["vertices"].is_empty():
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _to_mesh_arrays(water))
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, BlockRegistry.water_material)
	mesh_instance.mesh = array_mesh

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data["collision_faces"])
	collision_shape.shape = shape

static func _to_mesh_arrays(surface: Dictionary) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = surface["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = surface["normals"]
	arrays[Mesh.ARRAY_TEX_UV] = surface["uvs"]
	arrays[Mesh.ARRAY_INDEX] = surface["indices"]
	return arrays
