extends CanvasLayer

@export var show_time := 1.2

@onready var label: Label = $Label

var current_tween: Tween

func _ready() -> void:
	visible = false
	label.modulate.a = 0.0


func show_goal(team_name: String) -> void:
	label.text = "GOAL FOR %s!" % team_name

	# Reset (important if a previous tween was running)
	label.modulate.a = 0.0
	visible = true

	# Cancel old tween if present
	if current_tween:
		current_tween.kill()

	current_tween = create_tween()
	var tween := current_tween

	# Fade in
	tween.tween_property(label, "modulate:a", 1.0, 0.25)

	# Hold
	tween.tween_interval(show_time)

	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 0.35)

	tween.finished.connect(func():
		visible = false
	)
