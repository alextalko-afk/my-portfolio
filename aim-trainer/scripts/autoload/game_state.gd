extends Node
## Live session stats + timed-run tracking (autoload singleton "GameState").

signal target_hit(zone: String, points: int)
signal stats_reset
signal run_started
signal run_finished(final_score: int, final_accuracy: float)
signal player_damaged(amount: int, health: int)
signal player_died
signal player_respawned

const RUN_DURATION := 60.0
const MAX_HEALTH := 100

var shots_fired: int = 0
var hits: int = 0
var score: int = 0
var streak: int = 0
var best_streak: int = 0

var run_active: bool = false
var run_time_left: float = 0.0

var health: int = MAX_HEALTH
var is_dead: bool = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("start_run"):
		start_run()
	if run_active:
		run_time_left = max(run_time_left - delta, 0.0)
		if run_time_left <= 0.0:
			run_active = false
			run_finished.emit(score, get_accuracy())

func register_shot() -> void:
	shots_fired += 1

func register_hit(zone: String, points: int) -> void:
	hits += 1
	score += points
	streak += 1
	best_streak = max(best_streak, streak)
	target_hit.emit(zone, points)

func register_miss() -> void:
	streak = 0

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = max(health - amount, 0)
	player_damaged.emit(amount, health)
	if health <= 0:
		is_dead = true
		streak = 0
		player_died.emit()

func respawn() -> void:
	health = MAX_HEALTH
	is_dead = false
	player_respawned.emit()

func get_accuracy() -> float:
	if shots_fired == 0:
		return 0.0
	return (float(hits) / float(shots_fired)) * 100.0

func start_run() -> void:
	shots_fired = 0
	hits = 0
	score = 0
	streak = 0
	best_streak = 0
	run_time_left = RUN_DURATION
	run_active = true
	stats_reset.emit()
	run_started.emit()
