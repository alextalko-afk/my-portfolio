class_name VoxelPlayer
extends CharacterBody3D
## FPS controller: WASD movement, mouse look, jump, sprint, plus raycast
## block breaking/placing with a wireframe highlight on the targeted block,
## and health/melee combat against mobs.

signal health_changed(current: float, max_value: float)
signal died
signal respawned

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 6.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.0025
@export var world_path: NodePath
@export var hud_path: NodePath
@export var reach: float = 6.0
@export var max_health: float = 20.0
@export var attack_damage: float = 4.0
@export var respawn_delay: float = 2.0
@export var respawn_invulnerability: float = 1.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var pitch: float = 0.0
var mouse_captured: bool = false

var _world: VoxelWorld
## Chunk meshing/collision finishes asynchronously after the world starts
## up, so gravity stays off until the spawn chunk actually has a collider —
## otherwise the player free-falls through the not-yet-built ground.
var _spawn_ready: bool = false

var inventory: Inventory = Inventory.new()
var selected_slot: int = 0

var health: float
var _is_dead: bool = false
var _invulnerable_until_ms: int = 0
var _spawn_position: Vector3

var _hud: Hud
var _highlight: MeshInstance3D

var _footstep_audio: AudioStreamPlayer3D
var _hurt_audio: AudioStreamPlayer3D
var _footstep_timer: float = 0.0

const HOTBAR_ACTIONS := ["hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5", "hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9"]

func _ready() -> void:
	add_to_group("player")
	_capture_mouse()
	if world_path != NodePath():
		_world = get_node(world_path)
	if hud_path != NodePath():
		_hud = get_node(hud_path)
		_hud.setup(self)
	_highlight = _build_highlight_mesh()
	if _world != null:
		_world.add_child(_highlight)
	_highlight.visible = false

	_footstep_audio = AudioStreamPlayer3D.new()
	_footstep_audio.stream = SoundLibrary.footstep
	add_child(_footstep_audio)

	_hurt_audio = AudioStreamPlayer3D.new()
	_hurt_audio.stream = SoundLibrary.player_hurt
	add_child(_hurt_audio)

	health = max_health
	_spawn_position = global_position

## Applied by Game after a save loads (Player's own _ready() has already
## run by then, setting the plain defaults this then overrides). Also
## resets the spawn/respawn point to the loaded position and re-arms the
## gravity gate, since the chunk under it hasn't necessarily loaded yet.
func load_state(loaded_position: Vector3, rotation_y: float, pitch_value: float, health_value: float) -> void:
	global_position = loaded_position
	rotation.y = rotation_y
	pitch = pitch_value
	head.rotation.x = pitch
	health = health_value
	_spawn_position = loaded_position
	_spawn_ready = false
	health_changed.emit(health, max_health)

func take_damage(amount: float) -> void:
	if _is_dead or Time.get_ticks_msec() < _invulnerable_until_ms:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	_hurt_audio.play()
	if health <= 0.0:
		_die()

func _die() -> void:
	_is_dead = true
	velocity = Vector3.ZERO
	_highlight.visible = false
	died.emit()
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()

func _respawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	health = max_health
	_is_dead = false
	_invulnerable_until_ms = Time.get_ticks_msec() + int(respawn_invulnerability * 1000.0)
	health_changed.emit(health, max_health)
	respawned.emit()

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if event.is_action_pressed("inventory"):
		_toggle_inventory()
		return
	for i in range(HOTBAR_ACTIONS.size()):
		if event.is_action_pressed(HOTBAR_ACTIONS[i]):
			selected_slot = i
			return

	if _hud != null and _hud.is_inventory_open():
		return

	if event is InputEventMouseMotion and mouse_captured:
		var motion: InputEventMouseMotion = event
		rotate_y(-motion.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - motion.relative.y * mouse_sensitivity, -1.55, 1.55)
		head.rotation.x = pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_release_mouse()
	elif event is InputEventMouseButton and event.pressed and not mouse_captured:
		_capture_mouse()
	elif event.is_action_pressed("break_block"):
		_break_targeted_block()
	elif event.is_action_pressed("place_block"):
		_place_targeted_block()

func get_world() -> VoxelWorld:
	return _world

func _toggle_inventory() -> void:
	if _hud == null:
		return
	_hud.toggle_inventory()
	if _hud.is_inventory_open():
		_release_mouse()
	else:
		_capture_mouse()

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not _spawn_ready:
		if _world != null and _world.is_position_ready(global_position):
			_spawn_ready = true
		else:
			return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction.length() > 0.01:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_footsteps(delta, speed)

