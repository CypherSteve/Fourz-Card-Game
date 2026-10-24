class_name OpponentView
extends VBoxContainer

## OpponentView: Visual display for an individual opponent (Bot Alpha, Beta, Gamma).
## Shows active turn spotlight, name, hand card backs, and table cards (C + B layers).

@onready var name_label: Label = $NameLabel
@onready var hand_count_label: Label = $HandBox/HandCountLabel
@onready var mini_cards_container: HBoxContainer = $HandBox/MiniCards
@onready var table_cards_container: HBoxContainer = $TableCardsContainer
@onready var turn_badge: PanelContainer = $TurnBadge

var card_scene: PackedScene = preload("res://src/presentation/card_view.tscn")
var player_id: int = -1

func _ready() -> void:
	if turn_badge:
		turn_badge.visible = false
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.82, 0.12, 1.0) # Bright gold
		badge_style.set_corner_radius_all(8)
		badge_style.content_margin_left = 8
		badge_style.content_margin_right = 8
		badge_style.content_margin_top = 1
		badge_style.content_margin_bottom = 1
		turn_badge.add_theme_stylebox_override("panel", badge_style)

func update_opponent(player: PlayerState, is_active_turn: bool) -> void:
	player_id = player.id
	hand_count_label.text = "Hand: %d" % [player.group_a.size()]
	
	var prefix := "🤖 " if player.is_bot else "👤 "
	if is_active_turn:
		name_label.text = "▶  %s%s" % [prefix, player.name]
		name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2)) # Glowing gold
		modulate = Color(1.0, 1.0, 1.0)
		if turn_badge:
			turn_badge.visible = true
	else:
		name_label.text = "%s%s" % [prefix, player.name]
		name_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
		modulate = Color(0.60, 0.65, 0.74) # Dimmed when not their turn
		if turn_badge:
			turn_badge.visible = false
	
	_render_mini_cards(player.group_a.size())
	_render_table_cards(player)

func _render_mini_cards(count: int) -> void:
	for child in mini_cards_container.get_children():
		child.queue_free()
	
	var display_count := mini(count, 10)
	for i in range(display_count):
		var mini := Panel.new()
		mini.custom_minimum_size = Vector2(14, 20)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.18, 0.32, 1.0)
		style.border_color = Color(0.32, 0.46, 0.72, 1.0)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		mini.add_theme_stylebox_override("panel", style)
		mini_cards_container.add_child(mini)
	
	if count > 10:
		var extra := Label.new()
		extra.text = "+%d" % [count - 10]
		extra.add_theme_font_size_override("font_size", 10)
		mini_cards_container.add_child(extra)

func _render_table_cards(player: PlayerState) -> void:
	for child in table_cards_container.get_children():
		child.queue_free()
	
	var max_slots: int = maxi(player.group_c.size(), player.group_b.size())
	for i in range(max_slots):
		var slot_box := Control.new()
		slot_box.custom_minimum_size = Vector2(68, 114)
		table_cards_container.add_child(slot_box)
		
		# Group C (Face down, top)
		if i < player.group_c.size():
			var c_card := card_scene.instantiate() as CardView
			slot_box.add_child(c_card)
			c_card.scale = Vector2(0.8, 0.8)
			c_card.position = Vector2(0, 0)
			c_card.set_card(player.group_c[i], false, "C", i)
			c_card.is_interactive = false
		
		# Group B (Face up, shifted 18px down for peek)
		if i < player.group_b.size():
			var b_card := card_scene.instantiate() as CardView
			slot_box.add_child(b_card)
			b_card.scale = Vector2(0.8, 0.8)
			b_card.position = Vector2(0, 18)
			b_card.set_card(player.group_b[i], true, "B", i)
			b_card.is_interactive = false
