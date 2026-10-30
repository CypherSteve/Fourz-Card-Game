class_name MainMenu
extends Control

## MainMenu: Gateway scene for Fours.
## Allows selecting Single Player (2P/3P/4P vs bots), Multiplayer (LAN host/join),
## viewing rules, or adjusting sound settings before any game state is started.

const AudioManager = preload("res://src/presentation/audio_manager.gd")
const MultiplayerModalClass = preload("res://src/presentation/multiplayer_modal.gd")

@onready var btn_solo_2p: Button = $CenterArea/MenuCard/SoloBox/SoloButtons/Btn2P
@onready var btn_solo_3p: Button = $CenterArea/MenuCard/SoloBox/SoloButtons/Btn3P
@onready var btn_solo_4p: Button = $CenterArea/MenuCard/SoloBox/SoloButtons/Btn4P

@onready var btn_multiplayer: Button = $CenterArea/MenuCard/BtnMultiplayer
@onready var btn_rules: Button = $CenterArea/MenuCard/BtnRules
@onready var btn_quit: Button = $CenterArea/MenuCard/BtnQuit

@onready var btn_sound: Button = $TopBar/SoundButton
@onready var multiplayer_modal: MultiplayerModalClass = $MultiplayerModal
@onready var rules_modal: Panel = $RulesModal
@onready var rules_close_btn: Button = $RulesModal/ContentBox/CloseRulesButton

var audio_manager: AudioManager

func _ready() -> void:
	audio_manager = AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)
	
	if rules_modal != null:
		rules_modal.visible = false
	
	_setup_buttons()
	_apply_styles()

func _setup_buttons() -> void:
	btn_solo_2p.pressed.connect(func() -> void: _start_solo(2))
	btn_solo_3p.pressed.connect(func() -> void: _start_solo(3))
	btn_solo_4p.pressed.connect(func() -> void: _start_solo(4))
	
	btn_multiplayer.pressed.connect(_on_multiplayer_pressed)
	btn_rules.pressed.connect(_on_rules_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	if btn_sound != null:
		btn_sound.pressed.connect(_on_sound_pressed)
	
	if rules_close_btn != null:
		rules_close_btn.pressed.connect(func() -> void:
			audio_manager.play_click()
			rules_modal.visible = false
		)

func _start_solo(player_count: int) -> void:
	audio_manager.play_click()
	var net: NetworkManager = get_node_or_null("/root/GameNetwork")
	if net != null:
		net.pending_game_mode = "SOLO"
		net.pending_player_count = player_count
	get_tree().change_scene_to_file("res://src/presentation/table_view.tscn")

func _on_multiplayer_pressed() -> void:
	audio_manager.play_click()
	if multiplayer_modal != null:
		multiplayer_modal.open()

func _on_rules_pressed() -> void:
	audio_manager.play_click()
	if rules_modal != null:
		rules_modal.visible = true
		rules_modal.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(rules_modal, "modulate:a", 1.0, 0.2)

func _on_sound_pressed() -> void:
	audio_manager.is_muted = not audio_manager.is_muted
	btn_sound.text = "🔇 Muted" if audio_manager.is_muted else "🔊 Sound"

func _on_quit_pressed() -> void:
	audio_manager.play_click()
	get_tree().quit()

func _apply_styles() -> void:
	var card_panel: Panel = get_node_or_null("CenterArea/MenuCard")
	if card_panel != null:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.12, 0.16, 0.95)
		style.border_color = Color(0.24, 0.42, 0.35, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 20
		card_panel.add_theme_stylebox_override("panel", style)
	
	if rules_modal != null:
		var r_style := StyleBoxFlat.new()
		r_style.bg_color = Color(0.06, 0.10, 0.14, 0.98)
		r_style.border_color = Color(0.25, 0.45, 0.70, 0.9)
		r_style.set_border_width_all(2)
		r_style.set_corner_radius_all(12)
		r_style.shadow_color = Color(0, 0, 0, 0.5)
		r_style.shadow_size = 24
		rules_modal.add_theme_stylebox_override("panel", r_style)
