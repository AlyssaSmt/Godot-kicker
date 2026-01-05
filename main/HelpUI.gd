extends CanvasLayer

@onready var help_button: Button = $HelpButton
@onready var help_panel: Panel = $HelpPanel
@onready var close_button: Button = $HelpPanel/CloseButton

func _ready() -> void:
	help_panel.visible = false
	help_button.pressed.connect(_toggle_help)
	close_button.pressed.connect(_hide_help)

func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible

func _hide_help() -> void:
	help_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# ESC schließt Hilfe
	if event.is_action_pressed("ui_cancel") and help_panel.visible:
		help_panel.visible = false
		get_viewport().set_input_as_handled()
