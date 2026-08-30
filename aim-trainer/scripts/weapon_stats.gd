class_name WeaponStats
extends Resource
## Data-only weapon tuning. Recoil pattern is generated deterministically
## (same seed every spray) so it can be learned and countered, like a real
## weapon's spray pattern -- without copying any specific game's exact values.

@export var weapon_name: String = "Weapon"
@export var automatic: bool = true

@export var points_body: int = 10
@export var points_head: int = 15

@export var fire_interval: float = 0.1
@export var mag_size: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.5

@export var spread_base_deg: float = 0.3
@export var spread_move_penalty_deg: float = 2.2
@export var bloom_per_shot_deg: float = 0.35
@export var bloom_max_deg: float = 4.5
@export var bloom_recovery_deg_per_sec: float = 6.0

@export var recoil_reset_time: float = 0.3
@export var recoil_vertical_deg: float = 1.6
@export var recoil_horizontal_deg: float = 0.9
@export var recoil_pattern_length: int = 20

@export var muzzle_color: Color = Color(1.0, 0.75, 0.35)
@export var fire_sound_path: String = "res://audio/rifle_shot.wav"

var recoil_pattern: Array = []

func _init() -> void:
	_build_recoil_pattern()

func _build_recoil_pattern() -> void:
	recoil_pattern.clear()
	for i in range(recoil_pattern_length):
		var t := float(i) / float(max(recoil_pattern_length - 1, 1))
		var vertical := recoil_vertical_deg * (0.5 + 0.5 * t)
		var horizontal := recoil_horizontal_deg * sin(t * TAU * 1.6 + 0.4) * (0.4 + 0.9 * t)
		recoil_pattern.append(Vector2(vertical, horizontal))

func get_recoil(shot_index: int) -> Vector2:
	if recoil_pattern.is_empty():
		return Vector2.ZERO
	return recoil_pattern[min(shot_index, recoil_pattern.size() - 1)]

