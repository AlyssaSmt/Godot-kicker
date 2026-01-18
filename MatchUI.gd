extends CanvasLayer
class_name MatchUI

@onready var hud: Control = $HUD
@onready var timer_label: Label = $HUD/TimerLabel
@onready var score_label: Label = $HUD/ScoreLabel

@onready var end_screen: Control = $EndScreen
@onready var dim: ColorRect = $EndScreen/Dim
@onready var card: Control = $EndScreen/Card
@onready var title_label: Label = $EndScreen/Card/VBox/TitleLabel
@onready var result_label: Label = $EndScreen/Card/VBox/ResultLabel

@onready var buttons: Control = $EndScreen/Card/VBox/Buttons
@onready var play_again_btn: Button = $EndScreen/Card/VBox/Buttons/PlayAgainButton
@onready var main_menu_btn: Button = $EndScreen/Card/VBox/Buttons/MainMenuButton

var match_started := false

@export var disable_main_menu_button: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	end_screen.mouse_filter = Control.MOUSE_FILTER_STOP

	# connect buttons
	play_again_btn.pressed.connect(_on_play_again)
	main_menu_btn.pressed.connect(_on_main_menu)

	if disable_main_menu_button:
		main_menu_btn.disabled = true
		main_menu_btn.tooltip_text = "Main menu coming soon"

	match_started = false
	hud.visible = false
	hide_end_screen()


func set_time_left(seconds_left: int) -> void:
	if !match_started:
		return
	timer_label.text = _format_time(seconds_left)
	print("TIMER UI:", timer_label.text, " visible=", timer_label.visible, " hud=", hud.visible)


func set_score(left_score: int, right_score: int) -> void:
	if !match_started:
		return
	score_label.text = "%d : %d" % [left_score, right_score]


func show_end_screen(left_score: int, right_score: int, winner_text: String) -> void:
	end_screen.visible = true
	# Ensure the mouse is visible when the end screen appears
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Make sure the Main Menu button on the end screen is clickable
	if main_menu_btn:
		main_menu_btn.disabled = false
		main_menu_btn.tooltip_text = ""

	# Set result texts
	title_label.text = "Game Over"
	result_label.text = "Final score: %d : %d\n%s" % [left_score, right_score, winner_text]

	# Highlight winner visually
	if winner_text.find("Blue") != -1:
		title_label.modulate = Color(0.6, 0.75, 1.0) 
	elif winner_text.find("Red") != -1:
		title_label.modulate = Color(1.0, 0.65, 0.65)
	else:
		title_label.modulate = Color(1, 1, 1)

	# Initial values for animation
	end_screen.modulate.a = 0.0
	card.scale = Vector2(0.95, 0.95)

	dim.color = Color(0, 0, 0, 0.70)

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(end_screen, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(card, "scale", Vector2(1, 1), 0.18)

func hide_end_screen() -> void:
	end_screen.visible = false
	end_screen.modulate.a = 1.0
	card.scale = Vector2(1, 1)
	title_label.modulate = Color(1, 1, 1)


func _on_play_again() -> void:
	var root := get_tree().current_scene
	if root and root.has_method("request_play_again"):
		root.call_deferred("request_play_again")
		return
	
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var root := get_tree().current_scene
	if root and root.has_method("request_return_to_menu"):
		root.call_deferred("request_return_to_menu")
		return
	# Fallback
	get_tree().paused = false
	var err := get_tree().change_scene_to_file("res://MainMenu/MultiplayerMenu.tscn")
	if err != OK:
		push_error("MatchUI: Could not open MultiplayerMenu.tscn: %s" % err)

func _format_time(total_seconds: int) -> String:
	var m := int(total_seconds / 60.0)
	var s := total_seconds % 60
	return "%02d:%02d" % [m, s]


func start_match_ui() -> void:
	match_started = true
	hud.visible = true
	# Score is shown only when match is running
	if score_label:
		score_label.visible = false

	# Initialize timer display
	if timer_label.text.strip_edges() == "":
		timer_label.text = "00:00"


func stop_match_ui() -> void:
	match_started = false
	hud.visible = false
