class_name Inventory
extends RefCounted
## 36-slot inventory: slots 0-8 are the hotbar, 9-35 are the 3 extra rows
## shown in the full inventory screen. Each slot is {"id": int, "count": int}.

signal changed

const SLOT_COUNT := 36
const HOTBAR_SIZE := 9
const MAX_STACK := 64

var slots: Array = []

func _init() -> void:
	slots.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		slots[i] = {"id": BlockRegistry.AIR_ID, "count": 0}

func get_slot(index: int) -> Dictionary:
	return slots[index]

## Blocks are saved by name, not id — ids are just BlockRegistry
## registration order, which a future block addition could reshuffle and
## silently corrupt an old save.
func to_save_array() -> Array:
	var result: Array = []
	for slot in slots:
		var block: BlockType = BlockRegistry.get_block(slot["id"])
		var block_name: String = block.block_name if block != null else "air"
		result.append({"id": block_name, "count": slot["count"]})
	return result

func load_from_array(data: Array) -> void:
	for i in range(mini(data.size(), SLOT_COUNT)):
		var entry: Dictionary = data[i]
		var block_id: int = BlockRegistry.get_id_by_name(str(entry.get("id", "air")))
		slots[i] = {"id": block_id, "count": int(entry.get("count", 0))}
	changed.emit()

## Adds up to count of block_id, filling existing stacks first, then empty
## slots. Returns the amount that didn't fit.
func add_item(block_id: int, count: int) -> int:
	if block_id == BlockRegistry.AIR_ID or count <= 0:
		return count
	var remaining: int = count
	for i in range(SLOT_COUNT):
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i]
		if slot["id"] == block_id and slot["count"] < MAX_STACK:
			var space: int = MAX_STACK - int(slot["count"])
			var add: int = mini(space, remaining)
			slot["count"] = int(slot["count"]) + add
			remaining -= add
	for i in range(SLOT_COUNT):
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i]
		if slot["id"] == BlockRegistry.AIR_ID:
			var add: int = mini(MAX_STACK, remaining)
			slot["id"] = block_id
			slot["count"] = add
			remaining -= add
	changed.emit()
	return remaining

func remove_from_slot(index: int, count: int) -> void:
	var slot: Dictionary = slots[index]
	slot["count"] = maxi(0, int(slot["count"]) - count)
	if slot["count"] == 0:
		slot["id"] = BlockRegistry.AIR_ID
	changed.emit()

func set_slot(index: int, block_id: int, count: int) -> void:
	slots[index] = {"id": block_id, "count": count}
	changed.emit()

func swap_slots(a: int, b: int) -> void:
	if a == b:
		return
	var tmp: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	changed.emit()

func count_item(block_id: int) -> int:
	var total: int = 0
	for slot in slots:
		if slot["id"] == block_id:
			total += int(slot["count"])
	return total

## Removes count total of block_id across however many slots it takes.
## Returns false (and removes nothing) if there isn't enough.
func remove_item(block_id: int, count: int) -> bool:
	if count_item(block_id) < count:
		return false
	var remaining: int = count
	for slot in slots:
		if remaining <= 0:
			break
		if slot["id"] == block_id:
			var take: int = mini(int(slot["count"]), remaining)
			slot["count"] = int(slot["count"]) - take
			remaining -= take
			if slot["count"] == 0:
				slot["id"] = BlockRegistry.AIR_ID
	changed.emit()
	return true
