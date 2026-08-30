class_name Enemy
extends Node3D
## A Terrorist or Spec Ops soldier: procedural low-poly rig (built from
## primitives, no external models), a small AI state machine (idle/patrol
## -> alert -> dead), and code-driven animation (walk cycle, aim raise,
## flinch, death topple, spawn-in) -- no hand-authored AnimationPlayer
## tracks, since those can't be visually tuned without a GUI.

enum Faction { TERRORIST, SPEC_OPS }
enum State { IDLE, PATROL, ALERT, DEAD }

const HEALTH_MAX := 100
const DETECT_RANGE := 15.0
const LOSE_SIGHT_TIME := 2.0
const FIRE_INTERVAL_MIN := 0.9
const FIRE_INTERVAL_MAX := 1.6
const DAMAGE_PER_HIT := 9
const MAX_EFFECTIVE_RANGE := 16.0
const WALK_SPEED := 1.7
const RESPAWN_DELAY := 3.0
const MUZZLE_FLASH_TIME := 0.06

var faction: int = Faction.TERRORIST
var state: int = State.IDLE
var health: int = HEALTH_MAX
var spawn_points: Array = []
var patrol_points: Array = []
var player: Node = null

var body: StaticBody3D
var head: StaticBody3D

var _hip: Node3D
var _torso: MeshInstance3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D

var _patrol_index: int = 0
var _lose_sight_timer: float = 0.0
var _fire_cooldown: float = randf_range(0.3, 1.2)
var _walk_phase: float = 0.0
var _spawn_scale_t: float = 1.0
var _flinch_t: float = 0.0
var _muzzle_timer: float = 0.0

var _muzzle_light: OmniLight3D
var _muzzle_mesh: MeshInstance3D
var _audio_fire: AudioStreamPlayer3D
var _audio_death: AudioStreamPlayer3D

func setup(new_faction: int, points: Array, patrol: Array, new_player: Node) -> void:
	faction = new_faction
	spawn_points = points
	patrol_points = patrol
	player = new_player
	_build_rig()
	_build_hitboxes()
	_build_audio()
	if spawn_points.size() > 0:
		global_position = spawn_points[randi() % spawn_points.size()]
	state = State.PATROL if patrol_points.size() > 1 else State.IDLE
	_play_spawn_in()

func _palette() -> Dictionary:
	if faction == Faction.SPEC_OPS:
		return {
			"cloth": Color(0.14, 0.17, 0.22),
			"armor": Color(0.09, 0.11, 0.14),
			"head": Color(0.07, 0.08, 0.10),
		}
	return {
		"cloth": Color(0.52, 0.45, 0.30),
		"armor": Color(0.35, 0.30, 0.20),
		"head": Color(0.30, 0.24, 0.16),
	}

func _make_part(parent: Node3D, size: Vector3, color: Color, local_pos: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh_instance.material_override = mat
	mesh_instance.position = local_pos
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_rig() -> void:
	var pal := _palette()

	_hip = Node3D.new()
	_hip.position = Vector3(0, 0.95, 0)
	add_child(_hip)

	_left_leg = Node3D.new()
	_left_leg.position = Vector3(-0.11, 0, 0)
	_hip.add_child(_left_leg)
	_make_part(_left_leg, Vector3(0.14, 0.9, 0.16), pal["cloth"], Vector3(0, -0.45, 0))

	_right_leg = Node3D.new()
	_right_leg.position = Vector3(0.11, 0, 0)
	_hip.add_child(_right_leg)
	_make_part(_right_leg, Vector3(0.14, 0.9, 0.16), pal["cloth"], Vector3(0, -0.45, 0))

	_torso = _make_part(_hip, Vector3(0.42, 0.62, 0.26), pal["armor"], Vector3(0, 0.36, 0))

	_left_arm = Node3D.new()
	_left_arm.position = Vector3(-0.28, 0.58, 0)
	_hip.add_child(_left_arm)
	_make_part(_left_arm, Vector3(0.13, 0.55, 0.13), pal["cloth"], Vector3(0, -0.28, 0))

	_right_arm = Node3D.new()
	_right_arm.position = Vector3(0.28, 0.58, 0)
	_hip.add_child(_right_arm)
	_make_part(_right_arm, Vector3(0.13, 0.55, 0.13), pal["cloth"], Vector3(0, -0.28, 0))
	_make_part(_right_arm, Vector3(0.06, 0.06, 0.42), Color(0.05, 0.05, 0.05), Vector3(0.02, -0.5, -0.15))

	var neck := Node3D.new()
	neck.position = Vector3(0, 0.7, 0)
	_hip.add_child(neck)
	var head_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	head_mesh.mesh = sphere
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = pal["head"]
	head_mesh.material_override = head_mat
	neck.add_child(head_mesh)

	var muzzle_anchor := Node3D.new()
	muzzle_anchor.position = Vector3(0.02, -0.72, -0.36)
	_right_arm.add_child(muzzle_anchor)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.8, 0.4)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 2.0
	muzzle_anchor.add_child(_muzzle_light)

	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1.0, 0.8, 0.4, 0.0)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_muzzle_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	_muzzle_mesh.mesh = quad
	_muzzle_mesh.material_override = flash_mat
	muzzle_anchor.add_child(_muzzle_mesh)

