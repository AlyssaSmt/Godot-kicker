extends CanvasLayer
class_name MatchUI

# =========================
# NODES (passen zu deinem Tree)
# =========================
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

# Optional: if you don't have a MainMenu yet
@export var disable_main_menu_button: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	end_screen.mouse_filter = Control.MOUSE_FILTER_STOP

	# Buttons verbinden
	play_again_btn.pressed.connect(_on_play_again)
	main_menu_btn.pressed.connect(_on_main_menu)

	if disable_main_menu_button:
		main_menu_btn.disabled = true
		main_menu_btn.tooltip_text = "Main menu coming soon"

	# START-ZUSTAND: noch nicht gestartet
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

	# Text setzen
	title_label.text = "Game Over"
	result_label.text = "Final score: %d : %d\n%s" % [left_score, right_score, winner_text]

	# Gewinner optisch hervorheben (optional)
	# If you use exact strings "Team Blue wins!" / "Team Red wins!":
	if winner_text.find("Blue") != -1:
		title_label.modulate = Color(0.6, 0.75, 1.0) # leicht blau
	elif winner_text.find("Red") != -1:
		title_label.modulate = Color(1.0, 0.65, 0.65) # leicht rot
	else:
		title_label.modulate = Color(1, 1, 1)

	# Optional: hide HUD
	# hud.visible = false

	# Initial values for animation
	end_screen.modulate.a = 0.0
	card.scale = Vector2(0.95, 0.95)

	# If you use Dim as a ColorRect: control alpha
	# (You can also set the Dim color in the Inspector)
	dim.color = Color(0, 0, 0, 0.70)

	# Animation: Fade + Pop-in
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
	# hud.visible = true

func _on_play_again() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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

	# sofort sichtbar initialisieren
	if timer_label.text.strip_edges() == "":
		timer_label.text = "00:00"


func stop_match_ui() -> void:
	match_started = false
	hud.visible = false
