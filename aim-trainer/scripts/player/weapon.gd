class_name Weapon
extends Node3D
## One weapon instance: hitscan fire, deterministic recoil pattern, spread
## bloom, reload, muzzle flash and a small blockout viewmodel built at
## runtime from primitives (no external art assets).

signal ammo_changed(mag: int, reserve: int)

var stats
var player: Node = null
var camera: Camera3D

var mag_ammo: int = 0
var reserve_ammo: int = 0
var is_reloading: bool = false
var active: bool = false

var _fire_cooldown: float = 0.0
var _time_since_last_shot: float = 999.0
var _shots_since_rest: int = 0
var _current_bloom: float = 0.0
var _reload_timer: float = 0.0
var _empty_click_latch: bool = false

var _base_local_pos: Vector3 = Vector3(0.32, -0.28, -0.55)
var _bob_time: float = 0.0
var _recoil_kick: float = 0.0
var _muzzle_timer: float = 0.0

var _muzzle_light: OmniLight3D
var _muzzle_mesh: MeshInstance3D
var _audio_fire: AudioStreamPlayer
var _audio_reload_out: AudioStreamPlayer
var _audio_reload_in: AudioStreamPlayer
var _audio_empty: AudioStreamPlayer

func setup(new_stats, new_player: Node, new_camera: Camera3D) -> void:
	stats = new_stats
	player = new_player
	camera = new_camera
	mag_ammo = stats.mag_size
	reserve_ammo = stats.reserve_ammo
	name = stats.weapon_name
	position = _base_local_pos
	_build_viewmodel()
	_build_audio()

func set_active(value: bool) -> void:
	active = value
	visible = value
	if value:
		ammo_changed.emit(mag_ammo, reserve_ammo)

func get_ammo_text() -> String:
	return "%d / %d" % [mag_ammo, reserve_ammo]

func get_spread_deg() -> float:
	return stats.spread_base_deg + _current_bloom if stats else 0.0

func _build_viewmodel() -> void:
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	(body.mesh as BoxMesh).size = Vector3(0.09, 0.11, 0.42)
	body.material_override = _make_material(Color(0.08, 0.08, 0.09))
	add_child(body)

	var barrel := MeshInstance3D.new()
	barrel.mesh = BoxMesh.new()
	(barrel.mesh as BoxMesh).size = Vector3(0.035, 0.035, 0.28)
	barrel.material_override = _make_material(Color(0.05, 0.05, 0.05))
	barrel.position = Vector3(0, 0.015, -0.34)
	add_child(barrel)

	var grip := MeshInstance3D.new()
	grip.mesh = BoxMesh.new()
	(grip.mesh as BoxMesh).size = Vector3(0.06, 0.16, 0.06)
	grip.material_override = _make_material(Color(0.1, 0.1, 0.11))
	grip.position = Vector3(0, -0.11, 0.08)
	grip.rotation.x = deg_to_rad(12.0)
	add_child(grip)

	var mag := MeshInstance3D.new()
	mag.mesh = BoxMesh.new()
	(mag.mesh as BoxMesh).size = Vector3(0.045, 0.16, 0.06)
	mag.material_override = _make_material(Color(0.12, 0.12, 0.13))
	mag.position = Vector3(0, -0.13, -0.06)
	mag.rotation.x = deg_to_rad(-8.0)
	add_child(mag)

	var muzzle_anchor := Node3D.new()
	muzzle_anchor.position = Vector3(0, 0.015, -0.48)
	add_child(muzzle_anchor)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = stats.muzzle_color
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 2.5
	muzzle_anchor.add_child(_muzzle_light)

	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(stats.muzzle_color.r, stats.muzzle_color.g, stats.muzzle_color.b, 0.0)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	_muzzle_mesh = MeshInstance3D.new()
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2(0.14, 0.14)
	_muzzle_mesh.mesh = flash_mesh
	_muzzle_mesh.material_override = flash_mat
	muzzle_anchor.add_child(_muzzle_mesh)

func _make_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	return m

func _build_audio() -> void:
	_audio_fire = AudioStreamPlayer.new()
	_audio_fire.stream = load(stats.fire_sound_path)
	_audio_fire.volume_db = -4.0
	add_child(_audio_fire)

	_audio_reload_out = AudioStreamPlayer.new()
	_audio_reload_out.stream = load("res://audio/reload_out.wav")
	add_child(_audio_reload_out)

	_audio_reload_in = AudioStreamPlayer.new()
	_audio_reload_in.stream = load("res://audio/reload_in.wav")
	add_child(_audio_reload_in)

	_audio_empty = AudioStreamPlayer.new()
	_audio_empty.stream = load("res://audio/empty_click.wav")
	_audio_empty.volume_db = -6.0
	add_child(_audio_empty)

func _process(delta: float) -> void:
	_update_muzzle_flash(delta)
	if active:
		_update_viewmodel_motion(delta)

