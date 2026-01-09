extends Control
class_name PauseMenu

signal request_reset(team_name: String, wants_reset: bool)
signal request_forfeit(team_name: String)
signal request_resume
signal request_score_reset

@export var team_name_local: String = "Team A"
@export var score_manager_path: NodePath


# ✅ Root to your VBox (you have: HelpPanel/Card/MarginContainer)
@export var ui_root_path: NodePath = NodePath("HelpPanel/Card/MarginContainer")

@onready var ui_root: Node = get_node_or_null(ui_root_path)

@onready var reset_button: Button = _n("VBoxContainer/HBoxContainer/ResetButton")
@onready var forfeit_button: Button = _n("VBoxContainer/HBoxContainer/ForfeitButton")
@onready var close_button: Button = _n("VBoxContainer/CloseButton")
@onready var vote_label: Label = _n("VBoxContainer/VoteLabel")

@onready var forfeit_confirm: ConfirmationDialog = $ForfeitConfirm
@onready var score_manager := get_node_or_null(score_manager_path)

var vote_a := false
var vote_b := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	if ui_root == null:
		push_error("PauseMenu: ui_root_path incorrect: " + str(ui_root_path))
		return

	_disable_focus(reset_button)
	_disable_focus(forfeit_button)
	_disable_focus(close_button)

	_connect_button(reset_button, _on_reset_pressed, "ResetButton")
	_connect_button(forfeit_button, _on_forfeit_pressed, "ForfeitButton")
	_connect_button(close_button, _on_close_pressed, "CloseButton")

	# (MainMenuButton optional removal: no automatic connection)

	if forfeit_confirm:
		forfeit_confirm.confirmed.connect(_on_forfeit_confirmed)
		forfeit_confirm.ok_button_text = "Yes, forfeit"
		forfeit_confirm.cancel_button_text = "Cancel"

	_update_vote_text()

func _n(rel_path: String) -> Node:
	if ui_root == null:
		return null
	return ui_root.get_node_or_null(rel_path)

func _disable_focus(c: Control) -> void:
	if c:
		c.focus_mode = Control.FOCUS_NONE

func _connect_button(btn: Button, cb: Callable, name_for_debug: String) -> void:
	if btn == null:
		push_warning("PauseMenu: Button missing: " + name_for_debug + " (check ui_root_path)")
		return
	btn.pressed.connect(cb)

# =========================
# Public API
# =========================
func open_menu() -> void:
	visible = true
	get_tree().paused = true

func close_menu() -> void:
	visible = false
	get_tree().paused = false
	emit_signal("request_resume")

func set_votes(a: bool, b: bool) -> void:
	vote_a = a
	vote_b = b
	_update_vote_text()

func clear_votes() -> void:
	vote_a = false
	vote_b = false
	_update_vote_text()

# =========================
# Voting
# =========================
func _get_local_vote() -> bool:
	return vote_a if team_name_local == "Team A" else vote_b

func _set_local_vote(value: bool) -> void:
	if team_name_local == "Team A":
		vote_a = value
	else:
		vote_b = value
	_update_vote_text()

func _update_vote_text() -> void:
	if vote_label:
		var a_txt := "✅" if vote_a else "❌"
		var b_txt := "✅" if vote_b else "❌"
		vote_label.text = "Reset votes – Team A: %s | Team B: %s" % [a_txt, b_txt]

	if reset_button:
		reset_button.text = "Retract reset vote" if _get_local_vote() else "Vote reset"

# =========================
# Callbacks
# =========================
func _on_reset_pressed() -> void:
	var wants_reset := !_get_local_vote()
	_set_local_vote(wants_reset)
	emit_signal("request_reset", team_name_local, wants_reset)

func _on_forfeit_pressed() -> void:
	if forfeit_confirm:
		forfeit_confirm.popup_centered()

func _on_close_pressed() -> void:
	close_menu()

func _on_forfeit_confirmed() -> void:
	emit_signal("request_score_reset")
	emit_signal("request_forfeit", team_name_local)
	close_menu()


# (No built-in main-menu handler in PauseMenu anymore)
