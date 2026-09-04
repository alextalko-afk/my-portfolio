class_name Weapon
extends Node3D
## One weapon instance: hitscan (or short-range melee) fire, deterministic
## recoil pattern, spread bloom, reload, ADS zoom, muzzle flash/tracer and
## a small blockout viewmodel built at runtime from primitives (no external
## art assets). Animated procedurally: idle bob/sway, recoil kick, reload
## dip, draw-on-switch rise, and a melee swing arc.

signal ammo_changed(mag: int, reserve: int)

const ProcGfx := preload("res://scripts/world/proc_gfx.gd")

const DEFAULT_FOV := 90.0
const MUZZLE_FLASH_TIME := 0.06
const DRAW_TIME := 0.22
const RELOAD_DIP := 0.14

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

var _base_local_pos: Vector3 = Vector3(0.28, -0.24, -0.68)
var _bob_time: float = 0.0
var _recoil_kick: float = 0.0
var _muzzle_timer: float = 0.0
var _draw_t: float = 1.0
var _swing_t: float = 1.0

var _muzzle_light: OmniLight3D
var _muzzle_mesh: MeshInstance3D
var _audio_fire: AudioStreamPlayer
var _audio_reload_out: AudioStreamPlayer
var _audio_reload_in: AudioStreamPlayer
var _audio_empty: AudioStreamPlayer
var _audio_melee_hit: AudioStreamPlayer
var _scorch_tex: ImageTexture

func setup(new_stats, new_player: Node, new_camera: Camera3D) -> void:
	stats = new_stats
	player = new_player
	camera = new_camera
	_scorch_tex = ProcGfx.make_scorch_texture()
	mag_ammo = stats.mag_size
	reserve_ammo = stats.reserve_ammo
	name = stats.weapon_name
	position = _base_local_pos
	if stats.is_melee:
		_build_knife_viewmodel()
	else:
		_build_gun_viewmodel()
	_build_audio()

func set_active(value: bool) -> void:
	active = value
	visible = value
	if value:
		_draw_t = 0.0
		ammo_changed.emit(mag_ammo, reserve_ammo)
	elif camera:
		camera.fov = DEFAULT_FOV

func get_ammo_text() -> String:
	if stats.is_melee:
		return "MELEE"
	return "%d / %d" % [mag_ammo, reserve_ammo]

func get_spread_deg() -> float:
	return stats.spread_base_deg + _current_bloom if stats else 0.0