func _build_hitboxes() -> void:
	body = StaticBody3D.new()
	body.add_to_group("target_body")
	body.collision_layer = 1 << 2
	body.collision_mask = 0
	add_child(body)
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.3
	body_shape.shape = capsule
	body_shape.position = Vector3(0, 1.15, 0)
	body.add_child(body_shape)

	head = StaticBody3D.new()
	head.add_to_group("target_head")
	head.collision_layer = 1 << 2
	head.collision_mask = 0
	add_child(head)
	var head_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.2
	head_shape.position = Vector3(0, 1.65, 0)
	head_shape.shape = sphere_shape
	head.add_child(head_shape)

func _build_audio() -> void:
	_audio_fire = AudioStreamPlayer3D.new()
	_audio_fire.stream = load("res://audio/rifle_shot.wav")
	_audio_fire.volume_db = -8.0
	_audio_fire.max_distance = 30.0
	add_child(_audio_fire)

	_audio_death = AudioStreamPlayer3D.new()
	_audio_death.stream = load("res://audio/enemy_down.wav")
	_audio_death.max_distance = 30.0
	add_child(_audio_death)

func hit(zone: String, points: int, damage: int) -> void:
	if state == State.DEAD:
		return
	if zone == "head":
		_die(zone, points)
		return
	health -= damage
	_flinch_t = 1.0
	if health <= 0:
		_die(zone, points)

func _die(zone: String, points: int) -> void:
	state = State.DEAD
	GameState.register_hit(zone, points)
	_set_collision_enabled(false)
	_audio_death.play()
	_play_death_tween()
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	_respawn()

func _set_collision_enabled(enabled: bool) -> void:
	if body:
		body.set_collision_layer_value(3, enabled)
	if head:
		head.set_collision_layer_value(3, enabled)

func _play_death_tween() -> void:
	var fall := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:x", fall.y * 1.3, 0.35)
	tw.parallel().tween_property(self, "rotation:z", fall.x * 1.3, 0.35)
	tw.parallel().tween_property(self, "position:y", position.y - 0.4, 0.35)

func _respawn() -> void:
	if spawn_points.size() > 0:
		global_position = spawn_points[randi() % spawn_points.size()]
	rotation = Vector3.ZERO
	health = HEALTH_MAX
	_patrol_index = 0
	state = State.PATROL if patrol_points.size() > 1 else State.IDLE
	_set_collision_enabled(true)
	_play_spawn_in()

func _play_spawn_in() -> void:
	scale = Vector3.ONE * 0.001
	_spawn_scale_t = 0.0

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_update_ai(delta)
	_update_animation(delta)

func _update_ai(delta: float) -> void:
	if player == null or _spawn_scale_t < 1.0:
		return
	var can_see := _can_see_player()
	if can_see:
		_lose_sight_timer = LOSE_SIGHT_TIME
		state = State.ALERT
	elif state == State.ALERT:
		_lose_sight_timer -= delta
		if _lose_sight_timer <= 0.0:
			state = State.PATROL if patrol_points.size() > 1 else State.IDLE

	match state:
		State.ALERT:
			_face_player()
			_try_fire(delta)
		State.PATROL:
			_patrol(delta)

