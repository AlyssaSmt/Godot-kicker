extends CanvasLayer

@onready var label_a := $LabelTeamA
@onready var label_b := $LabelTeamB

func update_score(a: int, b: int):
	label_a.text = str(a)
	label_b.text = str(b)
