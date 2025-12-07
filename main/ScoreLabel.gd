extends Label

func _ready():
	# holt ScoreManager aus der Szene
	var score_manager := get_tree().get_root().get_node("main/ScoreManager")
	score_manager.connect("score_changed", Callable(self, "_on_score_changed"))

	_on_score_changed(0, 0) # Anfangswert

func _on_score_changed(a: int, b: int):
	text = str(a, " : ", b)
