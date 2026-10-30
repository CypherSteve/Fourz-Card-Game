class_name SwapOverlay
extends Control

## SwapOverlay: UI banner and timer for the 30-second pre-game strategy swap.
## Lets the player swap cards between Group A and Group B, and signal readiness.

signal ready_toggled(is_ready: bool)

@onready var timer_label: Label = $Panel/VBox/TimerLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var ready_button: Button = $Panel/VBox/ReadyButton

var is_ready: bool = false

func _ready() -> void:
	ready_button.pressed.connect(_on_ready_pressed)
	update_ready_ui()

func update_time(seconds: float) -> void:
	timer_label.text = "⏱ Swap Phase: %02d s" % [ceili(seconds)]
	if seconds <= 5.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))

func set_bot_status(bot_name: String, bot_ready: bool) -> void:
	set_player_status(bot_name, bot_ready)

func set_player_status(player_name: String, player_ready: bool) -> void:
	if player_ready:
		status_label.text = "✓ %s is Ready!" % [player_name]
		status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		status_label.text = "⏳ %s is swapping cards..." % [player_name]
		status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))

func _on_ready_pressed() -> void:
	is_ready = not is_ready
	update_ready_ui()
	ready_toggled.emit(is_ready)

func update_ready_ui() -> void:
	if is_ready:
		ready_button.text = "✓ READY (Waiting...)"
		ready_button.modulate = Color(0.4, 0.9, 0.4)
	else:
		ready_button.text = "I'M READY!"
		ready_button.modulate = Color(1.0, 1.0, 1.0)
