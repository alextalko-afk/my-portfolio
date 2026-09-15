class_name Hud
extends CanvasLayer
## Builds the whole HUD in code: crosshair, hotbar, debug readout, and the
## full inventory screen. No scene file needed — every Control here is
## simple enough that hand-authoring a .tscn would just be more places to
## typo an anchor.

const SLOT_SIZE := 48
const SLOT_SEP := 4
const HOTBAR_COUNT := 9
const INVENTORY_COLS := 9
const INVENTORY_ROWS := 4

var _player: VoxelPlayer

var _crosshair: Control
var _debug_label: Label
var _hotbar_slots: Array = []
var _inventory_screen: Control
var _inventory_slots: Array = []
var _craft_rows: Array = []  # [{recipe, button, label}]

func _ready() -> void:
	layer = 10
	_build_crosshair()
	_build_debug_label()
	_build_hotbar()
	_build_inventory_screen()

func setup(player: VoxelPlayer) -> void:
	_player = player
	_player.inventory.changed.connect(_refresh_slots)
	_refresh_slots()
	_refresh_hotbar_selection()

func _process(_delta: float) -> void:
	if _player == null:
		return
	_debug_label.text = "FPS: %d\nXYZ: %.1f, %.1f, %.1f\nSlot: %d" % [
		Engine.get_frames_per_second(),
		_player.global_position.x, _player.global_position.y, _player.global_position.z,
		_player.selected_slot + 1,
	]
	_refresh_hotbar_selection()
	if _inventory_screen.visible:
		_refresh_crafting()

func toggle_inventory() -> void:
	_inventory_screen.visible = not _inventory_screen.visible

func is_inventory_open() -> bool:
	return _inventory_screen.visible

func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		var center: Vector2 = _crosshair.size / 2.0
		var half: float = 6.0
		_crosshair.draw_line(center + Vector2(-half, 0), center + Vector2(half, 0), Color.WHITE, 2.0)
		_crosshair.draw_line(center + Vector2(0, -half), center + Vector2(0, half), Color.WHITE, 2.0)
	)
	add_child(_crosshair)

func _build_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 12)
	_debug_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_debug_label.add_theme_constant_override("shadow_offset_x", 1)
	_debug_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_debug_label)

func _build_hotbar() -> void:
	var width: int = HOTBAR_COUNT * SLOT_SIZE + (HOTBAR_COUNT - 1) * SLOT_SEP
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -width / 2.0
	root.offset_right = width / 2.0
	root.offset_top = -(SLOT_SIZE + 20)
	root.offset_bottom = -20
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", SLOT_SEP)
	root.add_child(box)

	for i in range(HOTBAR_COUNT):
		var slot: Panel = _make_slot_panel()
		box.add_child(slot)
		_hotbar_slots.append(slot)

func _build_inventory_screen() -> void:
	_inventory_screen = Control.new()
	_inventory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_screen.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	_inventory_screen.add_child(dim)

	var grid_width: int = INVENTORY_COLS * SLOT_SIZE + (INVENTORY_COLS - 1) * SLOT_SEP
	var grid_height: int = INVENTORY_ROWS * SLOT_SIZE + (INVENTORY_ROWS - 1) * SLOT_SEP
	var craft_panel_width: int = 260

	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_left = -(grid_width + craft_panel_width + 24) / 2.0
	row.offset_right = (grid_width + craft_panel_width + 24) / 2.0
	row.offset_top = -grid_height / 2.0 - 12
	row.offset_bottom = grid_height / 2.0 + 12
	row.add_theme_constant_override("separation", 24)
	_inventory_screen.add_child(row)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(grid_width + 24, grid_height + 24)
	row.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = INVENTORY_COLS
	grid.add_theme_constant_override("h_separation", SLOT_SEP)
	grid.add_theme_constant_override("v_separation", SLOT_SEP)
	panel.add_child(grid)

	for i in range(INVENTORY_COLS * INVENTORY_ROWS):
		var slot: Panel = _make_slot_panel()
		var button: Button = slot.get_node("Button")
		button.pressed.connect(_on_inventory_slot_pressed.bind(i))
		grid.add_child(slot)
		_inventory_slots.append(slot)

	_build_crafting_panel(row, craft_panel_width, grid_height)

	add_child(_inventory_screen)

