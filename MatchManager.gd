extends Node
class_name MatchManager

@export var round_seconds: int = 5 * 5

@export var score_manager_path: NodePath
@export var ui_path: NodePath

var time_left: int
var running := false
var _accum := 0.0

@onready var score_manager: Node = get_node(score_manager_path)
@onready var ui: Node = get_node(ui_path)

func _ready() -> void:
	start_round()

func start_round() -> void:
	get_tree().paused = false
	time_left = round_seconds
	running = true
	_accum = 0.0
	_update_ui_time()

func reset_round() -> void:
	# Timer + UI zurücksetzen (z.B. bei Forfeit oder "Nochmal spielen" ohne Scene reload)
	get_tree().paused = false
	time_left = round_seconds
	running = true
	_accum = 0.0
	_update_ui_time()

	if ui and ui.has_method("hide_end_screen"):
		ui.hide_end_screen()

	# optional: Score resetten, falls vorhanden
	if score_manager and score_manager.has_method("reset_score"):
		score_manager.reset_score()

	# optional: HUD Score zurücksetzen
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

	var winner := "Unentschieden!"
	if left_score > right_score:
		winner = "Team Blau gewinnt!"
	elif right_score > left_score:
		winner = "Team Rot gewinnt!"

	if ui and ui.has_method("show_end_screen"):
		ui.show_end_screen(left_score, right_score, winner)

func forfeit(loser_team_name: String) -> void:
	running = false
	get_tree().paused = true

	var scores := _get_scores()
	var left_score := scores[0]
	var right_score := scores[1]

	var winner_text := "Unentschieden!"
	# WICHTIG: Passe die Teamnamen an DEIN Spiel an
	# Hier: Team A = Blau, Team B = Rot
	if loser_team_name == "Team A":
		winner_text = "Team Rot gewinnt! (Forfeit)"
	elif loser_team_name == "Team B":
		winner_text = "Team Blau gewinnt! (Forfeit)"
	else:
		winner_text = "Gegner gewinnt! (Forfeit)"

	if ui and ui.has_method("show_end_screen"):
		ui.show_end_screen(left_score, right_score, winner_text)


func _update_ui_time() -> void:
	if ui and ui.has_method("set_time_left"):
		ui.set_time_left(time_left)

# ------------------------------------------------------------
# Robust score fetch:
# 1) Getter-Methoden (empfohlen)
# 2) Fallback: bekannte Variablennamen via get_indexed()
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

	# 2) Fallback: Variablen (ohne has_variable/has_property)
	# get_indexed("prop") gibt einen Fehler, wenn es nicht existiert,
	# daher try/catch per "has_method" geht hier nicht. Wir nutzen safe helper:
	if left_score == 0:
		left_score = _try_get_int(score_manager, ["score_left", "left_score", "blue_score", "score_blue"])
	if right_score == 0:
		right_score = _try_get_int(score_manager, ["score_right", "right_score", "red_score", "score_red"])

	return [left_score, right_score]

func _try_get_int(obj: Object, names: Array[String]) -> int:
	# Versucht mehrere Property-Namen; wenn keiner existiert -> 0
	for n in names:
		# Object.get() existiert, aber ohne default. Wenn Property nicht existiert,
		# liefert es null.
		var v = obj.get(n)
		if v != null:
			return int(v)
	return 0
