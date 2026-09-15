extends Node
## Autoload singleton "RecipeRegistry". All craftable recipes, registered
## as data (Recipe resources) rather than special-cased in game logic.

var recipes: Array[Recipe] = []

func _ready() -> void:
	_register_recipes()

func register_recipe(recipe: Recipe) -> void:
	recipes.append(recipe)

## Checks how much of an item the inventory holds and tries to craft the
## given recipe from it. Returns false (no state changed) if there isn't
## enough, or the recipe needs a workbench the player isn't at.
func craft(recipe: Recipe, inventory: Inventory, near_workbench: bool) -> bool:
	if recipe.requires_workbench and not near_workbench:
		return false
	for item_name in recipe.inputs:
		var block_id: int = BlockRegistry.get_id_by_name(item_name)
		if inventory.count_item(block_id) < int(recipe.inputs[item_name]):
			return false
	for item_name in recipe.inputs:
		var block_id: int = BlockRegistry.get_id_by_name(item_name)
		inventory.remove_item(block_id, int(recipe.inputs[item_name]))
	var output_id: int = BlockRegistry.get_id_by_name(recipe.output_name)
	inventory.add_item(output_id, recipe.output_count)
	return true

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