func _update_footsteps(delta: float, speed: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or horizontal_speed < 0.5:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_audio.play()
		_footstep_timer = clampf(2.2 / speed, 0.28, 0.6)

func _process(_delta: float) -> void:
	if _is_dead:
		_highlight.visible = false
		return
	var hit: Dictionary = _raycast_block()
	if hit.is_empty():
		_highlight.visible = false
		return
	var block_pos: Vector3i = Vector3i(floor(hit["position"] - hit["normal"] * 0.5))
	_highlight.visible = true
	_highlight.global_position = Vector3(block_pos)

func _raycast_block() -> Dictionary:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + (-camera.global_transform.basis.z) * reach
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	return space_state.intersect_ray(query)

func _break_targeted_block() -> void:
	if _world == null:
		return
	var hit: Dictionary = _raycast_block()
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider is Node and collider.is_in_group("mob"):
		collider.take_damage(attack_damage)
		return
	var block_pos: Vector3i = Vector3i(floor(hit["position"] - hit["normal"] * 0.5))
	var broken_id: int = _world.get_block_at(block_pos.x, block_pos.y, block_pos.z)
	if not _world.set_block_world(block_pos.x, block_pos.y, block_pos.z, BlockRegistry.AIR_ID):
		return
	var block: BlockType = BlockRegistry.get_block(broken_id)
	if block != null and block.drop_item != "":
		var drop_id: int = BlockRegistry.get_id_by_name(block.drop_item)
		inventory.add_item(drop_id, 1)
	_play_one_shot_at(Vector3(block_pos) + Vector3(0.5, 0.5, 0.5), SoundLibrary.block_break)

func _place_targeted_block() -> void:
	if _world == null:
		return
	var held: Dictionary = inventory.get_slot(selected_slot)
	if held["id"] == BlockRegistry.AIR_ID or held["count"] <= 0:
		return
	var held_block: BlockType = BlockRegistry.get_block(held["id"])
	if held_block == null or not held_block.is_placeable:
		return
	var hit: Dictionary = _raycast_block()
	if hit.is_empty():
		return
	var place_pos: Vector3i = Vector3i(floor(hit["position"] + hit["normal"] * 0.5))
	if _overlaps_player(place_pos):
		return
	if _world.set_block_world(place_pos.x, place_pos.y, place_pos.z, held["id"]):
		inventory.remove_from_slot(selected_slot, 1)
		_play_one_shot_at(Vector3(place_pos) + Vector3(0.5, 0.5, 0.5), SoundLibrary.block_place)

## A one-off AudioStreamPlayer3D at a fixed world position (a block being
## broken/placed shouldn't sound like it's glued to the player, and won't
## move again after this single play), freed once playback finishes.
func _play_one_shot_at(world_pos: Vector3, stream: AudioStreamWAV) -> void:
	if _world == null:
		return
	var one_shot := AudioStreamPlayer3D.new()
	one_shot.stream = stream
	_world.add_child(one_shot)
	one_shot.global_position = world_pos
	one_shot.finished.connect(one_shot.queue_free)
	one_shot.play()

## Crude AABB check (capsule radius 0.4, height 1.8, origin at feet) so
## placing a block can't wedge it inside the player.
func _overlaps_player(block_pos: Vector3i) -> bool:
	var p: Vector3 = global_position
	var bx: float = float(block_pos.x)
	var by: float = float(block_pos.y)
	var bz: float = float(block_pos.z)
	var within_x: bool = p.x > bx - 0.4 and p.x < bx + 1.4
	var within_z: bool = p.z > bz - 0.4 and p.z < bz + 1.4
	var within_y: bool = p.y < by + 1.0 and p.y + 1.8 > by
	return within_x and within_z and within_y

func _build_highlight_mesh() -> MeshInstance3D:
	var vertices := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1),
		Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1),
	])
	var edges := PackedInt32Array([
		0, 1, 1, 2, 2, 3, 3, 0,
		4, 5, 5, 6, 6, 7, 7, 4,
		0, 4, 1, 5, 2, 6, 3, 7,
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = edges
	var line_mesh := ArrayMesh.new()
	line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0, 0, 0)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = line_mesh
	mesh_instance.material_override = material
	return mesh_instance
