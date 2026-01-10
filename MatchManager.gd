extends Node
class_name MatchManager

@export var round_seconds: int = 5 * 60

@export var score_manager_path: NodePath
@export var ui_path: NodePath

var time_left: int
var running := false
var _accum := 0.0

@onready var score_manager: Node = get_node_or_null(score_manager_path)
@onready var ui: Node = get_node_or_null(ui_path)

func _ready() -> void:
	# NICHT automatisch starten – wartet auf Menü-Start
	running = false
	_accum = 0.0
	time_left = round_seconds
	_update_ui_time() # setzt 05:00 (oder was du willst) – wird von MatchUI ignoriert bis start_match_ui()


func start_round() -> void:
	get_tree().paused = false
	time_left = round_seconds
	running = true
	_accum = 0.0
	# Ensure the UI is in "match started" state so it accepts time updates
	if ui and ui.has_method("start_match_ui"):
		ui.start_match_ui()
	_update_ui_time()

func reset_round() -> void:
	# Reset timer + UI (e.g. for forfeit or "Play again" without scene reload)
	get_tree().paused = false
	time_left = round_seconds
	running = true
	_accum = 0.0
	# Make sure HUD is visible and will accept updates
	if ui and ui.has_method("start_match_ui"):
		ui.start_match_ui()
	_update_ui_time()

	if ui and ui.has_method("hide_end_screen"):
		ui.hide_end_screen()

	# optional: reset score if available
	if score_manager and score_manager.has_method("reset_score"):
		score_manager.reset_score()

	# optional: reset HUD score
	if ui and ui.has_method("set_score"):
		ui.set_score(0, 0)

func _process(delta: float) -> void:
	if not running:
		return

	_accum += delta
	if _accum < 1.0:
		return

	var secs := int(floor(_accum))
	_accum -= float(secs)

	time_left = max(0, time_left - secs)
	_update_ui_time()

	if time_left <= 0:
		end_round()

func end_round() -> void:
	running = false
	get_tree().paused = true

	var scores := _get_scores()
	var left_score := scores[0]
	var right_score := scores[1]

	var winner := "Draw!"
	if left_score > right_score:
		winner = "Team Blue wins!"
	elif right_score > left_score:
		winner = "Team Red wins!"

	if ui and ui.has_method("show_end_screen"):
		ui.show_end_screen(left_score, right_score, winner)

func forfeit(loser_team_name: String) -> void:
	running = false
	get_tree().paused = true

	var scores := _get_scores()
	var left_score := scores[0]
	var right_score := scores[1]

	var winner_text := "Draw!"
	# IMPORTANT: Adjust team names to YOUR game if needed
	# Here: Team Blue (formerly Team A) and Team Red (formerly Team B)
	if loser_team_name == "Team Blue":
		winner_text = "Team Red wins! (Forfeit)"
	elif loser_team_name == "Team Red":
		winner_text = "Team Blue wins! (Forfeit)"
	else:
		winner_text = "Opponent wins! (Forfeit)"

	if ui and ui.has_method("show_end_screen"):
		ui.show_end_screen(left_score, right_score, winner_text)


func _update_ui_time() -> void:
	if ui and ui.has_method("set_time_left"):
		ui.set_time_left(time_left)

# ------------------------------------------------------------
# Robust score fetch:
# 1) Getter methods (recommended)
# 2) Fallback: known variable names via get_indexed()
# ------------------------------------------------------------
func _get_scores() -> Array[int]:
	var left_score := 0
	var right_score := 0

	if score_manager == null:
		return [0, 0]

	# 1) Empfohlen: Getter
	if score_manager.has_method("get_left_score"):
		left_score = int(score_manager.call("get_left_score"))
	if score_manager.has_method("get_right_score"):
		right_score = int(score_manager.call("get_right_score"))

	# 2) Fallback: Variables (without has_variable/has_property)
	# get_indexed("prop") raises an error if it doesn't exist,
	# therefore try/catch via "has_method" won't work here. We use a safe helper:
	if left_score == 0:
		left_score = _try_get_int(score_manager, ["score_left", "left_score", "blue_score", "score_blue"])
	if right_score == 0:
		right_score = _try_get_int(score_manager, ["score_right", "right_score", "red_score", "score_red"])

	return [left_score, right_score]

func _try_get_int(obj: Object, names: Array[String]) -> int:
	# Tries several property names; if none exist -> 0
	for n in names:
		# Object.get() exists but without default. If property doesn't exist,
		# it returns null.
		var v = obj.get(n)
		if v != null:
			return int(v)
	return 0


func start_match() -> void:
	# startet eine neue Runde nur wenn gerade nicht läuft
	if running:
		return
	start_round()

func stop_match() -> void:
	running = false
