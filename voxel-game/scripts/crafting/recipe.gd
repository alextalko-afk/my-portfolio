class_name Recipe
extends Resource
## Shapeless crafting recipe: a bag of required items (by block name, since
## saves reference blocks by name too) and one output. Matching only cares
## about total quantities in the grid, not their arrangement.

@export var recipe_name: String = ""
@export var inputs: Dictionary = {}  # block_name(String) -> count(int)
@export var output_name: String = ""
@export var output_count: int = 1
@export var requires_workbench: bool = false

## True if `available` (block_name -> count) contains at least the
## quantities this recipe needs.
func is_satisfied_by(available: Dictionary) -> bool:
	for item_name in inputs:
		if int(available.get(item_name, 0)) < int(inputs[item_name]):
			return false
	return true
