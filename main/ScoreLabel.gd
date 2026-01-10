extends Label

@onready var score_manager := get_node("/root/main/ScoreManager")

func _ready():
	if score_manager == null:
		push_error("ScoreManager not found!")
		return

	score_manager.connect("score_changed", Callable(self, "_update_score"))
	_update_score(score_manager.get_left_score(), score_manager.get_right_score())

func _update_score(a: int, b: int):
	text = str(a, " : ", b)
