extends Control
class_name PauseMenu

signal request_reset(team_name: String, wants_reset: bool)
signal request_forfeit(team_name: String)
signal request_resume
signal request_score_reset


@export var team_name_local: String = "Team A"
@export var score_manager_path: NodePath


@onready var reset_button: Button = $HelpPanel/VBoxContainer/HBoxContainer/ResetButton
@onready var forfeit_button: Button = $HelpPanel/VBoxContainer/HBoxContainer/ForfeitButton
@onready var close_button: Button = $HelpPanel/VBoxContainer/CloseButton
@onready var vote_label: Label = $HelpPanel/VBoxContainer/VoteLabel

@onready var forfeit_confirm: ConfirmationDialog = $ForfeitConfirm
@onready var score_manager := get_node_or_null(score_manager_path)



var vote_a := false
var vote_b := false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# 🔒 Space darf Buttons NICHT auslösen
	reset_button.focus_mode = Control.FOCUS_NONE
	forfeit_button.focus_mode = Control.FOCUS_NONE
	close_button.focus_mode = Control.FOCUS_NONE

	reset_button.pressed.connect(_on_reset_pressed)
	forfeit_button.pressed.connect(_on_forfeit_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# ConfirmDialog
	forfeit_confirm.confirmed.connect(_on_forfeit_confirmed)
	forfeit_confirm.ok_button_text = "Yes, forfeit"
	forfeit_confirm.cancel_button_text = "Cancel"

	_update_vote_text()


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
# Voting Helpers (lokales Team)
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
	var a_txt := "✅" if vote_a else "❌"
	var b_txt := "✅" if vote_b else "❌"
	vote_label.text = "Reset Zustimmung – Team A: %s | Team B: %s" % [a_txt, b_txt]

	# Reset-Button zeigt immer den passenden Toggle-Text
	reset_button.text = "Reset-Vote zurücknehmen" if _get_local_vote() else "Reset voten"


# =========================
# Button Callbacks
# =========================
func _on_reset_pressed() -> void:
	# Toggle: nochmal klicken = vote zurücknehmen
	var wants_reset := !_get_local_vote()

	# UI sofort aktualisieren (fühlt sich direkt an)
	_set_local_vote(wants_reset)

	# Empfänger (Main/ScoreManager/Netcode) soll dann Votes sammeln & ggf. resetten
	emit_signal("request_reset", team_name_local, wants_reset)


func _on_forfeit_pressed() -> void:
	forfeit_confirm.popup_centered()


func _on_close_pressed() -> void:
	close_menu()


func _on_forfeit_confirmed() -> void:
	emit_signal("request_score_reset")
	emit_signal("request_forfeit", team_name_local)
	close_menu()



# Optional später:
func exit_to_menu() -> void:
	get_tree().reload_current_scene()


func _reset_score() -> void:
	# Variante 1: ScoreManager ist im Inspector per NodePath verlinkt
	if score_manager and score_manager.has_method("reset_score"):
		score_manager.call("reset_score")
		return
	if score_manager and score_manager.has_method("reset"):
		score_manager.call("reset")
		return

	# Variante 2: ScoreManager ist ein Autoload (Singleton) /root/ScoreManager
	var sm := get_node_or_null("/root/ScoreManager")
	if sm and sm.has_method("reset_score"):
		sm.call("reset_score")
	elif sm and sm.has_method("reset"):
		sm.call("reset")
	else:
		print("⚠️ Kein ScoreManager gefunden oder keine reset/reset_score Methode.")
