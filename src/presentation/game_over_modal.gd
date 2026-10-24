class_name GameOverModal
extends Control

## GameOverModal: End-of-game victory/defeat celebration dialog with Play Again button.

signal play_again_requested()

@onready var panel_node: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var play_again_button: Button = $Panel/VBox/PlayAgainButton

func _ready() -> void:
	visible = false
	play_again_button.pressed.connect(_on_play_again_pressed)
	
	if panel_node:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.08, 0.12, 0.19, 0.98) # Crisp dark opaque background
		panel_style.border_color = Color(0.28, 0.42, 0.68, 0.9)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(14)
		panel_style.shadow_color = Color(0, 0, 0, 0.55)
		panel_style.shadow_size = 20
		panel_style.shadow_offset = Vector2(0, 6)
		panel_node.add_theme_stylebox_override("panel", panel_style)

func show_game_over(winner_name: String, is_player_winner: bool, turns: int, burned_count: int) -> void:
	visible = true
	modulate.a = 0.0
	
	if is_player_winner:
		title_label.text = "🏆 VICTORY! 🏆"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold
		message_label.text = "Congratulations! You shed all of your cards!"
	else:
		title_label.text = "💀 DEFEAT 💀"
		title_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3)) # Crimson
		message_label.text = "%s cleared all cards before you!" % [winner_name]
	
	stats_label.text = "Match Duration: %d turns  •  Cards Burned: %d" % [turns, burned_count]
	
	# Smooth fade-in and scale punch
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _on_play_again_pressed() -> void:
	visible = false
	play_again_requested.emit()
