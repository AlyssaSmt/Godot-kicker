extends Node
class_name ScoreManager

var score_team_blue: int = 0
var score_team_red: int = 0

signal score_changed(a: int, b: int)


# ❗️NUR HOST ruft das direkt auf
func add_goal(team: String) -> void:
	match team:
		"Team Blue":
			score_team_blue += 1
		"Team Red":
			score_team_red += 1
		_:
			push_warning("Unknown Team: %s" % team)
			return

	# 🔥 Score an alle syncen (inkl. Host)
	rpc("_rpc_sync_score", score_team_blue, score_team_red)


func reset_score() -> void:
	score_team_blue = 0
	score_team_red = 0
	rpc("_rpc_sync_score", score_team_blue, score_team_red)


@rpc("authority", "reliable", "call_local")
func _rpc_sync_score(blue: int, red: int) -> void:
	score_team_blue = blue
	score_team_red = red
	emit_signal("score_changed", score_team_blue, score_team_red)


func get_left_score() -> int:
	return score_team_blue

func get_right_score() -> int:
	return score_team_red
