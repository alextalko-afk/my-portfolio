class_name DayNightCycle
extends Node
## Rotates the sun light and re-colors the sky over a full day/night cycle.
## Cave/interior darkening comes from the sun's real-time shadow mapping
## against chunk geometry (already enabled on the light), not a separate
## system — occluded spots stay dark regardless of time of day, and the
## ambient light level still falls at night so caves aren't lit by ambient
## alone once the sun goes down.

@export var cycle_seconds: float = 1200.0
@export var sun_path: NodePath
@export var environment_path: NodePath

## 0..1 across a full day; 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.
var time_of_day: float = 0.3

var _sun: DirectionalLight3D
var _world_environment: WorldEnvironment
var _sky_material: ProceduralSkyMaterial

const DAY_SKY_TOP := Color(0.29, 0.55, 0.86)
const DAY_SKY_HORIZON := Color(0.68, 0.82, 0.93)
const DUSK_SKY_TOP := Color(0.22, 0.2, 0.34)
const DUSK_SKY_HORIZON := Color(0.92, 0.55, 0.35)
const NIGHT_SKY_TOP := Color(0.02, 0.03, 0.08)
const NIGHT_SKY_HORIZON := Color(0.05, 0.07, 0.15)

const DAY_LIGHT_COLOR := Color(1.0, 0.98, 0.92)
const DUSK_LIGHT_COLOR := Color(1.0, 0.6, 0.35)
const NIGHT_LIGHT_COLOR := Color(0.4, 0.45, 0.65)

func _ready() -> void:
	if sun_path != NodePath():
		_sun = get_node(sun_path)
	if environment_path != NodePath():
		_world_environment = get_node(environment_path)
		_sky_material = _world_environment.environment.sky.sky_material
	_apply()

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / cycle_seconds, 1.0)
	_apply()

func is_night() -> bool:
	return get_sun_height() < -0.05

## 1.0 = sun directly overhead, 0.0 = on the horizon, negative = below it.
func get_sun_height() -> float:
	return sin(time_of_day * TAU - PI / 2.0)

func _apply() -> void:
	if _sun == null:
		return
	var angle: float = time_of_day * TAU - PI / 2.0
	_sun.rotation = Vector3(angle, deg_to_rad(-20.0), 0.0)

	var height: float = get_sun_height()
	var day_factor: float = clampf(height, 0.0, 1.0)
	var dusk_factor: float = clampf(1.0 - absf(height) * 3.0, 0.0, 1.0)
	var night_factor: float = clampf(-height, 0.0, 1.0)

	_sun.light_energy = lerpf(0.0, 1.15, day_factor)
	_sun.visible = height > -0.2
	_sun.light_color = DAY_LIGHT_COLOR.lerp(DUSK_LIGHT_COLOR, dusk_factor).lerp(NIGHT_LIGHT_COLOR, night_factor * 0.6)

	if _sky_material != null:
		var top: Color = DAY_SKY_TOP.lerp(DUSK_SKY_TOP, dusk_factor).lerp(NIGHT_SKY_TOP, night_factor)
		var horizon: Color = DAY_SKY_HORIZON.lerp(DUSK_SKY_HORIZON, dusk_factor).lerp(NIGHT_SKY_HORIZON, night_factor)
		_sky_material.sky_top_color = top
		_sky_material.sky_horizon_color = horizon

	if _world_environment != null:
		_world_environment.environment.ambient_light_energy = lerpf(0.15, 1.0, day_factor + dusk_factor * 0.3)