func _physics_process(delta: float) -> void:
	_time_since_last_shot += delta
	_fire_cooldown = max(_fire_cooldown - delta, 0.0)

	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	if _time_since_last_shot > stats.recoil_reset_time:
		_shots_since_rest = 0
	_current_bloom = max(_current_bloom - stats.bloom_recovery_deg_per_sec * delta, 0.0)

	if not active or is_reloading:
		return

	if Input.is_action_just_pressed("reload") and mag_ammo < stats.mag_size and reserve_ammo > 0:
		_start_reload()
		return

	var wants_fire: bool = Input.is_action_pressed("fire") if stats.automatic else Input.is_action_just_pressed("fire")
	if wants_fire and _fire_cooldown <= 0.0:
		if mag_ammo > 0:
			_fire()
			_empty_click_latch = false
		elif not _empty_click_latch:
			_audio_empty.play()
			_empty_click_latch = true
			if reserve_ammo > 0:
				_start_reload()
	elif not Input.is_action_pressed("fire"):
		_empty_click_latch = false

func _fire() -> void:
	mag_ammo -= 1
	_fire_cooldown = stats.fire_interval
	_time_since_last_shot = 0.0
	_recoil_kick = 1.0
	ammo_changed.emit(mag_ammo, reserve_ammo)

	var move_penalty := 0.0
	if player and player.has_method("get_horizontal_speed"):
		var ratio: float = clamp(player.get_horizontal_speed() / max(player.walk_speed, 0.01), 0.0, 1.0)
		move_penalty = ratio * stats.spread_move_penalty_deg
	var total_spread_deg: float = stats.spread_base_deg + _current_bloom + move_penalty
	_current_bloom = min(_current_bloom + stats.bloom_per_shot_deg, stats.bloom_max_deg)

	var recoil: Vector2 = stats.get_recoil(_shots_since_rest)
	if player and player.has_method("apply_recoil"):
		player.apply_recoil(recoil)
	_shots_since_rest += 1

	GameState.register_shot()
	_raycast_shot(total_spread_deg)

	_muzzle_timer = 0.06
	_audio_fire.stop()
	_audio_fire.play()

func _raycast_shot(spread_deg: float) -> void:
	if not camera:
		return
	var space_state := camera.get_world_3d().direct_space_state
	var forward: Vector3 = -camera.global_transform.basis.z
	var spread_dir: Vector3 = _apply_spread(forward, spread_deg)
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + spread_dir * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b101
	var result := space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		if collider.is_in_group("target_head"):
			collider.get_parent().hit("head", stats.points_head)
		elif collider.is_in_group("target_body"):
			collider.get_parent().hit("body", stats.points_body)
		else:
			GameState.register_miss()
	else:
		GameState.register_miss()

func _apply_spread(forward: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return forward
	var rand_pitch := deg_to_rad(randf_range(-spread_deg, spread_deg))
	var rand_yaw := deg_to_rad(randf_range(-spread_deg, spread_deg))
	var spread_basis := Basis(Vector3.UP, rand_yaw) * Basis(Vector3.RIGHT, rand_pitch)
	return (spread_basis * forward).normalized()

func _start_reload() -> void:
	is_reloading = true
	_reload_timer = stats.reload_time
	_audio_reload_out.play()

func _finish_reload() -> void:
	var needed: int = stats.mag_size - mag_ammo
	var take: int = min(needed, reserve_ammo)
	mag_ammo += take
	reserve_ammo -= take
	is_reloading = false
	ammo_changed.emit(mag_ammo, reserve_ammo)
	_audio_reload_in.play()

func _update_muzzle_flash(delta: float) -> void:
	var mat := _muzzle_mesh.material_override as StandardMaterial3D
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
		var t: float = clamp(_muzzle_timer / 0.06, 0.0, 1.0)
		_muzzle_light.light_energy = 6.0 * t
		mat.albedo_color.a = t
		_muzzle_mesh.scale = Vector3.ONE * (0.6 + 0.6 * (1.0 - t))
	else:
		_muzzle_light.light_energy = 0.0
		mat.albedo_color.a = 0.0

func _update_viewmodel_motion(delta: float) -> void:
	var speed_ratio := 0.0
	if player and player.has_method("get_horizontal_speed"):
		speed_ratio = clamp(player.get_horizontal_speed() / max(player.walk_speed, 0.01), 0.0, 1.0)
	if speed_ratio > 0.05:
		_bob_time += delta * (8.0 + speed_ratio * 6.0)
	var bob_offset := Vector3(sin(_bob_time) * 0.01, absf(cos(_bob_time)) * 0.012, 0.0) * speed_ratio

	_recoil_kick = max(_recoil_kick - delta * 8.0, 0.0)
	var kick_offset := Vector3(0.0, 0.0, _recoil_kick * 0.06)

	position = _base_local_pos + bob_offset + kick_offset
	rotation.x = -_recoil_kick * 0.12
