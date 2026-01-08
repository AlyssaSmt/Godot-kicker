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

	help_button.pressed.connect(_on_help_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# Optional: clicking the dark background closes
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)

func _on_help_pressed() -> void:
	get_tree().paused = true
	pause_menu.visible = true
	dim.visible = true
	help_panel.visible = true

func _on_close_pressed() -> void:
	help_panel.visible = false
	dim.visible = false
	pause_menu.visible = false
	get_tree().paused = false

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close_pressed()

func _disable_focus_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for c in node.get_children():
		_disable_focus_recursive(c)