## Recipes listed as rows (shapeless: quantities only, no grid shape) — a
## crafting grid's actual positions don't matter for matching, so a list
## covers the same functionality with much simpler, more robust UI.
func _build_crafting_panel(parent: Control, panel_width: int, panel_height: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	parent.add_child(panel)

	var scroll := ScrollContainer.new()
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for recipe in RecipeRegistry.recipes:
		var recipe_row := HBoxContainer.new()

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture = BlockRegistry.get_icon_texture(BlockRegistry.get_id_by_name(recipe.output_name))
		recipe_row.add_child(icon)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_row.add_child(label)

		var craft_button := Button.new()
		craft_button.text = "Craft"
		craft_button.focus_mode = Control.FOCUS_NONE
		craft_button.pressed.connect(_on_craft_pressed.bind(recipe))
		recipe_row.add_child(craft_button)

		list.add_child(recipe_row)
		_craft_rows.append({"recipe": recipe, "button": craft_button, "label": label})

func _make_slot_panel() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var button := Button.new()
	button.name = "Button"
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE
	panel.add_child(button)

	var count_label := Label.new()
	count_label.name = "Count"
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(count_label)

	return panel

func _on_inventory_slot_pressed(index: int) -> void:
	if _player == null:
		return
	_player.inventory.swap_slots(index, _player.selected_slot)

func _on_craft_pressed(recipe: Recipe) -> void:
	if _player == null:
		return
	var near_bench: bool = _world_near_workbench()
	RecipeRegistry.craft(recipe, _player.inventory, near_bench)

func _world_near_workbench() -> bool:
	if _player == null:
		return false
	var world: VoxelWorld = _player.get_world()
	if world == null:
		return false
	return world.is_near_workbench(_player.global_position, 4.0)

func _refresh_crafting() -> void:
	if _player == null:
		return
	var near_bench: bool = _world_near_workbench()
	for row in _craft_rows:
		var recipe: Recipe = row["recipe"]
		var button: Button = row["button"]
		var label: Label = row["label"]
		var available := Dictionary()
		for item_name in recipe.inputs:
			available[item_name] = _player.inventory.count_item(BlockRegistry.get_id_by_name(item_name))
		var have_materials: bool = recipe.is_satisfied_by(available)
		var have_bench: bool = (not recipe.requires_workbench) or near_bench
		button.disabled = not (have_materials and have_bench)

		var parts: PackedStringArray = []
		for item_name in recipe.inputs:
			parts.append("%s x%d" % [item_name, int(recipe.inputs[item_name])])
		var suffix: String = " (workbench)" if recipe.requires_workbench else ""
		label.text = "%s -> %d%s\n%s" % [recipe.recipe_name, recipe.output_count, suffix, ", ".join(parts)]

func _refresh_slots() -> void:
	if _player == null:
		return
	for i in range(_hotbar_slots.size()):
		_apply_slot_display(_hotbar_slots[i], _player.inventory.get_slot(i))
	for i in range(_inventory_slots.size()):
		_apply_slot_display(_inventory_slots[i], _player.inventory.get_slot(i))

func _apply_slot_display(slot_panel: Panel, data: Dictionary) -> void:
	var button: Button = slot_panel.get_node("Button")
	var count_label: Label = slot_panel.get_node("Count")
	var id: int = data["id"]
	var count: int = data["count"]
	if id == BlockRegistry.AIR_ID or count <= 0:
		button.icon = null
		count_label.text = ""
	else:
		button.icon = BlockRegistry.get_icon_texture(id)
		count_label.text = str(count) if count > 1 else ""

func _refresh_hotbar_selection() -> void:
	if _player == null:
		return
	for i in range(_hotbar_slots.size()):
		var panel: Panel = _hotbar_slots[i]
		panel.self_modulate = Color(1.4, 1.4, 1.0) if i == _player.selected_slot else Color(1, 1, 1)
