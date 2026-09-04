extends RefCounted
## Factory functions for tuned WeaponStats instances. Kept out of
## weapon_stats.gd because a static factory referencing its own class_name
## by bare name fails to resolve before Godot has built its script class
## cache (i.e. the very first run, before the project is ever opened in
## the editor) -- preloading by path sidesteps that entirely.

const WeaponStatsScript := preload("res://scripts/weapon_stats.gd")

static func make_rifle():
	var s = WeaponStatsScript.new()
	s.weapon_name = "Rifle"
	s.automatic = true
	s.points_body = 10
	s.points_head = 15
	s.damage_body = 34
	s.fire_interval = 0.096
	s.mag_size = 30
	s.reserve_ammo = 90
	s.reload_time = 2.5
	s.spread_base_deg = 0.25
	s.spread_move_penalty_deg = 2.4
	s.bloom_per_shot_deg = 0.4
	s.bloom_max_deg = 5.0
	s.bloom_recovery_deg_per_sec = 7.0
	s.recoil_reset_time = 0.3
	s.recoil_vertical_deg = 1.7
	s.recoil_horizontal_deg = 1.0
	s.recoil_pattern_length = 24
	s.muzzle_color = Color(1.0, 0.78, 0.35)
	s.fire_sound_path = "res://audio/rifle_shot.wav"
	s.shake_amount = 0.14
	s._build_recoil_pattern()
	return s

static func make_pistol():
	var s = WeaponStatsScript.new()
	s.weapon_name = "Pistol"
	s.automatic = false
	s.points_body = 12
	s.points_head = 20
	s.damage_body = 24
	s.fire_interval = 0.17
	s.mag_size = 12
	s.reserve_ammo = 36
	s.reload_time = 1.8
	s.spread_base_deg = 0.4
	s.spread_move_penalty_deg = 2.0
	s.bloom_per_shot_deg = 0.5
	s.bloom_max_deg = 4.0
	s.bloom_recovery_deg_per_sec = 8.0
	s.recoil_reset_time = 0.35
	s.recoil_vertical_deg = 1.1
	s.recoil_horizontal_deg = 0.6
	s.recoil_pattern_length = 12
	s.muzzle_color = Color(1.0, 0.85, 0.5)
	s.fire_sound_path = "res://audio/pistol_shot.wav"
	s.shake_amount = 0.09
	s._build_recoil_pattern()
	return s

static func make_smg():
	var s = WeaponStatsScript.new()
	s.weapon_name = "SMG"
	s.automatic = true
	s.points_body = 8
	s.points_head = 13
	s.damage_body = 19
	s.fire_interval = 0.07
	s.mag_size = 35
	s.reserve_ammo = 105
	s.reload_time = 2.2
	s.spread_base_deg = 0.35
	s.spread_move_penalty_deg = 1.6
	s.bloom_per_shot_deg = 0.3
	s.bloom_max_deg = 4.5
	s.bloom_recovery_deg_per_sec = 8.0
	s.recoil_reset_time = 0.3
	s.recoil_vertical_deg = 1.3
	s.recoil_horizontal_deg = 1.3
	s.recoil_pattern_length = 20
	s.muzzle_color = Color(1.0, 0.7, 0.3)
	s.fire_sound_path = "res://audio/smg_shot.wav"
	s.shake_amount = 0.11
	s._build_recoil_pattern()
	return s

static func make_sniper():
	var s = WeaponStatsScript.new()
	s.weapon_name = "Sniper"
	s.automatic = false
	s.points_body = 40
	s.points_head = 60
	s.damage_body = 100
	s.fire_interval = 1.35
	s.mag_size = 5
	s.reserve_ammo = 20
	s.reload_time = 3.2
	s.spread_base_deg = 0.05
	s.spread_move_penalty_deg = 6.0
	s.bloom_per_shot_deg = 1.2
	s.bloom_max_deg = 6.0
	s.bloom_recovery_deg_per_sec = 10.0
	s.recoil_reset_time = 0.5
	s.recoil_vertical_deg = 4.0
	s.recoil_horizontal_deg = 1.0
	s.recoil_pattern_length = 5
	s.muzzle_color = Color(1.0, 0.6, 0.25)
	s.fire_sound_path = "res://audio/sniper_shot.wav"
	s.has_ads = true
	s.ads_fov = 25.0
	s.ads_spread_mult = 0.05
	s.shake_amount = 0.4
	s._build_recoil_pattern()
	return s

static func make_knife():
	var s = WeaponStatsScript.new()
	s.weapon_name = "Knife"
	s.automatic = false
	s.points_body = 25
	s.points_head = 35
	s.damage_body = 55
	s.fire_interval = 0.45
	s.mag_size = 1
	s.reserve_ammo = 0
	s.reload_time = 0.0
	s.spread_base_deg = 1.0
	s.spread_move_penalty_deg = 0.0
	s.bloom_per_shot_deg = 0.0
	s.bloom_max_deg = 0.0
	s.bloom_recovery_deg_per_sec = 0.0
	s.recoil_reset_time = 0.2
	s.recoil_vertical_deg = 0.0
	s.recoil_horizontal_deg = 0.0
	s.recoil_pattern_length = 1
	s.is_melee = true
	s.melee_range = 2.2
	s.fire_sound_path = "res://audio/knife_swing.wav"
	s.shake_amount = 0.06
	s._build_recoil_pattern()
	return s