func _build_gun_viewmodel() -> void:
	var metal_mat := _metal_material(Color(0.13, 0.14, 0.16))
	var poly_mat := ProcGfx.make_noise_material(Color(0.20, 0.17, 0.13), 0.8, 0.14, 3.0)

	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	(body.mesh as BoxMesh).size = Vector3(0.09, 0.11, 0.42)
	body.material_override = metal_mat
	add_child(body)

	var barrel := MeshInstance3D.new()
	barrel.mesh = BoxMesh.new()
	(barrel.mesh as BoxMesh).size = Vector3(0.035, 0.035, 0.28)
	barrel.material_override = metal_mat
	barrel.position = Vector3(0, 0.015, -0.34)
	add_child(barrel)

	var foregrip := MeshInstance3D.new()
	foregrip.mesh = BoxMesh.new()
	(foregrip.mesh as BoxMesh).size = Vector3(0.05, 0.05, 0.15)
	foregrip.material_override = poly_mat
	foregrip.position = Vector3(0, -0.038, -0.27)
	add_child(foregrip)

	var front_sight := MeshInstance3D.new()
	front_sight.mesh = BoxMesh.new()
	(front_sight.mesh as BoxMesh).size = Vector3(0.014, 0.05, 0.014)
	front_sight.material_override = metal_mat
	front_sight.position = Vector3(0, 0.065, -0.46)
	add_child(front_sight)

	var rear_sight := MeshInstance3D.new()
	rear_sight.mesh = BoxMesh.new()
	(rear_sight.mesh as BoxMesh).size = Vector3(0.05, 0.025, 0.02)
	rear_sight.material_override = metal_mat
	rear_sight.position = Vector3(0, 0.075, 0.12)
	add_child(rear_sight)

	var trigger_guard := MeshInstance3D.new()
	trigger_guard.mesh = BoxMesh.new()
	(trigger_guard.mesh as BoxMesh).size = Vector3(0.05, 0.018, 0.09)
	trigger_guard.material_override = poly_mat
	trigger_guard.position = Vector3(0, -0.055, 0.04)
	add_child(trigger_guard)

	var grip := MeshInstance3D.new()
	grip.mesh = BoxMesh.new()
	(grip.mesh as BoxMesh).size = Vector3(0.06, 0.16, 0.06)
	grip.material_override = poly_mat
	grip.position = Vector3(0, -0.11, 0.08)
	grip.rotation.x = deg_to_rad(12.0)
	add_child(grip)

	var mag := MeshInstance3D.new()
	mag.mesh = BoxMesh.new()
	(mag.mesh as BoxMesh).size = Vector3(0.045, 0.16, 0.06)
	mag.material_override = poly_mat
	mag.position = Vector3(0, -0.13, -0.06)
	mag.rotation.x = deg_to_rad(-8.0)
	add_child(mag)

	if stats.has_ads:
		var scope := MeshInstance3D.new()
		scope.mesh = BoxMesh.new()
		(scope.mesh as BoxMesh).size = Vector3(0.045, 0.045, 0.2)
		scope.material_override = metal_mat
		scope.position = Vector3(0, 0.08, -0.09)
		add_child(scope)

		var scope_lens := MeshInstance3D.new()
		scope_lens.mesh = CylinderMesh.new()
		var lens := scope_lens.mesh as CylinderMesh
		lens.top_radius = 0.026
		lens.bottom_radius = 0.026
		lens.height = 0.008
		scope_lens.rotation_degrees = Vector3(90, 0, 0)
		var lens_mat := StandardMaterial3D.new()
		lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lens_mat.albedo_color = Color(0.15, 0.55, 0.4)
		lens_mat.emission_enabled = true
		lens_mat.emission = Color(0.1, 0.4, 0.3)
		lens_mat.emission_energy_multiplier = 0.6
		scope_lens.material_override = lens_mat
		scope_lens.position = Vector3(0, 0.08, -0.19)
		add_child(scope_lens)
	else:
		var stock := MeshInstance3D.new()
		stock.mesh = BoxMesh.new()
		(stock.mesh as BoxMesh).size = Vector3(0.05, 0.06, 0.15)
		stock.material_override = poly_mat
		stock.position = Vector3(0, 0.0, 0.10)
		add_child(stock)

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

func _build_knife_viewmodel() -> void:
	var handle_mat := ProcGfx.make_noise_material(Color(0.22, 0.16, 0.1), 0.8, 0.14, 6.0)
	var handle := MeshInstance3D.new()
	handle.mesh = BoxMesh.new()
	(handle.mesh as BoxMesh).size = Vector3(0.05, 0.05, 0.16)
	handle.material_override = handle_mat
	handle.position = Vector3(0, 0, 0.05)
	add_child(handle)

	var wrap := MeshInstance3D.new()
	wrap.mesh = CylinderMesh.new()
	var wrap_cyl := wrap.mesh as CylinderMesh
	wrap_cyl.top_radius = 0.029
	wrap_cyl.bottom_radius = 0.029
	wrap_cyl.height = 0.13
	wrap.rotation_degrees = Vector3(90, 0, 0)
	wrap.material_override = ProcGfx.make_noise_material(Color(0.08, 0.08, 0.09), 0.9, 0.2, 8.0)
	wrap.position = Vector3(0, 0, 0.05)
	add_child(wrap)

	var guard := MeshInstance3D.new()
	guard.mesh = BoxMesh.new()
	(guard.mesh as BoxMesh).size = Vector3(0.1, 0.03, 0.02)
	guard.material_override = _metal_material(Color(0.15, 0.15, 0.16))
	guard.position = Vector3(0, 0, -0.05)
	add_child(guard)

	var blade_mat := _metal_material(Color(0.78, 0.8, 0.82))
	blade_mat.metallic = 0.85
	blade_mat.roughness = 0.2
	var blade := MeshInstance3D.new()
	blade.mesh = BoxMesh.new()
	(blade.mesh as BoxMesh).size = Vector3(0.022, 0.018, 0.32)
	blade.material_override = blade_mat
	blade.position = Vector3(0, 0.01, -0.22)
	add_child(blade)

	var blade_edge := MeshInstance3D.new()
	blade_edge.mesh = BoxMesh.new()
	(blade_edge.mesh as BoxMesh).size = Vector3(0.03, 0.004, 0.3)
	blade_edge.material_override = blade_mat
	blade_edge.position = Vector3(0, -0.006, -0.22)
	add_child(blade_edge)

