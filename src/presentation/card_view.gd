class_name CardView
extends Control

## CardView: Visual representation of a playing card in Godot.
## Renders crisp procedural graphics (face-up and face-down), handles hover lifts,
## selection states, and click signals for Group A, B, and C.

signal card_clicked(card_view: CardView)

@export var card_width: float = 84.0
@export var card_height: float = 120.0

var data: CardData = null
var is_face_up: bool = true
var is_selected: bool = false
var group_source: String = "A" # "A", "B", "C", or "GROUND"
var group_index: int = 0

var is_interactive: bool = true:
	set(val):
		is_interactive = val
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_interactive else Control.CURSOR_ARROW

# UI Child Nodes
var background_panel: Panel
var back_pattern: Panel
var corner_top_left: Label
var corner_bottom_right: Label
var center_label: Label
var selection_border: ReferenceRect

var _is_hovered: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(card_width, card_height)
	size = custom_minimum_size
	pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	_build_ui()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	update_view()

func _build_ui() -> void:
	# Main card body (Face-up)
	background_panel = Panel.new()
	background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_panel)
	
	# Face-down back cover
	back_pattern = Panel.new()
	back_pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back_pattern)
	
	# Inner decorative frame on the back
	var back_inner := Panel.new()
	back_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_inner.offset_left = 6.0
	back_inner.offset_top = 6.0
	back_inner.offset_right = -6.0
	back_inner.offset_bottom = -6.0
	back_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.16, 0.24, 0.42, 1.0)
	inner_style.border_color = Color(0.38, 0.54, 0.85, 0.8)
	inner_style.set_border_width_all(2)
	inner_style.set_corner_radius_all(4)
	back_inner.add_theme_stylebox_override("panel", inner_style)
	back_pattern.add_child(back_inner)
	
	# Top-left combined badge (e.g. "10 ♦" or "A ♠")
	corner_top_left = Label.new()
	corner_top_left.position = Vector2(5, 4)
	corner_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner_top_left.add_theme_font_size_override("font_size", 14)
	add_child(corner_top_left)
	
	# Bottom-right badge
	corner_bottom_right = Label.new()
	corner_bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner_bottom_right.offset_left = -38.0
	corner_bottom_right.offset_top = -22.0
	corner_bottom_right.offset_right = -5.0
	corner_bottom_right.offset_bottom = -3.0
	corner_bottom_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner_bottom_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner_bottom_right.add_theme_font_size_override("font_size", 13)
	add_child(corner_bottom_right)
	
	# Center large symbol
	center_label = Label.new()
	center_label.set_anchors_preset(Control.PRESET_CENTER)
	center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_label.add_theme_font_size_override("font_size", 28)
	add_child(center_label)
	
	# Selection border (Gold glow)
	selection_border = ReferenceRect.new()
	selection_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_border.border_color = Color(1.0, 0.84, 0.0, 1.0)
	selection_border.border_width = 3.0
	selection_border.editor_only = false
	selection_border.visible = false
	selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selection_border)
	
	_apply_styles()

func _apply_styles() -> void:
	# Front style: Clean off-white card face with subtle border and drop shadow
	var front_style := StyleBoxFlat.new()
	front_style.bg_color = Color(0.98, 0.98, 0.99, 1.0)
	front_style.border_color = Color(0.85, 0.86, 0.9, 1.0)
	front_style.set_border_width_all(1)
	front_style.set_corner_radius_all(6)
	front_style.shadow_color = Color(0, 0, 0, 0.28)
	front_style.shadow_size = 5
	front_style.shadow_offset = Vector2(0, 2)
	background_panel.add_theme_stylebox_override("panel", front_style)
	
	# Back style: Deep rich midnight navy blue with elegant cyan border
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.10, 0.15, 0.28, 1.0)
	back_style.border_color = Color(0.28, 0.42, 0.68, 1.0)
	back_style.set_border_width_all(3)
	back_style.set_corner_radius_all(6)
	back_style.shadow_color = Color(0, 0, 0, 0.35)
	back_style.shadow_size = 5
	back_pattern.add_theme_stylebox_override("panel", back_style)

## Sets card data and face orientation
func set_card(p_data: CardData, p_face_up: bool = true, p_group: String = "A", p_idx: int = 0) -> void:
	data = p_data
	is_face_up = p_face_up
	group_source = p_group
	group_index = p_idx
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_interactive else Control.CURSOR_ARROW
	update_view()

func set_face_up(p_face_up: bool) -> void:
	is_face_up = p_face_up
	update_view()

var _selection_tween: Tween

func set_selected(p_selected: bool) -> void:
	is_selected = p_selected
	selection_border.visible = is_selected
	
	if _selection_tween and _selection_tween.is_valid():
		_selection_tween.kill()
	
	if is_selected:
		selection_border.border_color = Color(1.0, 0.84, 0.0, 1.0)
		_selection_tween = create_tween().set_loops()
		_selection_tween.tween_property(selection_border, "border_color:a", 0.4, 0.5).set_trans(Tween.TRANS_SINE)
		_selection_tween.tween_property(selection_border, "border_color:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	
	_animate_lift()

func update_view() -> void:
	if not is_inside_tree():
		return
	
	if data == null:
		visible = false
		return
	
	visible = true
	back_pattern.visible = not is_face_up
	background_panel.visible = is_face_up
	corner_top_left.visible = is_face_up
	corner_bottom_right.visible = is_face_up
	center_label.visible = is_face_up
	
	if is_face_up:
		var rank_str := data.get_rank_str()
		var suit_sym := data.get_suit_symbol()
		
		# Vivid red for Hearts/Diamonds, clean dark charcoal for Clubs/Spades
		var is_red: bool = (data.suit == CardData.Suit.HEARTS or data.suit == CardData.Suit.DIAMONDS)
		var card_color := Color(0.85, 0.08, 0.16, 1.0) if is_red else Color(0.12, 0.13, 0.16, 1.0)
		
		var badge_text := "%s%s" % [rank_str, suit_sym]
		corner_top_left.text = badge_text
		corner_top_left.add_theme_color_override("font_color", card_color)
		
		corner_bottom_right.text = badge_text
		corner_bottom_right.add_theme_color_override("font_color", card_color)
		
		center_label.text = "%s\n%s" % [rank_str, suit_sym]
		center_label.add_theme_color_override("font_color", card_color)

func _animate_lift() -> void:
	var target_y: float = 0.0
	var target_scale := Vector2(1.0, 1.0)
	
	if is_selected:
		target_y = -18.0
		target_scale = Vector2(1.06, 1.06)
	elif _is_hovered and is_interactive:
		target_y = -12.0
		target_scale = Vector2(1.04, 1.04)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", target_y, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_mouse_entered() -> void:
	_is_hovered = true
	if is_interactive:
		_animate_lift()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_animate_lift()

func _on_gui_input(event: InputEvent) -> void:
	if not is_interactive:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var press_tween := create_tween()
		press_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.05).set_trans(Tween.TRANS_QUAD)
		press_tween.tween_property(self, "scale", Vector2(1.06, 1.06) if is_selected else Vector2(1.04, 1.04), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card_clicked.emit(self)
