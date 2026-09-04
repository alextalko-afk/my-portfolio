extends Control
## Built entirely in code -- see hud.gd for why. Backdrop is a small live
## SubViewport scene (one enemy rig, slowly turning) rather than a flat
## color, so the menu shows off the same procedural assets the game uses.

const EnemyScript := preload("res://scripts/world/enemy.gd")

var _display_enemy: Node3D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_backdrop()
	_build_ui()

func _process(delta: float) -> void:
	if _display_enemy:
		_display_enemy.rotation.y += delta * 0.35

func _build_backdrop() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	var svp := SubViewport.new()
	svp.size = Vector2i(1920, 1080)
	svp.transparent_bg = false
	svc.add_child(svp)

	var world := Node3D.new()
	svp.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.05, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.42, 0.48)
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, 20, 0)
	key_light.light_energy = 3.2
	key_light.light_color = Color(1.0, 0.9, 0.75)
	world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-15, 145, 0)
	rim_light.light_energy = 2.2
	rim_light.light_color = Color(0.4, 0.6, 1.0)
	rim_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	world.add_child(rim_light)

	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(6, 0.2, 6)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.07, 0.07, 0.08)
	floor_mat.roughness = 0.9
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0, -0.1, 0)
	world.add_child(floor_mesh)

	_display_enemy = EnemyScript.new()
	world.add_child(_display_enemy)
	_display_enemy.setup(EnemyScript.Faction.SPEC_OPS, [Vector3.ZERO], [], null)
	_display_enemy.rotation.y = 0.0

	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.current = true
	cam.look_at_from_position(Vector3(1.1, 1.15, 4.6), Vector3(0, 0.95, 0), Vector3.UP)
	world.add_child(cam)

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.03, 0.04, 0.35)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var side_panel_bg := StyleBoxFlat.new()
	side_panel_bg.bg_color = Color(0.05, 0.055, 0.07, 0.82)
	side_panel_bg.set_corner_radius_all(0)
	side_panel_bg.border_color = Color(0.8, 0.22, 0.16)
	side_panel_bg.set_border_width_all(0)
	side_panel_bg.border_width_right = 3
	side_panel_bg.set_content_margin_all(36)

	var side_panel := PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", side_panel_bg)
	side_panel.anchor_left = 0.0
	side_panel.anchor_top = 0.0
	side_panel.anchor_right = 0.0
	side_panel.anchor_bottom = 1.0
	side_panel.offset_left = 0.0
	side_panel.offset_top = 0.0
	side_panel.offset_right = 460.0
	side_panel.offset_bottom = 0.0
	side_panel.custom_minimum_size = Vector2(460, 0)
	add_child(side_panel)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side_panel.add_child(panel)

	var title := Label.new()
	title.text = "AIM RANGE"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	var accent := ColorRect.new()
	accent.color = Color(0.85, 0.22, 0.16)
	accent.custom_minimum_size = Vector2(120, 4)
	panel.add_child(accent)

	var subtitle := Label.new()
	subtitle.text = "Terrorists vs. Spec Ops -- single-player combat range"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	panel.add_child(subtitle)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 18)
	panel.add_child(spacer1)

	var play_btn := _make_button("PLAY", Color(0.82, 0.20, 0.15), Color(0.95, 0.30, 0.22), 22, 52)
	play_btn.pressed.connect(_on_play_pressed)
	panel.add_child(play_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	panel.add_child(spacer2)

	var sens_label := Label.new()
	sens_label.text = "MOUSE SENSITIVITY"
	sens_label.add_theme_font_size_override("font_size", 13)
	sens_label.add_theme_color_override("font_color", Color(0.6, 0.63, 0.68))
	panel.add_child(sens_label)

	var sens_slider := HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.008
	sens_slider.step = 0.0002
	sens_slider.value = Settings.mouse_sensitivity
	sens_slider.custom_minimum_size = Vector2(0, 24)
	sens_slider.value_changed.connect(_on_sensitivity_changed)
	panel.add_child(sens_slider)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	panel.add_child(spacer3)

	var quit_btn := _make_button("QUIT", Color(0.14, 0.15, 0.18), Color(0.24, 0.25, 0.28), 16, 40)
	quit_btn.pressed.connect(_on_quit_pressed)
	panel.add_child(quit_btn)

	var hint := Label.new()
	hint.text = "WASD Move   Mouse Look   LMB Fire   R Reload   1-5 Weapons   RMB Aim (Sniper)   T Timed Run"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 3)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-420, -34)
	hint.size = Vector2(840, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _make_button(label: String, bg: Color, border: Color, font_size: int, height: float) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96))

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = bg
	normal_sb.border_color = border
	normal_sb.set_border_width_all(2)
	normal_sb.set_corner_radius_all(3)
	normal_sb.set_content_margin_all(10)

	var hover_sb := normal_sb.duplicate()
	hover_sb.bg_color = bg.lightened(0.15)
	hover_sb.border_color = border.lightened(0.15)

	var pressed_sb := normal_sb.duplicate()
	pressed_sb.bg_color = bg.darkened(0.15)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", normal_sb)
	return btn

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/range.tscn")

func _on_sensitivity_changed(value: float) -> void:
	Settings.set_mouse_sensitivity(value)

func _on_quit_pressed() -> void:
	get_tree().quit()