func _make_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	return m

func _metal_material(color: Color) -> StandardMaterial3D:
	var m := ProcGfx.make_noise_material(color, 0.35, 0.08, 5.0)
	m.metallic = 0.65
	m.metallic_specular = 0.6
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

	_audio_melee_hit = AudioStreamPlayer.new()
	_audio_melee_hit.stream = load("res://audio/knife_hit.wav")
	add_child(_audio_melee_hit)

func _process(delta: float) -> void:
	_update_muzzle_flash(delta)
	if active:
		_update_viewmodel_motion(delta)
		_update_ads(delta)

func _update_ads(delta: float) -> void:
	if not camera:
		return
	var target_fov := DEFAULT_FOV
	if stats.has_ads and not is_reloading and Input.is_action_pressed("ads"):
		target_fov = stats.ads_fov
	camera.fov = lerp(camera.fov, target_fov, clamp(delta * 10.0, 0.0, 1.0))

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

	if not active or is_reloading or GameState.is_dead:
		return

	if not stats.is_melee and Input.is_action_just_pressed("reload") and mag_ammo < stats.mag_size and reserve_ammo > 0:
		_start_reload()
		return

	var wants_fire: bool = Input.is_action_pressed("fire") if stats.automatic else Input.is_action_just_pressed("fire")
	if not wants_fire or _fire_cooldown > 0.0:
		if not Input.is_action_pressed("fire"):
			_empty_click_latch = false
		return

	if stats.is_melee:
		_fire()
		return

	if mag_ammo > 0:
		_fire()
		_empty_click_latch = false
	elif not _empty_click_latch:
		_audio_empty.play()
		_empty_click_latch = true
		if reserve_ammo > 0:
			_start_reload()

func _fire() -> void:
	_fire_cooldown = stats.fire_interval
	_time_since_last_shot = 0.0

	if stats.is_melee:
		_swing_t = 0.0
		GameState.register_shot()
		_raycast_shot(stats.spread_base_deg, stats.melee_range)
		_audio_fire.stop()
		_audio_fire.play()
		if player and player.has_method("add_shake"):
			player.add_shake(stats.shake_amount)
		return

	mag_ammo -= 1
	_recoil_kick = 1.0
	ammo_changed.emit(mag_ammo, reserve_ammo)

	var move_penalty := 0.0
	if player and player.has_method("get_horizontal_speed"):
		var ratio: float = clamp(player.get_horizontal_speed() / max(player.walk_speed, 0.01), 0.0, 1.0)
		move_penalty = ratio * stats.spread_move_penalty_deg
	var total_spread_deg: float = stats.spread_base_deg + _current_bloom + move_penalty
	if stats.has_ads and Input.is_action_pressed("ads"):
		total_spread_deg *= stats.ads_spread_mult
	_current_bloom = min(_current_bloom + stats.bloom_per_shot_deg, stats.bloom_max_deg)

	var recoil: Vector2 = stats.get_recoil(_shots_since_rest)
	if player and player.has_method("apply_recoil"):
		player.apply_recoil(recoil)
	if player and player.has_method("add_shake"):
		player.add_shake(stats.shake_amount)
	_shots_since_rest += 1

	GameState.register_shot()
	_raycast_shot(total_spread_deg, 1000.0)

	_muzzle_timer = MUZZLE_FLASH_TIME
	_audio_fire.stop()
	_audio_fire.play()
	_spawn_muzzle_spark()

