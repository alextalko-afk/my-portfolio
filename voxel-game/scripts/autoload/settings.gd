extends Node
## Autoload singleton "Settings". Persistent player preferences, applied
## live: World/Player read these directly (or react to the signals below)
## instead of caching a copy at startup, so a change takes effect the
## moment it's made — no restart, no re-entering the world.

signal render_distance_changed(value: int)
signal fov_changed(value: float)
signal mouse_sensitivity_changed(value: float)

const SAVE_PATH := "user://settings.cfg"

const RENDER_DISTANCE_MIN := 2
const RENDER_DISTANCE_MAX := 8
const FOV_MIN := 50.0
const FOV_MAX := 100.0
const SENSITIVITY_MIN := 0.0005
const SENSITIVITY_MAX := 0.006

var render_distance: int = 4
var fov: float = 75.0
var mouse_sensitivity: float = 0.0025

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		render_distance = cfg.get_value("world", "render_distance", render_distance)
		fov = cfg.get_value("player", "fov", fov)
		mouse_sensitivity = cfg.get_value("player", "mouse_sensitivity", mouse_sensitivity)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("world", "render_distance", render_distance)
	cfg.set_value("player", "fov", fov)
	cfg.set_value("player", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(SAVE_PATH)

func set_render_distance(value: int) -> void:
	render_distance = clampi(value, RENDER_DISTANCE_MIN, RENDER_DISTANCE_MAX)
	save_settings()
	render_distance_changed.emit(render_distance)

func set_fov(value: float) -> void:
	fov = clampf(value, FOV_MIN, FOV_MAX)
	save_settings()
	fov_changed.emit(fov)

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	save_settings()
	mouse_sensitivity_changed.emit(mouse_sensitivity)
