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
var _hearts: Control
var _death_label: Label
var _hotbar_slots: Array = []
var _inventory_screen: Control
var _inventory_slots: Array = []
var _grid_slots: Array = []
var _output_slot: Panel
var _settings_screen: Control

func _ready() -> void:
	layer = 10
	_build_crosshair()
	_build_debug_label()
	_build_hearts()
	_build_death_label()
	_build_hotbar()
	_build_inventory_screen()
	_build_settings_screen()

func setup(player: VoxelPlayer) -> void:
	_player = player
	_player.inventory.changed.connect(_refresh_slots)
	_player.health_changed.connect(func(_c: float, _m: float) -> void: _hearts.queue_redraw())
	_player.died.connect(func() -> void: _death_label.visible = true)
	_player.respawned.connect(func() -> void: _death_label.visible = false; _hearts.queue_redraw())
	_refresh_slots()
	_refresh_hotbar_selection()
	_hearts.queue_redraw()

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
		_refresh_crafting_grid()

func toggle_inventory() -> void:
	_inventory_screen.visible = not _inventory_screen.visible

func is_inventory_open() -> bool:
	return _inventory_screen.visible

func toggle_settings() -> void:
	_settings_screen.visible = not _settings_screen.visible

func is_settings_open() -> bool:
	return _settings_screen.visible

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

const HEART_SIZE := 18
const HEART_SEP := 4
const HEART_POINTS := [
	Vector2(9, 3.4), Vector2(6.8, 0), Vector2(3.4, 0), Vector2(0, 3.4), Vector2(0, 6.8),
	Vector2(9, 17), Vector2(18, 6.8), Vector2(18, 3.4), Vector2(14.6, 0), Vector2(11.2, 0),
]

func _build_hearts() -> void:
	_hearts = Control.new()
	_hearts.anchor_left = 0.5
	_hearts.anchor_right = 0.5
	_hearts.anchor_top = 1.0
	_hearts.anchor_bottom = 1.0
	_hearts.offset_top = -(SLOT_SIZE + 20 + 8 + HEART_SIZE)
	_hearts.offset_bottom = -(SLOT_SIZE + 20 + 8)
	_hearts.offset_left = -110
	_hearts.offset_right = 110
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts.draw.connect(_draw_hearts)
	add_child(_hearts)

func _draw_hearts() -> void:
	if _player == null:
		return
	var max_hearts: int = int(ceil(_player.max_health / 2.0))
	var current_hearts: float = _player.health / 2.0
	var empty_color := Color(0.18, 0.18, 0.18, 0.9)
	var full_color := Color(0.82, 0.12, 0.12)
	for i in range(max_hearts):
		var fill: float = clampf(current_hearts - float(i), 0.0, 1.0)
		var color: Color = empty_color.lerp(full_color, fill)
		var offset := Vector2(i * (HEART_SIZE + HEART_SEP), 0)
		var pts := PackedVector2Array()
		for p in HEART_POINTS:
			pts.append(p + offset)
		_hearts.draw_colored_polygon(pts, color)

func _build_death_label() -> void:
	_death_label = Label.new()
	_death_label.text = "You died"
	_death_label.add_theme_font_size_override("font_size", 32)
	_death_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.visible = false
	add_child(_death_label)

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
		_connect_secondary_click(slot.get_node("Button"), _add_inventory_item_to_grid.bind(i))
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
		_connect_secondary_click(button, _add_inventory_item_to_grid.bind(i))
		grid.add_child(slot)
		_inventory_slots.append(slot)

	_build_crafting_grid_panel(row, craft_panel_width, grid_height)

	add_child(_inventory_screen)

