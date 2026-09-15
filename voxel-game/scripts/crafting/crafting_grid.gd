class_name CraftingGrid
extends RefCounted
## A real 3x3 grid of crafting slots (row-major index = row*3+col). Without
## a workbench nearby, only the top-left 2x2 (indices 0,1,3,4) is active;
## the other 5 slots are visually locked by the HUD but keep whatever was
## in them if the player walks away from a workbench mid-craft.

signal changed

const SIZE := 9
const ACTIVE_2X2 := [0, 1, 3, 4]
const ACTIVE_3X3 := [0, 1, 2, 3, 4, 5, 6, 7, 8]

var slots: Array = []

func _init() -> void:
	slots.resize(SIZE)
	for i in range(SIZE):
		slots[i] = {"id": BlockRegistry.AIR_ID, "count": 0}

func get_slot(index: int) -> Dictionary:
	return slots[index]

## Adds one item of block_id into slot i (stacking if it already matches).
## Returns false if the slot holds something else and is full.
func add_one(index: int, block_id: int) -> bool:
	var slot: Dictionary = slots[index]
	if slot["id"] == BlockRegistry.AIR_ID:
		slot["id"] = block_id
		slot["count"] = 1
		changed.emit()
		return true
	if slot["id"] == block_id and slot["count"] < Inventory.MAX_STACK:
		slot["count"] += 1
		changed.emit()
		return true
	return false

## Empties slot i and returns what was in it (for handing back to the
## inventory when the player reclaims it).
func take_slot(index: int) -> Dictionary:
	var result: Dictionary = slots[index].duplicate()
	slots[index] = {"id": BlockRegistry.AIR_ID, "count": 0}
	changed.emit()
	return result

## Totals by block name across only the currently active slots — a
## non-empty slot outside the active set doesn't count, so it can't
## secretly satisfy or block a recipe match.
func get_active_totals_by_name(active_indices: Array) -> Dictionary:
	var totals: Dictionary = {}
	for i in active_indices:
		var slot: Dictionary = slots[i]
		if slot["id"] == BlockRegistry.AIR_ID:
			continue
		var block: BlockType = BlockRegistry.get_block(slot["id"])
		var block_name: String = block.block_name if block != null else "air"
		totals[block_name] = int(totals.get(block_name, 0)) + int(slot["count"])
	return totals

## Deducts `requirements` (block_name -> count) from the active slots,
## spreading the deduction across however many slots hold that item.
func consume(active_indices: Array, requirements: Dictionary) -> void:
	var remaining: Dictionary = requirements.duplicate()
	for i in active_indices:
		var slot: Dictionary = slots[i]
		if slot["id"] == BlockRegistry.AIR_ID:
			continue
		var block: BlockType = BlockRegistry.get_block(slot["id"])
		var block_name: String = block.block_name if block != null else "air"
		if int(remaining.get(block_name, 0)) <= 0:
			continue
		var take: int = mini(int(slot["count"]), int(remaining[block_name]))
		slot["count"] = int(slot["count"]) - take
		remaining[block_name] = int(remaining[block_name]) - take
		if slot["count"] <= 0:
			slots[i] = {"id": BlockRegistry.AIR_ID, "count": 0}
	changed.emit()
