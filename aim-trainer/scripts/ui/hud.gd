extends CanvasLayer
## In-range HUD: dynamic crosshair, ammo, live stats, 60s run timer, hit marker.
## Built entirely in code so no .tscn node tree has to be hand-authored.

const CrosshairScript := preload("res://scripts/ui/crosshair.gd")
const HitMarkerScript := preload("res://scripts/ui/hitmarker.gd")

const HEALTH_BAR_WIDTH := 220.0
const HEALTH_BAR_HEIGHT := 18.0

var player: Node = null

var _crosshair: Control
var _hitmarker: Control
var _ammo_label: Label
var _weapon_name_label: Label
var _reload_label: Label
var _stats_label: Label
var _timer_label: Label
var _hint_label: Label
var _result_label: Label
var _health_bar_bg: ColorRect
var _health_bar_fg: ColorRect
var _health_label: Label
var _damage_flash: ColorRect
var _death_label: Label
var _damage_flash_t: float = 0.0

func _ready() -> void:
	layer = 5
	_build_ui()
	GameState.target_hit.connect(_on_target_hit)
	GameState.run_started.connect(_on_run_started)
	GameState.run_finished.connect(_on_run_finished)
	GameState.player_damaged.connect(_on_player_damaged)
	GameState.player_died.connect(_on_player_died)
	GameState.player_respawned.connect(_on_player_respawned)

func set_player(p: Node) -> void:
	player = p

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = CrosshairScript.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_crosshair)

	_hitmarker = HitMarkerScript.new()
	_hitmarker.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_hitmarker)

	_ammo_label = _make_label(22, Color.WHITE)
	_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.position = Vector2(-190, -60)
	_ammo_label.size = Vector2(170, 40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_ammo_label)

	_reload_label = _make_label(16, Color(1.0, 0.8, 0.3))
	_reload_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_reload_label.position = Vector2(-190, -84)
	_reload_label.size = Vector2(170, 24)
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_reload_label)

	_weapon_name_label = _make_label(15, Color(0.85, 0.85, 0.92))
	_weapon_name_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon_name_label.position = Vector2(-190, -106)
	_weapon_name_label.size = Vector2(170, 22)
	_weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_weapon_name_label)

	_health_bar_bg = ColorRect.new()
	_health_bar_bg.color = Color(0.08, 0.08, 0.08, 0.75)
	_health_bar_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_bar_bg.position = Vector2(20, -46)
	_health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_health_bar_bg)

	_health_bar_fg = ColorRect.new()
	_health_bar_fg.color = Color(0.25, 0.85, 0.35)
	_health_bar_fg.position = Vector2(2, 2)
	_health_bar_fg.size = Vector2(HEALTH_BAR_WIDTH - 4, HEALTH_BAR_HEIGHT - 4)
	_health_bar_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar_bg.add_child(_health_bar_fg)

	_health_label = _make_label(14, Color.WHITE)
	_health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_label.position = Vector2(20, -68)
	_health_label.size = Vector2(HEALTH_BAR_WIDTH, 18)
	root.add_child(_health_label)

	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_flash)

	_death_label = _make_label(30, Color(0.95, 0.2, 0.2))
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.position = Vector2(-220, -20)
	_death_label.size = Vector2(440, 40)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_death_label)

	_stats_label = _make_label(18, Color.WHITE)
	_stats_label.position = Vector2(20, 20)
	_stats_label.size = Vector2(320, 90)
	root.add_child(_stats_label)

	_timer_label = _make_label(28, Color(1.0, 0.9, 0.3))
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.position = Vector2(-60, 20)
	_timer_label.size = Vector2(120, 40)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_timer_label)

	_result_label = _make_label(20, Color(1.0, 0.95, 0.6))
	_result_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_result_label.position = Vector2(-220, 62)
	_result_label.size = Vector2(440, 60)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_result_label)

	_hint_label = _make_label(14, Color(0.85, 0.85, 0.85))
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position = Vector2(-320, -34)
	_hint_label.size = Vector2(640, 24)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = "WASD Move   Shift Walk   Ctrl Crouch   Space Jump   R Reload   1-5 Weapon   RMB Aim   T Start 60s Run   Esc Cursor"
	root.add_child(_hint_label)

func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l

func _process(delta: float) -> void:
	_update_crosshair_and_ammo()
	_update_stats()
	_update_timer()
	_update_health()
	_update_damage_flash(delta)

func _update_crosshair_and_ammo() -> void:
	if not player or not player.has_method("get_active_weapon"):
		return
	var weapon = player.get_active_weapon()
	if weapon == null:
		return
	_crosshair.gap = 6.0 + weapon.get_spread_deg() * 14.0
	_ammo_label.text = weapon.get_ammo_text()
	_weapon_name_label.text = weapon.stats.weapon_name.to_upper()
	_reload_label.text = "RELOADING" if weapon.is_reloading else ""

func _update_health() -> void:
	var pct: float = clamp(float(GameState.health) / float(GameState.MAX_HEALTH), 0.0, 1.0)
	_health_bar_fg.size.x = (HEALTH_BAR_WIDTH - 4) * pct
	_health_label.text = "HP %d" % GameState.health
	if pct > 0.6:
		_health_bar_fg.color = Color(0.25, 0.85, 0.35)
	elif pct > 0.3:
		_health_bar_fg.color = Color(0.9, 0.75, 0.2)
	else:
		_health_bar_fg.color = Color(0.85, 0.2, 0.2)

func _update_damage_flash(delta: float) -> void:
	if _damage_flash_t > 0.0:
		_damage_flash_t = max(_damage_flash_t - delta * 2.0, 0.0)
	_damage_flash.color.a = _damage_flash_t * 0.35

func _update_stats() -> void:
	_stats_label.text = "Score: %d\nHits: %d / %d shots  (%.0f%% acc)\nStreak: %d  (best %d)" % [
		GameState.score, GameState.hits, GameState.shots_fired, GameState.get_accuracy(),
		GameState.streak, GameState.best_streak
	]

func _update_timer() -> void:
	if GameState.run_active:
		var t: int = int(ceil(GameState.run_time_left))
		_timer_label.text = "%02d:%02d" % [t / 60, t % 60]
	else:
		_timer_label.text = ""

func _on_target_hit(zone: String, _points: int) -> void:
	_hitmarker.flash(zone == "head")

func _on_run_started() -> void:
	_result_label.text = ""

func _on_run_finished(final_score: int, final_accuracy: float) -> void:
	_result_label.text = "RUN COMPLETE — Score %d — Accuracy %.0f%%\nPress T to run again" % [final_score, final_accuracy]

func _on_player_damaged(_amount: int, _health: int) -> void:
	_damage_flash_t = 1.0

func _on_player_died() -> void:
	_death_label.text = "ELIMINATED — respawning..."

func _on_player_respawned() -> void:
	_death_label.text = ""
