extends Node
## Autoload singleton "SaveSystem". Saves/loads the whole game state as one
## JSON file. Blocks are always referenced by name (never a raw id) in the
## save, in both the inventory and the world diff, so a later BlockRegistry
## change can't silently corrupt an existing save.

const SAVE_PATH := "user://savegame.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

## Only the diff from generated terrain is written (World.
## get_modifications_for_save), never the whole world — the rest
## regenerates identically from world_seed on load.
func save_game(world: VoxelWorld, player: VoxelPlayer, day_night: DayNightCycle) -> void:
	var data: Dictionary = {
		"world_seed": world.world_seed,
		"time_of_day": day_night.time_of_day,
		"player": {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"rotation_y": player.rotation.y,
			"pitch": player.pitch,
			"health": player.health,
		},
		"inventory": player.inventory.to_save_array(),
		"modified_blocks": world.get_modifications_for_save(),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: could not open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))
	file.close()
