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

var mesh_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D

func setup(coord: Vector2i) -> void:
	chunk_coord = coord
	blocks.resize(SIZE_X * HEIGHT * SIZE_Z)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.material_override = BlockRegistry.chunk_material
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

## Pure computation, safe to call from a worker thread: fills the column
## using a surface-height sampler (world_x, world_z) -> int.
func generate_terrain(height_sampler: Callable, grass_id: int, dirt_id: int, stone_id: int) -> void:
	var world_x_origin: int = chunk_coord.x * SIZE_X
	var world_z_origin: int = chunk_coord.y * SIZE_Z
	for lx in range(SIZE_X):
		for lz in range(SIZE_Z):
			var world_x: int = world_x_origin + lx
			var world_z: int = world_z_origin + lz
			var surface: int = int(height_sampler.call(world_x, world_z))
			surface = clampi(surface, 1, HEIGHT - 2)
			for ly in range(surface + 1):
				var id: int
				if ly == surface:
					id = grass_id
				elif ly >= surface - 3:
					id = dirt_id
				else:
					id = stone_id
				blocks[local_index(lx, ly, lz)] = id

## Pure computation, safe to call from a worker thread. neighbor_lookup is
## Callable(world_x:int, world_y:int, world_z:int) -> int, used only at the
## horizontal borders of this chunk to query adjacent chunks/terrain.
func build_mesh_data(neighbor_lookup: Callable) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
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

					var tile_index: int
					match face["slot"]:
						"top":
							tile_index = block.texture_top
						"bottom":
							tile_index = block.texture_bottom
						_:
							tile_index = block.texture_side
					var uv_rect: Rect2 = BlockRegistry.get_uv_rect(tile_index)

					var base_index: int = vertices.size()
					var corners: Array = face["corners"]
					var block_origin := Vector3(lx, ly, lz)
					for corner in corners:
						vertices.append(block_origin + corner)
						normals.append(face["normal"])
					uvs.append(Vector2(uv_rect.position.x, uv_rect.position.y))
					uvs.append(Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y))
					uvs.append(Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y))
					uvs.append(Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y))

					indices.append(base_index)
					indices.append(base_index + 2)
					indices.append(base_index + 1)
					indices.append(base_index)
					indices.append(base_index + 3)
					indices.append(base_index + 2)

					collision_faces.append(vertices[base_index])
					collision_faces.append(vertices[base_index + 2])
					collision_faces.append(vertices[base_index + 1])
					collision_faces.append(vertices[base_index])
					collision_faces.append(vertices[base_index + 3])
					collision_faces.append(vertices[base_index + 2])

	return {
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices,
		"collision_faces": collision_faces,
	}

## Must run on the main thread: creates the Mesh/CollisionShape resources
## and assigns them to this chunk's nodes.
func apply_mesh_data(data: Dictionary) -> void:
	if not is_instance_valid(mesh_instance):
		return
	var vertices: PackedVector3Array = data["vertices"]
	if vertices.is_empty():
		mesh_instance.mesh = null
		collision_shape.shape = null
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data["collision_faces"])
	collision_shape.shape = shape
