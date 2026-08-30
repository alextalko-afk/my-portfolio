extends Node
## Persistent player preferences (autoload singleton "Settings").

const SAVE_PATH := "user://settings.cfg"

var mouse_sensitivity: float = 0.0025
var master_volume: float = 0.8

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		mouse_sensitivity = cfg.get_value("player", "mouse_sensitivity", mouse_sensitivity)
		master_volume = cfg.get_value("audio", "master_volume", master_volume)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(SAVE_PATH)

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	save_settings()

func set_master_volume(value: float) -> void:
	master_volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(clamp(value, 0.001, 1.0)))
	save_settings()
