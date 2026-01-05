extends CanvasLayer

@onready var pause_menu: Control = $PauseMenu
@onready var help_panel: Control = $PauseMenu/HelpPanel
@onready var close_button: Button = $PauseMenu/HelpPanel/VBoxContainer/CloseButton

@onready var reset_button: Button = $PauseMenu/HelpPanel/VBoxContainer/HBoxContainer/ResetButton
@onready var forfeit_button: Button = $PauseMenu/HelpPanel/VBoxContainer/HBoxContainer/ForfeitButton
@onready var vote_label: Label = $PauseMenu/HelpPanel/VBoxContainer/VoteLabel
@onready var help_button: Button = $HelpButton

func _ready() -> void:
	# Menü am Anfang aus
	pause_menu.visible = false
	help_panel.visible = false

	# WICHTIG: UI soll funktionieren, auch wenn Spiel pausiert
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	help_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Space darf NICHT den Button "klicken"
	_disable_focus_recursive(self)

	help_button.pressed.connect(_on_help_pressed)
	close_button.pressed.connect(_on_close_pressed)

func _on_help_pressed() -> void:
	# Pause an + Menü zeigen
	get_tree().paused = true
	pause_menu.visible = true
	help_panel.visible = true

func _on_close_pressed() -> void:
	help_panel.visible = false
	pause_menu.visible = false
	get_tree().paused = false


func _disable_focus_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for c in node.get_children():
		_disable_focus_recursive(c)