func _raycast_shot(spread_deg: float, max_distance: float) -> void:
	if not camera:
		return
	var space_state := camera.get_world_3d().direct_space_state
	var forward: Vector3 = -camera.global_transform.basis.z
	var spread_dir: Vector3 = _apply_spread(forward, spread_deg)
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + spread_dir * max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b101
	var result := space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		if collider.is_in_group("target_head"):
			collider.get_parent().hit("head", stats.points_head, stats.damage_body)
			_spawn_blood(result.position, result.normal)
			if stats.is_melee:
				_audio_melee_hit.play()
		elif collider.is_in_group("target_body"):
			collider.get_parent().hit("body", stats.points_body, stats.damage_body)
			_spawn_blood(result.position, result.normal)
			if stats.is_melee:
				_audio_melee_hit.play()
		else:
			GameState.register_miss()
			_spawn_wall_impact(result.position, result.normal)
	else:
		GameState.register_miss()

func _spawn_muzzle_spark() -> void:
	var scene := get_tree().current_scene
	if not scene or not camera:
		return
	var muzzle_world: Vector3 = global_transform * Vector3(0, 0.015, -0.48)
	var forward: Vector3 = -camera.global_transform.basis.z
	ProcGfx.spawn_spark_burst(scene, muzzle_world, forward, stats.muzzle_color, 6)

func _spawn_wall_impact(position: Vector3, normal: Vector3) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	ProcGfx.spawn_spark_burst(scene, position, normal, Color(1.0, 0.75, 0.35), 8)
	ProcGfx.spawn_decal(scene, position, normal, _scorch_tex, Vector3(0.16, 0.06, 0.16))

func _spawn_blood(position: Vector3, normal: Vector3) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	ProcGfx.spawn_spark_burst(scene, position, normal, Color(0.55, 0.05, 0.05), 10)

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
	if _muzzle_mesh == null:
		return
	var mat := _muzzle_mesh.material_override as StandardMaterial3D
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
		var t: float = clamp(_muzzle_timer / MUZZLE_FLASH_TIME, 0.0, 1.0)
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

	_draw_t = min(_draw_t + delta / DRAW_TIME, 1.0)
	var draw_eased: float = 1.0 - pow(1.0 - _draw_t, 3.0)
	var draw_offset := Vector3(0.0, -(1.0 - draw_eased) * 0.5, (1.0 - draw_eased) * 0.15)

	var reload_offset := Vector3.ZERO
	var swing_offset := Vector3.ZERO

	if is_reloading and stats.reload_time > 0.0:
		var progress: float = 1.0 - clamp(_reload_timer / stats.reload_time, 0.0, 1.0)
		reload_offset.y = -sin(progress * PI) * RELOAD_DIP
		rotation.x = sin(progress * PI) * 0.35
		rotation.y = 0.0
	elif stats.is_melee:
		_swing_t = min(_swing_t + delta * 4.0, 1.0)
		var s: float = sin(_swing_t * PI) if _swing_t < 1.0 else 0.0
		swing_offset = Vector3(-s * 0.12, s * 0.05, -s * 0.18)
		rotation.x = -s * 0.5
		rotation.y = s * 0.6
	else:
		rotation.x = -_recoil_kick * 0.12
		rotation.y = 0.0

	position = _base_local_pos + bob_offset + kick_offset + draw_offset + reload_offset + swing_offset