## A real 3x3 crafting grid (2x2 active without a workbench nearby, full
## 3x3 with one — the other 5 slots are visibly locked). Right-click a
## hotbar/inventory slot to send one item into the grid; left-click a
## filled grid slot to take it back; left-click the output slot to craft.
func _build_crafting_grid_panel(parent: Control, panel_width: int, panel_height: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	parent.add_child(panel)

	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(outer)

	var hint := Label.new()
	hint.text = "Right-click to add, left-click to take back"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	outer.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	outer.add_child(row)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", SLOT_SEP)
	grid.add_theme_constant_override("v_separation", SLOT_SEP)
	row.add_child(grid)

	for i in range(CraftingGrid.SIZE):
		var slot: Panel = _make_slot_panel()
		var button: Button = slot.get_node("Button")
		button.pressed.connect(_on_grid_slot_pressed.bind(i))
		grid.add_child(slot)
		_grid_slots.append(slot)

	var arrow := Label.new()
	arrow.text = "->"
	row.add_child(arrow)

	_output_slot = _make_slot_panel()
	var output_button: Button = _output_slot.get_node("Button")
	output_button.pressed.connect(_on_output_pressed)
	row.add_child(_output_slot)

## Render distance, FOV, mouse sensitivity — each a slider wired straight
## to Settings.set_*(), which applies immediately and persists to disk.
## No "Apply" button: the whole point of this stage is that it's live.
func _build_settings_screen() -> void:
	_settings_screen = Control.new()
	_settings_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_screen.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	_settings_screen.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -90
	panel.offset_bottom = 90
	_settings_screen.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	panel.add_child(list)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)

	_add_settings_row(list, "Render distance", Settings.RENDER_DISTANCE_MIN, Settings.RENDER_DISTANCE_MAX, 1.0, Settings.render_distance,
		func(v: float) -> void: Settings.set_render_distance(int(v)),
		func(v: float) -> String: return str(int(v)))
	_add_settings_row(list, "FOV", Settings.FOV_MIN, Settings.FOV_MAX, 1.0, Settings.fov,
		func(v: float) -> void: Settings.set_fov(v),
		func(v: float) -> String: return "%d" % int(v))
	_add_settings_row(list, "Mouse sensitivity", Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX, 0.0001, Settings.mouse_sensitivity,
		func(v: float) -> void: Settings.set_mouse_sensitivity(v),
		func(v: float) -> String: return "%.4f" % v)

	add_child(_settings_screen)

func _add_settings_row(parent: Control, label_text: String, min_value: float, max_value: float, step: float, initial: float, on_change: Callable, format_value: Callable) -> void:
	var row := VBoxContainer.new()

	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var value_label := Label.new()
	value_label.text = format_value.call(initial)
	header.add_child(value_label)
	row.add_child(header)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(300, 0)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = format_value.call(v)
		on_change.call(v)
	)
	row.add_child(slider)

	parent.add_child(row)

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

func _world_near_workbench() -> bool:
	if _player == null:
		return false
	var world: VoxelWorld = _player.get_world()
	if world == null:
		return false
	return world.is_near_workbench(_player.global_position, 4.0)

func _active_grid_indices() -> Array:
	return CraftingGrid.ACTIVE_3X3 if _world_near_workbench() else CraftingGrid.ACTIVE_2X2

## Right-click handler for a hotbar/inventory slot: moves one item from
## that inventory slot into the first active grid slot that will take it
## (an empty one, or one already holding the same item and not full).
func _add_inventory_item_to_grid(inventory_index: int) -> void:
	if _player == null:
		return
	var data: Dictionary = _player.inventory.get_slot(inventory_index)
	if data["id"] == BlockRegistry.AIR_ID or data["count"] <= 0:
		return
	for i in _active_grid_indices():
		if _player.crafting_grid.add_one(i, data["id"]):
			_player.inventory.remove_from_slot(inventory_index, 1)
			return

func _on_grid_slot_pressed(index: int) -> void:
	if _player == null:
		return
	var grid: CraftingGrid = _player.crafting_grid
	var data: Dictionary = grid.get_slot(index)
	if data["id"] == BlockRegistry.AIR_ID or data["count"] <= 0:
		return
	var leftover: int = _player.inventory.add_item(data["id"], data["count"])
	grid.slots[index] = {"id": data["id"] if leftover > 0 else BlockRegistry.AIR_ID, "count": leftover}
	grid.changed.emit()

func _on_output_pressed() -> void:
	if _player == null:
		return
	var near_bench: bool = _world_near_workbench()
	var active: Array = _active_grid_indices()
	var recipe: Recipe = RecipeRegistry.find_match(_player.crafting_grid, active, near_bench)
	if recipe == null:
		return
	RecipeRegistry.craft_from_grid(recipe, _player.crafting_grid, active, _player.inventory)

func _refresh_crafting_grid() -> void:
	if _player == null:
		return
	var near_bench: bool = _world_near_workbench()
	var active: Array = _active_grid_indices()
	for i in range(CraftingGrid.SIZE):
		_apply_slot_display(_grid_slots[i], _player.crafting_grid.get_slot(i))
		var is_active: bool = i in active
		_grid_slots[i].modulate = Color(1, 1, 1, 1) if is_active else Color(1, 1, 1, 0.35)
		_grid_slots[i].get_node("Button").disabled = not is_active

	var recipe: Recipe = RecipeRegistry.find_match(_player.crafting_grid, active, near_bench)
	if recipe != null:
		var output_id: int = BlockRegistry.get_id_by_name(recipe.output_name)
		_apply_slot_display(_output_slot, {"id": output_id, "count": recipe.output_count})
	else:
		_apply_slot_display(_output_slot, {"id": BlockRegistry.AIR_ID, "count": 0})

func _connect_secondary_click(button: Button, callback: Callable) -> void:
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			callback.call()
	)

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
