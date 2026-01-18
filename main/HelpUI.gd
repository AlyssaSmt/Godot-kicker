extends CanvasLayer

@onready var pause_menu: Control = $PauseMenu
@onready var dim: ColorRect = $PauseMenu/Dim
@onready var help_panel: Control = $PauseMenu/HelpPanel

@onready var close_button: Button = $PauseMenu/HelpPanel/Card/MarginContainer/VBoxContainer/CloseButton
@onready var help_button: Button = $HelpButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	help_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.process_mode = Node.PROCESS_MODE_ALWAYS

	# Initial state
	pause_menu.visible = false
	dim.visible = false
	help_panel.visible = false

	_disable_focus_recursive(self)

	dim.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_help_pressed() -> void:
	pause_menu.visible = true
	dim.visible = true
	help_panel.visible = true

func _on_close_pressed() -> void:
	help_panel.visible = false
	dim.visible = false
	pause_menu.visible = false

func _on_dim_input(event: InputEvent) -> void:
	return

func _disable_focus_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for c in node.get_children():
		_disable_focus_recursive(c)
