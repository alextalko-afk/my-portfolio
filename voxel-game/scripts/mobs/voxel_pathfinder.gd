class_name VoxelPathfinder
extends RefCounted
## A* pathfinding directly over the voxel block grid — the way Minecraft
## itself paths mobs. Tried NavigationRegion3D/Recast first (one baked
## region per chunk); at the scale of dozens of simultaneously baked
## voxel-chunk regions it hit a real, reproducible NavigationServer bug
## (intermittent "already-merged edge" sync errors that left parts of the
## map disconnected — reproduced in isolation down to a two-region case
## working and a ~49-region case failing, so it wasn't misuse of the API).
## Recast/Detour's tiled navmesh generation assumes fairly non-repetitive
## static geometry; it isn't the standard tool for a voxel grid, which is
## exactly why a direct block-grid search is the normal answer here.

const MAX_FALL := 3
const MAX_NODES := 600

## Standable = solid floor beneath, open feet and head space above it —
## a 2-block-tall clearance, matching how Minecraft's own pathfinder
## evaluates voxel positions.
static func is_standable(world: VoxelWorld, x: int, y: int, z: int) -> bool:
	if y <= 0 or y >= Chunk.HEIGHT - 1:
		return false
	if BlockRegistry.is_solid(world.get_block_at(x, y, z)):
		return false
	if BlockRegistry.is_solid(world.get_block_at(x, y + 1, z)):
		return false
	return BlockRegistry.is_solid(world.get_block_at(x, y - 1, z))

static func _neighbors(world: VoxelWorld, pos: Vector3i) -> Array:
	var result: Array = []
	const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for dir in DIRS:
		var nx: int = pos.x + dir.x
		var nz: int = pos.z + dir.z
		if is_standable(world, nx, pos.y, nz):
			result.append(Vector3i(nx, pos.y, nz))
		elif is_standable(world, nx, pos.y + 1, nz) and not BlockRegistry.is_solid(world.get_block_at(pos.x, pos.y + 2, pos.z)):
			result.append(Vector3i(nx, pos.y + 1, nz))
		else:
			for fall in range(1, MAX_FALL + 1):
				if is_standable(world, nx, pos.y - fall, nz):
					result.append(Vector3i(nx, pos.y - fall, nz))
					break
	return result

## Returns a path of world-space waypoints (block center, integer Y) from
## start to goal, or an empty array if the goal wasn't reached within
## MAX_NODES expansions (out of practical reach, or genuinely unreachable).
static func find_path(world: VoxelWorld, start: Vector3, goal: Vector3) -> Array:
	var start_cell := Vector3i(floori(start.x), floori(start.y), floori(start.z))
	var goal_cell := Vector3i(floori(goal.x), floori(goal.y), floori(goal.z))

	if not is_standable(world, start_cell.x, start_cell.y, start_cell.z):
		# the mob itself isn't on solid, standable ground (mid-air, mid-fall,
		# etc.) — searching from there is meaningless, let gravity settle it
		return []

	var open: Array = [start_cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_cell: 0.0}
	var visited: Dictionary = {}
	var expansions: int = 0

	while not open.is_empty() and expansions < MAX_NODES:
		expansions += 1
		var best_index: int = 0
		var best_f: float = INF
		for i in range(open.size()):
			var cell: Vector3i = open[i]
			var f: float = g_score[cell] + Vector3(cell - goal_cell).length()
			if f < best_f:
				best_f = f
				best_index = i
		var current: Vector3i = open[best_index]
		open.remove_at(best_index)
		if visited.has(current):
			continue
		visited[current] = true

		if current.x == goal_cell.x and current.z == goal_cell.z and absi(current.y - goal_cell.y) <= 1:
			return _reconstruct(came_from, current)

		for neighbor in _neighbors(world, current):
			if visited.has(neighbor):
				continue
			var tentative: float = g_score[current] + 1.0
			if tentative < g_score.get(neighbor, INF):
				g_score[neighbor] = tentative
				came_from[neighbor] = current
				open.append(neighbor)

	return []

static func _reconstruct(came_from: Dictionary, end: Vector3i) -> Array:
	var cells: Array = [end]
	var current: Vector3i = end
	while came_from.has(current):
		current = came_from[current]
		cells.append(current)
	cells.reverse()
	var world_path: Array = []
	for cell in cells:
		world_path.append(Vector3(cell.x + 0.5, cell.y, cell.z + 0.5))
	return world_path
