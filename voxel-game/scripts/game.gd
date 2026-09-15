extends Node3D
## Root script for the main scene: applies loaded-save state to Player and
## DayNightCycle once they've finished their own _ready() (World applies
## its own part of the save — the seed and terrain diff — earlier, inside
## its own _ready(), since that has to happen before its noise is set up).
## Also owns autosave and save-on-quit.

const AUTOSAVE_INTERVAL := 30.0

@onready var world: VoxelWorld = $World
@onready var player: VoxelPlayer = $Player
@onready var day_night: DayNightCycle = $DayNightCycle

var _autosave_timer: float = 0.0

func _ready() -> void:
	var save_data: Dictionary = SaveSystem.load_game()
	if not save_data.is_empty():
		_apply_save_data(save_data)

func _apply_save_data(data: Dictionary) -> void:
	if data.has("time_of_day"):
		day_night.time_of_day = float(data["time_of_day"])

	var player_data: Dictionary = data.get("player", {})
	if player_data.has("position"):
		var pos: Array = player_data["position"]
		var loaded_position := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		player.load_state(
			loaded_position,
			float(player_data.get("rotation_y", 0.0)),
			float(player_data.get("pitch", 0.0)),
			float(player_data.get("health", player.max_health)),
		)

	if data.has("inventory"):
		player.inventory.load_from_array(data["inventory"])

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		_save_now()

func _save_now() -> void:
	SaveSystem.save_game(world, player, day_night)

## Runs alongside World's own NOTIFICATION_WM_CLOSE_REQUEST handler (both
## get the same notification independently); this one is synchronous and
## finishes well before World's deferred quit() actually happens.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()
