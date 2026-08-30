extends Control
## Built entirely in code -- see hud.gd for why.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -150)
	panel.size = Vector2(320, 300)
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)

	var title := Label.new()
	title.text = "AIM RANGE"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.25, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "CS-style aim trainer"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	panel.add_child(spacer)

	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(0, 48)
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.pressed.connect(_on_play_pressed)
	panel.add_child(play_btn)

	var sens_label := Label.new()
	sens_label.text = "Mouse sensitivity"
	sens_label.add_theme_font_size_override("font_size", 14)
	sens_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))
	panel.add_child(sens_label)

	var sens_slider := HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.008
	sens_slider.step = 0.0002
	sens_slider.value = Settings.mouse_sensitivity
	sens_slider.custom_minimum_size = Vector2(0, 24)
	sens_slider.value_changed.connect(_on_sensitivity_changed)
	panel.add_child(sens_slider)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.custom_minimum_size = Vector2(0, 40)
	quit_btn.pressed.connect(_on_quit_pressed)
	panel.add_child(quit_btn)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/range.tscn")

func _on_sensitivity_changed(value: float) -> void:
	Settings.set_mouse_sensitivity(value)

func _on_quit_pressed() -> void:
	get_tree().quit()