func _can_see_player() -> bool:
	if player == null:
		return false
	var eye_pos: Vector3 = global_position + Vector3(0, 1.6, 0)
	var target_pos: Vector3 = player.global_position + Vector3(0, 1.6, 0)
	if eye_pos.distance_to(target_pos) > DETECT_RANGE:
		return false
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye_pos, target_pos)
	query.collision_mask = 1
	return space_state.intersect_ray(query).is_empty()

func _face_player() -> void:
	var target: Vector3 = player.global_position
	target.y = global_position.y
	if global_position.distance_squared_to(target) > 0.0001:
		look_at(target, Vector3.UP)

func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	var target: Vector3 = patrol_points[_patrol_index]
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist < 0.15:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		return
	var dir := to_target.normalized()
	global_position += dir * WALK_SPEED * delta
	look_at(global_position + dir, Vector3.UP)
	_walk_phase += delta * 6.0

func _try_fire(delta: float) -> void:
	if GameState.is_dead:
		return
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return
	_fire_cooldown = randf_range(FIRE_INTERVAL_MIN, FIRE_INTERVAL_MAX)
	_muzzle_timer = MUZZLE_FLASH_TIME
	_audio_fire.play()
	var dist: float = global_position.distance_to(player.global_position)
	var hit_chance: float = clamp(1.0 - (dist / MAX_EFFECTIVE_RANGE), 0.15, 0.85)
	if randf() < hit_chance:
		GameState.take_damage(DAMAGE_PER_HIT)

func _update_muzzle_flash(delta: float) -> void:
	var mat := _muzzle_mesh.material_override as StandardMaterial3D
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
		var t: float = clamp(_muzzle_timer / MUZZLE_FLASH_TIME, 0.0, 1.0)
		_muzzle_light.light_energy = 5.0 * t
		mat.albedo_color.a = t
	else:
		_muzzle_light.light_energy = 0.0
		mat.albedo_color.a = 0.0

func _update_animation(delta: float) -> void:
	_update_muzzle_flash(delta)
	if _flinch_t > 0.0:
		_flinch_t = max(_flinch_t - delta * 5.0, 0.0)

	var torso_x := 0.0
	var lerp_t: float = clamp(delta * 6.0, 0.0, 1.0)
	match state:
		State.PATROL:
			var swing := sin(_walk_phase) * 0.5
			_left_leg.rotation.x = swing
			_right_leg.rotation.x = -swing
			_left_arm.rotation.x = -swing * 0.6
			_right_arm.rotation.x = swing * 0.6
			_hip.position.y = 0.95 + absf(sin(_walk_phase)) * 0.03
		State.ALERT:
			_left_leg.rotation.x = lerp(_left_leg.rotation.x, 0.0, lerp_t)
			_right_leg.rotation.x = lerp(_right_leg.rotation.x, 0.0, lerp_t)
			_right_arm.rotation.x = lerp(_right_arm.rotation.x, -1.1, clamp(delta * 8.0, 0.0, 1.0))
			_left_arm.rotation.x = lerp(_left_arm.rotation.x, -0.5, clamp(delta * 8.0, 0.0, 1.0))
			_hip.position.y = lerp(_hip.position.y, 0.95, lerp_t)
		State.IDLE:
			torso_x = sin(Time.get_ticks_msec() * 0.0015) * 0.02
			_left_leg.rotation.x = lerp(_left_leg.rotation.x, 0.0, lerp_t)
			_right_leg.rotation.x = lerp(_right_leg.rotation.x, 0.0, lerp_t)
			_left_arm.rotation.x = lerp(_left_arm.rotation.x, 0.0, lerp_t)
			_right_arm.rotation.x = lerp(_right_arm.rotation.x, 0.0, lerp_t)
			_hip.position.y = lerp(_hip.position.y, 0.95, lerp_t)

	_torso.rotation.x = torso_x - _flinch_t * 0.3

	if _spawn_scale_t < 1.0:
		_spawn_scale_t = min(_spawn_scale_t + delta * 3.5, 1.0)
		var eased: float = 1.0 - pow(1.0 - _spawn_scale_t, 3.0)
		scale = Vector3.ONE * eased
