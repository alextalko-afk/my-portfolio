extends Node
## Autoload singleton "RecipeRegistry". All craftable recipes, registered
## as data (Recipe resources) rather than special-cased in game logic.

var recipes: Array[Recipe] = []

func _ready() -> void:
	_register_recipes()

func register_recipe(recipe: Recipe) -> void:
	recipes.append(recipe)

## Finds the (single) recipe whose ingredients exactly match what's sitting
## in the grid's active slots: every ingredient present in at least the
## required amount, and nothing else in an active slot that the recipe
## doesn't call for (an unrelated item in the grid blocks a match, same as
## vanilla — it isn't just ignored and silently consumed).
func find_match(grid: CraftingGrid, active_indices: Array, near_workbench: bool) -> Recipe:
	var totals: Dictionary = grid.get_active_totals_by_name(active_indices)
	if totals.is_empty():
		return null
	for recipe in recipes:
		if recipe.requires_workbench and not near_workbench:
			continue
		var has_extra_item := false
		for item_name in totals:
			if not recipe.inputs.has(item_name):
				has_extra_item = true
				break
		if has_extra_item:
			continue
		if recipe.is_satisfied_by(totals):
			return recipe
	return null

## Consumes the matched recipe's ingredients from the grid and adds the
## output to the inventory. Caller must already hold a match from
## find_match — this doesn't re-check requires_workbench.
func craft_from_grid(recipe: Recipe, grid: CraftingGrid, active_indices: Array, inventory: Inventory) -> void:
	grid.consume(active_indices, recipe.inputs)
	var output_id: int = BlockRegistry.get_id_by_name(recipe.output_name)
	inventory.add_item(output_id, recipe.output_count)

func _register_recipes() -> void:
	var planks := Recipe.new()
	planks.recipe_name = "Planks"
	planks.inputs = {"wood": 1}
	planks.output_name = "planks"
	planks.output_count = 4
	register_recipe(planks)

	var stick := Recipe.new()
	stick.recipe_name = "Stick"
	stick.inputs = {"planks": 2}
	stick.output_name = "stick"
	stick.output_count = 4
	register_recipe(stick)

	var workbench := Recipe.new()
	workbench.recipe_name = "Workbench"
	workbench.inputs = {"planks": 4}
	workbench.output_name = "workbench"
	workbench.output_count = 1
	register_recipe(workbench)

	var wooden_pickaxe := Recipe.new()
	wooden_pickaxe.recipe_name = "Wooden Pickaxe"
	wooden_pickaxe.inputs = {"planks": 3, "stick": 2}
	wooden_pickaxe.output_name = "wooden_pickaxe"
	wooden_pickaxe.output_count = 1
	wooden_pickaxe.requires_workbench = true
	register_recipe(wooden_pickaxe)

	var wooden_axe := Recipe.new()
	wooden_axe.recipe_name = "Wooden Axe"
	wooden_axe.inputs = {"planks": 3, "stick": 2}
	wooden_axe.output_name = "wooden_axe"
	wooden_axe.output_count = 1
	wooden_axe.requires_workbench = true
	register_recipe(wooden_axe)

	var wooden_sword := Recipe.new()
	wooden_sword.recipe_name = "Wooden Sword"
	wooden_sword.inputs = {"planks": 2, "stick": 1}
	wooden_sword.output_name = "wooden_sword"
	wooden_sword.output_count = 1
	wooden_sword.requires_workbench = true
	register_recipe(wooden_sword)

	var stone_pickaxe := Recipe.new()
	stone_pickaxe.recipe_name = "Stone Pickaxe"
	stone_pickaxe.inputs = {"cobblestone": 3, "stick": 2}
	stone_pickaxe.output_name = "stone_pickaxe"
	stone_pickaxe.output_count = 1
	stone_pickaxe.requires_workbench = true
	register_recipe(stone_pickaxe)
