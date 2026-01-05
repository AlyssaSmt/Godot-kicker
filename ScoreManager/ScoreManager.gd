extends Node
class_name ScoreManager

var score_team_a: int = 0
var score_team_b: int = 0

signal score_changed(a: int, b: int)

func add_goal(team: String) -> void:
	match team:
		"Team A":
			score_team_a += 1
		"Team B":
			score_team_b += 1
		_:
			push_warning("Unknown Team: %s" % team)
			return

	emit_signal("score_changed", score_team_a, score_team_b)


func reset_score() -> void:
	score_team_a = 0
	score_team_b = 0
	emit_signal("score_changed", score_team_a, score_team_b)
