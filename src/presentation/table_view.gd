class_name TableView
extends Control

## TableView: Primary gameplay scene for Fours.
## Bridges the headless GameEngine, BotControllers, AudioManager, and 2P/3P/4P table layouts.

const AudioManager = preload("res://src/presentation/audio_manager.gd")
const OpponentView = preload("res://src/presentation/opponent_view.gd")
const CardView = preload("res://src/presentation/card_view.gd")
const GameOverModal = preload("res://src/presentation/game_over_modal.gd")
const BurnVFX = preload("res://src/presentation/burn_vfx.gd")
const SwapOverlay = preload("res://src/presentation/swap_overlay.gd")

@onready var swap_overlay: SwapOverlay = $SwapOverlay
@onready var play_button: Button = $ActionBar/PlayButton
@onready var pickup_button: Button = $ActionBar/PickupButton
@onready var restart_button: Button = $HeaderBar/RestartButton
@onready var mute_button: Button = $HeaderBar/MuteButton
@onready var menu_button: Button = $HeaderBar/MenuButton
@onready var btn_2p: Button = $HeaderBar/PlayerCountBox/Btn2P
@onready var btn_3p: Button = $HeaderBar/PlayerCountBox/Btn3P
@onready var btn_4p: Button = $HeaderBar/PlayerCountBox/Btn4P

@onready var notification_banner: Panel = $NotificationBanner
@onready var announcement_label: Label = $NotificationBanner/AnnouncementLabel
@onready var burn_vfx: BurnVFX = $BurnVFX
@onready var game_over_modal: GameOverModal = $GameOverModal

# Opponents
@onready var opp_top: OpponentView = $OpponentsContainer/OpponentTop
@onready var opp_left: OpponentView = $OpponentsContainer/OpponentLeft
@onready var opp_right: OpponentView = $OpponentsContainer/OpponentRight

# Center Pile Nodes
@onready var draw_pile_view: Control = $CenterArea/DrawPileContainer
@onready var draw_count_label: Label = $CenterArea/DrawPileContainer/DrawCountLabel
@onready var ground_container: Control = $CenterArea/GroundPileContainer
@onready var ground_count_label: Label = $CenterArea/GroundPileContainer/GroundCountLabel
@onready var combo_badge: Label = $CenterArea/GroundPileContainer/ComboBadge
@onready var graveyard_view: Control = $CenterArea/GraveyardContainer
@onready var graveyard_count_label: Label = $CenterArea/GraveyardContainer/GraveyardCountLabel
@onready var animation_layer: Control = $AnimationLayer
@onready var multiplayer_btn: Button = $HeaderBar/MultiplayerButton
@onready var multiplayer_modal: MultiplayerModalClass = $MultiplayerModal

# Human Player Nodes
@onready var player_area: VBoxContainer = $PlayerArea
@onready var player_turn_badge: PanelContainer = $PlayerArea/PlayerTurnBadge
@onready var player_table_container: HBoxContainer = $PlayerArea/TableCardsContainer
@onready var player_hand_container: HBoxContainer = $PlayerArea/HandScroll/HandCardsContainer

var card_scene: PackedScene = preload("res://src/presentation/card_view.tscn")
const NetworkManagerClass = preload("res://src/network/network_manager.gd")
const MultiplayerModalClass = preload("res://src/presentation/multiplayer_modal.gd")

var engine: GameEngine
var bot_controllers: Dictionary = {} # id -> BotController
var audio_manager: AudioManager
var network_manager: NetworkManagerClass

var local_player_id: int = 0
var is_multiplayer_client: bool = false

# Selection state for Human player
var selected_hand_indices: Array[int] = []
var selected_swap_hand_idx: int = -1
var selected_swap_table_idx: int = -1

var match_turns: int = 0
var current_player_count: int = 2
var _original_position: Vector2

func _ready() -> void:
	DisplayServer.window_move_to_foreground()
	_original_position = position
	
	if animation_layer == null:
		animation_layer = get_node_or_null("AnimationLayer")
	if animation_layer == null:
		animation_layer = Control.new()
		animation_layer.name = "AnimationLayer"
		animation_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		animation_layer.z_index = 20
		animation_layer.name = "AnimationLayer"
		add_child(animation_layer)
	
	# Instantiate AudioManager with explicit node name for network consistency
	audio_manager = AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)
	
	# Use autoload GameNetwork if present, or instantiate locally as fallback
	network_manager = get_node_or_null("/root/GameNetwork")
	if network_manager == null:
		network_manager = NetworkManager.new()
		network_manager.name = "NetworkManager"
		add_child(network_manager)
	
	_connect_client_network_signals()
	
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	
	if multiplayer_btn:
		multiplayer_btn.pressed.connect(func() -> void:
			audio_manager.play_click()
			if notification_banner:
				notification_banner.visible = false
			multiplayer_modal.open()
		)
	
	if multiplayer_modal:
		multiplayer_modal.host_match_requested.connect(_on_host_match_requested)
		multiplayer_modal.join_match_requested.connect(_on_join_match_requested)
		multiplayer_modal.start_game_requested.connect(_on_multiplayer_start_game_requested)
	
	if not network_manager.host_started.is_connected(_on_net_host_started):
		network_manager.host_started.connect(_on_net_host_started)
	if not network_manager.lobby_updated.is_connected(_on_net_lobby_updated):
		network_manager.lobby_updated.connect(_on_net_lobby_updated)
	if not network_manager.connection_succeeded.is_connected(_on_net_connection_succeeded):
		network_manager.connection_succeeded.connect(_on_net_connection_succeeded)
	if not network_manager.connection_failed.is_connected(_on_net_connection_failed):
		network_manager.connection_failed.connect(_on_net_connection_failed)
	if not network_manager.server_disconnected.is_connected(_on_net_server_disconnected):
		network_manager.server_disconnected.connect(_on_net_server_disconnected)
	
	play_button.pressed.connect(_on_play_button_pressed)
	pickup_button.pressed.connect(_on_pickup_button_pressed)
	restart_button.pressed.connect(func() -> void:
		audio_manager.play_click()
		start_new_match()
	)
	
	mute_button.pressed.connect(_on_mute_pressed)
	btn_2p.pressed.connect(func() -> void: _set_player_count(2))
	btn_3p.pressed.connect(func() -> void: _set_player_count(3))
	btn_4p.pressed.connect(func() -> void: _set_player_count(4))
	
	swap_overlay.ready_toggled.connect(_on_swap_ready_toggled)
	game_over_modal.play_again_requested.connect(func() -> void:
		audio_manager.play_click()
		if is_multiplayer_client or (network_manager != null and network_manager.is_network_active):
			_on_menu_pressed()
		else:
			start_new_match()
	)
	
	_update_player_count_buttons()
	
	if player_turn_badge:
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.82, 0.12, 1.0)
		badge_style.set_corner_radius_all(8)
		badge_style.content_margin_left = 10
		badge_style.content_margin_right = 10
		badge_style.content_margin_top = 2
		badge_style.content_margin_bottom = 2
		player_turn_badge.add_theme_stylebox_override("panel", badge_style)
	
	if network_manager != null and network_manager.pending_game_mode == "MULTIPLAYER":
		if network_manager.is_server():
			_setup_host_session()
		else:
			_setup_client_session()
	else:
		if network_manager != null:
			current_player_count = network_manager.pending_player_count
			_update_player_count_buttons()
		start_new_match()

func _process(delta: float) -> void:
	if engine != null and engine.state.phase == GameState.GamePhase.SWAP_PHASE:
		if not is_multiplayer_client:
			engine.tick_swap_timer(delta)

func _on_menu_pressed() -> void:
	audio_manager.play_click()
	if network_manager != null and network_manager.is_network_active:
		network_manager.disconnect_game()
	get_tree().change_scene_to_file("res://src/presentation/main_menu.tscn")

func _set_player_count(count: int) -> void:
	audio_manager.play_click()
	current_player_count = count
	_update_player_count_buttons()
	
	if player_turn_badge:
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.82, 0.12, 1.0)
		badge_style.set_corner_radius_all(8)
		badge_style.content_margin_left = 10
		badge_style.content_margin_right = 10
		badge_style.content_margin_top = 2
		badge_style.content_margin_bottom = 2
		player_turn_badge.add_theme_stylebox_override("panel", badge_style)
	
	start_new_match()

func _update_player_count_buttons() -> void:
	btn_2p.text = "● 2P" if current_player_count == 2 else "2P"
	btn_3p.text = "● 3P" if current_player_count == 3 else "3P"
	btn_4p.text = "● 4P" if current_player_count == 4 else "4P"
	
	btn_2p.modulate = Color(1.0, 0.85, 0.2) if current_player_count == 2 else Color(0.8, 0.8, 0.8)
	btn_3p.modulate = Color(1.0, 0.85, 0.2) if current_player_count == 3 else Color(0.8, 0.8, 0.8)
	btn_4p.modulate = Color(1.0, 0.85, 0.2) if current_player_count == 4 else Color(0.8, 0.8, 0.8)

func _on_mute_pressed() -> void:
	audio_manager.is_muted = not audio_manager.is_muted
	mute_button.text = "🔇 Muted" if audio_manager.is_muted else "🔊 Sound"

func _connect_engine_signals() -> void:
	if engine == null:
		return
	engine.cards_dealt.connect(_on_cards_dealt)
	engine.swap_phase_started.connect(_on_swap_phase_started)
	engine.swap_time_updated.connect(_on_swap_time_updated)
	engine.swap_phase_ended.connect(_on_swap_phase_ended)
	engine.card_swapped.connect(_on_card_swapped)
	engine.player_ready_changed.connect(_on_player_ready_changed)
	engine.turn_started.connect(_on_turn_started)
	engine.cards_played.connect(_on_cards_played)
	engine.blind_card_revealed.connect(_on_blind_card_revealed)
	engine.pile_burned.connect(_on_pile_burned)
	engine.pile_collected.connect(_on_pile_collected)
	engine.cards_drawn.connect(_on_cards_drawn)
	engine.game_won.connect(_on_game_won)

func _cleanup_previous_match() -> void:
	match_turns = 0
	selected_hand_indices.clear()
	selected_swap_hand_idx = -1
	selected_swap_table_idx = -1
	game_over_modal.visible = false
	if player_turn_badge:
		player_turn_badge.visible = false
	bot_controllers.clear()
	if player_hand_container:
		for child in player_hand_container.get_children():
			child.queue_free()
	if player_table_container:
		for child in player_table_container.get_children():
			child.queue_free()
	if ground_container:
		for child in ground_container.get_children():
			if child is CardView:
				child.queue_free()

## Initializes a solo match with current_player_count (2, 3, or 4 players).
func start_new_match() -> void:
	is_multiplayer_client = false
	local_player_id = 0
	_cleanup_previous_match()
	
	engine = GameEngine.new()
	_connect_engine_signals()
	
	var configs: Array[Dictionary] = [
		{"id": 0, "name": "You", "is_bot": false}
	]
	var bot_names := ["Bot Alpha", "Bot Beta", "Bot Gamma"]
	for i in range(1, current_player_count):
		configs.append({"id": i, "name": bot_names[i - 1], "is_bot": true})
		var bot := BotController.new(i, engine, 100 + i)
		bot_controllers[i] = bot
	
	engine.setup_game(configs)

# ==========================================
# MULTIPLAYER ROOM & SYNC HANDLERS
# ==========================================

func _on_host_match_requested(port: int, player_count: int, player_name: String, fill_bots: bool) -> void:
	current_player_count = player_count
	_update_player_count_buttons()
	var err := network_manager.host_game(port, player_count, player_name, fill_bots)
	if err != OK:
		show_announcement("Error starting host: %s" % error_string(err), 3.0)

func _on_join_match_requested(address: String, port: int, player_name: String) -> void:
	var err := network_manager.join_game(address, port, player_name)
	if err != OK:
		multiplayer_modal.on_connection_failed(error_string(err))

func _on_net_host_started(port: int) -> void:
	show_announcement("Hosting room on port %d" % port, 2.5)

func _on_net_lobby_updated(peers: Array[Dictionary]) -> void:
	if multiplayer_modal:
		multiplayer_modal.update_lobby_peers(peers)

func _on_net_connection_succeeded() -> void:
	if multiplayer_modal:
		multiplayer_modal.on_connection_success()

func _on_net_connection_failed(reason: String = "Failed to connect to host.") -> void:
	if multiplayer_modal:
		multiplayer_modal.on_connection_failed(reason)

func _on_net_server_disconnected() -> void:
	show_announcement("Host disconnected. Returning to Main Menu...", 3.0)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_inside_tree():
			get_tree().change_scene_to_file("res://src/presentation/main_menu.tscn")
	)

func _setup_host_session() -> void:
	if multiplayer_modal:
		multiplayer_modal.close()
	_cleanup_previous_match()
	is_multiplayer_client = false
	local_player_id = 0
	
	if restart_button:
		restart_button.visible = false
	if btn_2p and btn_3p and btn_4p:
		btn_2p.disabled = true
		btn_3p.disabled = true
		btn_4p.disabled = true
	
	current_player_count = network_manager.pending_player_count
	_update_player_count_buttons()
	
	engine = GameEngine.new()
	network_manager.engine = engine
	_connect_engine_signals()
	
	for config in network_manager.pending_multiplayer_configs:
		if config.get("is_bot", false):
			var bot_id: int = int(config.get("id", 0))
			var bot := BotController.new(bot_id, engine, 100 + bot_id)
			bot_controllers[bot_id] = bot
	
	show_announcement("Multiplayer room active! Waiting for peers to load...", 3.0)
	network_manager.host_scene_ready_and_check()

func _on_multiplayer_start_game_requested() -> void:
	_setup_host_session()

func _setup_client_session() -> void:
	if multiplayer_modal:
		multiplayer_modal.close()
	_cleanup_previous_match()
	
	if restart_button:
		restart_button.visible = false
	if btn_2p and btn_3p and btn_4p:
		btn_2p.disabled = true
		btn_3p.disabled = true
		btn_4p.disabled = true
	
	current_player_count = network_manager.pending_player_count
	_update_player_count_buttons()
	
	is_multiplayer_client = true
	local_player_id = network_manager.pending_assigned_id
	
	# Mirrored engine for client to track local turns and state
	engine = GameEngine.new()
	for config in network_manager.pending_multiplayer_configs:
		var p := PlayerState.new(
			int(config.get("id", 0)),
			str(config.get("name", "Player")),
			bool(config.get("is_bot", false))
		)
		engine.state.players.append(p)
	
	show_announcement("Connected as Player %d. Synchronizing with Host..." % [local_player_id], 3.0)
	network_manager.notify_client_scene_ready()

func _on_network_match_started(configs: Array[Dictionary], assigned_player_id: int) -> void:
	network_manager.pending_multiplayer_configs = configs
	network_manager.pending_assigned_id = assigned_player_id
	network_manager.pending_player_count = configs.size()
	_setup_client_session()

func _on_player_ready_changed(player_id: int, is_ready: bool) -> void:
	if player_id != local_player_id and swap_overlay != null:
		var p := engine.state.get_player_by_id(player_id) if engine != null else null
		var p_name: String = p.name if p != null else ("Player %d" % player_id)
		swap_overlay.set_player_status(p_name, is_ready)

func _connect_client_network_signals() -> void:
	if network_manager == null:
		return
	
	if not network_manager.net_cards_dealt.is_connected(_on_net_cards_dealt):
		network_manager.net_cards_dealt.connect(_on_net_cards_dealt)
	if not network_manager.net_swap_phase_started.is_connected(_on_net_swap_phase_started):
		network_manager.net_swap_phase_started.connect(_on_net_swap_phase_started)
	if not network_manager.net_swap_time_updated.is_connected(_on_net_swap_time_updated):
		network_manager.net_swap_time_updated.connect(_on_net_swap_time_updated)
	if not network_manager.net_swap_phase_ended.is_connected(_on_net_swap_phase_ended):
		network_manager.net_swap_phase_ended.connect(_on_net_swap_phase_ended)
	if not network_manager.net_player_ready_changed.is_connected(_on_net_player_ready_changed):
		network_manager.net_player_ready_changed.connect(_on_net_player_ready_changed)
	if not network_manager.net_card_swapped.is_connected(_on_net_card_swapped):
		network_manager.net_card_swapped.connect(_on_net_card_swapped)
	if not network_manager.net_turn_started.is_connected(_on_net_turn_started):
		network_manager.net_turn_started.connect(_on_net_turn_started)
	if not network_manager.net_cards_played.is_connected(_on_net_cards_played):
		network_manager.net_cards_played.connect(_on_net_cards_played)
	if not network_manager.net_blind_card_revealed.is_connected(_on_net_blind_card_revealed):
		network_manager.net_blind_card_revealed.connect(_on_net_blind_card_revealed)
	if not network_manager.net_pile_burned.is_connected(_on_net_pile_burned):
		network_manager.net_pile_burned.connect(_on_net_pile_burned)
	if not network_manager.net_pile_collected.is_connected(_on_net_pile_collected):
		network_manager.net_pile_collected.connect(_on_net_pile_collected)
	if not network_manager.net_cards_drawn.is_connected(_on_net_cards_drawn):
		network_manager.net_cards_drawn.connect(_on_net_cards_drawn)
	if not network_manager.net_game_won.is_connected(_on_net_game_won):
		network_manager.net_game_won.connect(_on_net_game_won)

func _on_net_cards_dealt(players_data: Array, draw_count: int) -> void:
	if not is_multiplayer_client or engine == null:
		return
	engine.state.deck.cards.clear()
	for _i in range(draw_count):
		engine.state.deck.cards.append(CardData.new(-1))
	
	engine.state.players.clear()
	for p_dict in players_data:
		engine.state.players.append(PlayerState.from_dict(p_dict))
	
	_on_cards_dealt()

func _on_net_swap_phase_started(duration: float) -> void:
	if not is_multiplayer_client or engine == null:
		return
	engine.state.phase = GameState.GamePhase.SWAP_PHASE
	_on_swap_phase_started(duration)

func _on_net_swap_time_updated(seconds: float) -> void:
	if not is_multiplayer_client or engine == null:
		return
	_on_swap_time_updated(seconds)

func _on_net_swap_phase_ended() -> void:
	if not is_multiplayer_client or engine == null:
		return
	engine.state.phase = GameState.GamePhase.PLAYING
	_on_swap_phase_ended()

func _on_net_player_ready_changed(p_id: int, is_ready: bool) -> void:
	if not is_multiplayer_client or engine == null:
		return
	_on_player_ready_changed(p_id, is_ready)

func _on_net_card_swapped(p_id: int, h_idx: int, t_idx: int) -> void:
	if not is_multiplayer_client or engine == null:
		return
	var p := engine.state.get_player_by_id(p_id)
	if p != null and p.id == local_player_id:
		p.swap_a_and_b(h_idx, t_idx)
	_on_card_swapped(p_id, h_idx, t_idx)

func _on_net_turn_started(active_p_id: int, active_group: String) -> void:
	if not is_multiplayer_client or engine == null:
		return
	for idx in range(engine.state.players.size()):
		if engine.state.players[idx].id == active_p_id:
			engine.state.current_player_index = idx
			break
	_on_turn_started(active_p_id, active_group)

func _on_net_cards_played(p_id: int, cards: Array[CardData], active_group: String) -> void:
	if not is_multiplayer_client or engine == null:
		return
	for c in cards:
		engine.state.ground_stack.append(c)
	var p := engine.state.get_player_by_id(p_id)
	if p != null and p.id == local_player_id:
		var ranks_to_remove: Array[CardData.Rank] = []
		for c in cards:
			ranks_to_remove.append(c.rank)
		for r in ranks_to_remove:
			if active_group == "A":
				for i in range(p.group_a.size() - 1, -1, -1):
					if p.group_a[i].rank == r:
						p.group_a.remove_at(i)
						break
			elif active_group == "B":
				for i in range(p.group_b.size() - 1, -1, -1):
					if p.group_b[i].rank == r:
						p.group_b.remove_at(i)
						break
			elif active_group == "C":
				if not p.group_c.is_empty():
					p.group_c.pop_back()
	elif p != null:
		for _c in cards:
			if active_group == "A" and not p.group_a.is_empty():
				p.group_a.pop_back()
			elif active_group == "B" and not p.group_b.is_empty():
				p.group_b.pop_back()
			elif active_group == "C" and not p.group_c.is_empty():
				p.group_c.pop_back()
			elif not p.group_a.is_empty():
				p.group_a.pop_back()
			elif not p.group_b.is_empty():
				p.group_b.pop_back()
			elif not p.group_c.is_empty():
				p.group_c.pop_back()
	
	_on_cards_played(p_id, cards, active_group)

func _on_net_blind_card_revealed(p_id: int, card: CardData, is_valid: bool) -> void:
	if not is_multiplayer_client or engine == null:
		return
	if not is_valid:
		var p := engine.state.get_player_by_id(p_id)
		if p != null and not p.group_c.is_empty():
			p.group_c.pop_back()
	_on_blind_card_revealed(p_id, card, is_valid)

func _on_net_pile_burned(p_id: int, reason: String) -> void:
	if not is_multiplayer_client or engine == null:
		return
	for c in engine.state.ground_stack:
		engine.state.graveyard.append(c)
	engine.state.ground_stack.clear()
	_on_pile_burned(p_id, reason)

func _on_net_pile_collected(p_id: int, count: int) -> void:
	if not is_multiplayer_client or engine == null:
		return
	var p := engine.state.get_player_by_id(p_id)
	if p != null:
		for c in engine.state.ground_stack:
			p.group_a.append(c)
		if p.id == local_player_id:
			p.sort_hand()
	engine.state.ground_stack.clear()
	_on_pile_collected(p_id, count)

func _on_net_cards_drawn(p_id: int, count: int, drawn_cards: Array[CardData]) -> void:
	if not is_multiplayer_client or engine == null:
		return
	var p := engine.state.get_player_by_id(p_id)
	if p != null:
		if p.id == local_player_id and not drawn_cards.is_empty():
			for c in drawn_cards:
				p.group_a.append(c)
			p.sort_hand()
		else:
			for _i in range(count):
				p.group_a.append(CardData.new(-1))
	for _i in range(count):
		if not engine.state.deck.is_empty():
			engine.state.deck.cards.pop_back()
	_on_cards_drawn(p_id, count, drawn_cards)

func _on_net_game_won(winner_id: int) -> void:
	if not is_multiplayer_client or engine == null:
		return
	_on_game_won(winner_id)

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_cards_dealt() -> void:
	animate_dealing_cascade(func() -> void:
		render_all_cards()
		update_pile_counts()
	)

func _on_swap_phase_started(duration: float) -> void:
	swap_overlay.visible = true
	swap_overlay.update_time(duration)
	play_button.visible = false
	pickup_button.visible = false
	show_announcement("Strategy Phase! Click 1 Hand & 1 Table card to swap.", 3.0)
	
	# Let bots execute their swaps after a brief delay
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		for bot_id in bot_controllers.keys():
			bot_controllers[bot_id].on_swap_phase_started(duration)
			var bot_player := engine.state.get_player_by_id(bot_id)
			if bot_player != null:
				swap_overlay.set_bot_status(bot_player.name, true)
	)

func _on_swap_time_updated(seconds: float) -> void:
	swap_overlay.update_time(seconds)

func _on_swap_phase_ended() -> void:
	swap_overlay.visible = false
	play_button.visible = true
	pickup_button.visible = true
	selected_swap_hand_idx = -1
	selected_swap_table_idx = -1
	render_all_cards()

func _on_card_swapped(_player_id: int, _hand_idx: int, _table_idx: int) -> void:
	audio_manager.play_card_slide()
	render_all_cards()

func _on_turn_started(active_player_id: int, active_group: String) -> void:
	match_turns += 1
	selected_hand_indices.clear()
	render_all_cards()
	update_pile_counts()
	
	var current_player := engine.state.get_player_by_id(active_player_id)
	
	if active_player_id == local_player_id:
		# Local Player turn
		if player_turn_badge:
			player_turn_badge.visible = true
		player_area.modulate = Color(1.0, 1.0, 1.0)
		play_button.disabled = true
		pickup_button.disabled = engine.state.ground_stack.is_empty()
		
		match active_group:
			"A":
				show_announcement("⬇ YOUR TURN: Select card(s) from Hand", 2.0)
			"B":
				show_announcement("⬇ YOUR TURN: Hand empty! Select from Table (Face-Up)", 2.5)
			"C":
				show_announcement("⬇ YOUR TURN: BLIND GAMBLE! Click a Face-Down card", 3.0)
	else:
		# Other player turn (remote player or bot)
		if player_turn_badge:
			player_turn_badge.visible = false
		player_area.modulate = Color(0.68, 0.72, 0.78)
		play_button.disabled = true
		pickup_button.disabled = true
		
		var arrow: String = "⬆"
		if current_player_count == 3:
			arrow = "⬅" if active_player_id == (local_player_id + 1) % 3 else "➡"
		elif current_player_count == 4:
			if active_player_id == (local_player_id + 1) % 4: arrow = "⬅"
			elif active_player_id == (local_player_id + 2) % 4: arrow = "⬆"
			elif active_player_id == (local_player_id + 3) % 4: arrow = "➡"
		
		var p_name := current_player.name if current_player else "Opponent"
		show_announcement("%s %s is playing..." % [arrow, p_name], 1.2)
		
		# Give bot realistic thinking delay (0.9s) only if bot controller exists locally
		if bot_controllers.has(active_player_id):
			get_tree().create_timer(0.9).timeout.connect(func() -> void:
				if engine.state.phase == GameState.GamePhase.PLAYING and engine.state.get_current_player() != null and engine.state.get_current_player().id == active_player_id:
					if bot_controllers.has(active_player_id):
						bot_controllers[active_player_id].on_turn_started(active_group)
			)

func _on_cards_played(player_id: int, cards: Array[CardData], _group: String) -> void:
	var player := engine.state.get_player_by_id(player_id)
	var card_names: Array[String] = []
	for c in cards:
		card_names.append(c.get_display_name())
	
	show_announcement("%s played: %s" % [player.name, ", ".join(card_names)], 2.0)
	
	var from_pos := _get_player_play_pos(player_id)
	var to_pos := ground_container.global_position
	
	animate_cards_to_ground(cards, from_pos, to_pos, func() -> void:
		audio_manager.play_card_snap()
		render_all_cards()
		update_pile_counts()
	)

func _on_blind_card_revealed(player_id: int, card: CardData, is_valid: bool) -> void:
	var player := engine.state.get_player_by_id(player_id)
	if is_valid:
		show_announcement("🎲 %s flipped %s — SUCCESSFUL!" % [player.name, card.get_display_name()], 2.5)
	else:
		show_announcement("💥 %s flipped %s — FAILED! Must pick up pile!" % [player.name, card.get_display_name()], 3.0)

func _on_pile_burned(player_id: int, reason: String) -> void:
	var player := engine.state.get_player_by_id(player_id)
	var reason_text := "10 PLAYED" if reason == "TEN_PLAYED" else "4-OF-A-KIND"
	audio_manager.play_burn_boom()
	shake_screen(12.0, 0.4)
	burn_vfx.play_burn_effect(reason_text)
	show_announcement("🔥 PILE BURNED! (%s) %s plays again!" % [reason_text, player.name], 3.0)
	
	var from_pos := ground_container.global_position
	var to_pos := graveyard_view.global_position if graveyard_view else (from_pos + Vector2(180, 0))
	
	animate_burn_cards(from_pos, to_pos, func() -> void:
		render_all_cards()
		update_pile_counts()
	)

func _on_pile_collected(player_id: int, count: int) -> void:
	var player := engine.state.get_player_by_id(player_id)
	show_announcement("📥 %s picked up %d cards from the ground!" % [player.name, count], 2.5)
	
	var from_pos := ground_container.global_position
	var to_pos := _get_player_global_pos(player_id)
	
	animate_pickup_stack(from_pos, to_pos, count, func() -> void:
		audio_manager.play_pickup()
		render_all_cards()
		update_pile_counts()
	)

func _on_cards_drawn(player_id: int, count: int, _drawn: Array[CardData] = []) -> void:
	if player_id == local_player_id:
		show_announcement("Drew %d card(s) from Side Stack." % [count], 1.5)
	
	var from_pos := draw_pile_view.global_position
	var to_pos := _get_player_global_pos(player_id)
	
	animate_draw_cards(from_pos, to_pos, count, func() -> void:
		audio_manager.play_card_slide()
		render_all_cards()
		update_pile_counts()
	)

func _on_game_won(winner_id: int) -> void:
	var winner := engine.state.get_player_by_id(winner_id)
	play_button.disabled = true
	pickup_button.disabled = true
	
	var is_player := (winner_id == local_player_id)
	if is_player:
		audio_manager.play_victory()
	else:
		audio_manager.play_defeat()
	
	game_over_modal.show_game_over(winner.name, is_player, match_turns, engine.state.graveyard_count())

# ==========================================
# CARD TWEEN & MOTION ANIMATIONS
# ==========================================

func _get_player_global_pos(player_id: int) -> Vector2:
	if player_id == local_player_id:
		if player_hand_container and is_instance_valid(player_hand_container):
			return player_hand_container.global_position + Vector2(player_hand_container.size.x * 0.5 - 42.0, 0)
		return Vector2(576, 540)
	
	if current_player_count == 2:
		if opp_top and is_instance_valid(opp_top):
			return opp_top.global_position + Vector2(opp_top.size.x * 0.5 - 34.0, 30)
	elif current_player_count == 3:
		var left_id := (local_player_id + 1) % 3
		if player_id == left_id and opp_left and is_instance_valid(opp_left):
			return opp_left.global_position + Vector2(40, opp_left.size.y * 0.5 - 30)
		elif opp_right and is_instance_valid(opp_right):
			return opp_right.global_position + Vector2(40, opp_right.size.y * 0.5 - 30)
	elif current_player_count == 4:
		var left_id := (local_player_id + 1) % 4
		var top_id := (local_player_id + 2) % 4
		if player_id == left_id and opp_left and is_instance_valid(opp_left):
			return opp_left.global_position + Vector2(40, opp_left.size.y * 0.5 - 30)
		elif player_id == top_id and opp_top and is_instance_valid(opp_top):
			return opp_top.global_position + Vector2(opp_top.size.x * 0.5 - 34.0, 30)
		elif opp_right and is_instance_valid(opp_right):
			return opp_right.global_position + Vector2(40, opp_right.size.y * 0.5 - 30)
	
	return Vector2(576, 120)

func _get_player_play_pos(player_id: int) -> Vector2:
	if player_id == local_player_id:
		for child in player_hand_container.get_children():
			if child is CardView and child.is_selected:
				return child.global_position
		for slot in player_table_container.get_children():
			for child in slot.get_children():
				if child is CardView and child.is_selected:
					return child.global_position
		return _get_player_global_pos(local_player_id)
	return _get_player_global_pos(player_id)

func animate_cards_to_ground(cards: Array[CardData], from_pos: Vector2, to_pos: Vector2, on_complete: Callable) -> void:
	if not is_inside_tree() or cards.is_empty() or animation_layer == null:
		on_complete.call()
		return
	
	var total_cards := cards.size()
	var completed_count := 0
	
	audio_manager.play_card_slide()
	
	for i in range(total_cards):
		var ghost := card_scene.instantiate() as CardView
		animation_layer.add_child(ghost)
		ghost.set_card(cards[i], true, "GHOST", 0)
		ghost.is_interactive = false
		
		var spread_offset := Vector2((i - (total_cards - 1) * 0.5) * 16.0, (i - (total_cards - 1) * 0.5) * 4.0)
		ghost.global_position = from_pos + spread_offset
		ghost.scale = Vector2(0.92, 0.92)
		ghost.rotation_degrees = randf_range(-5.0, 5.0)
		
		var target_rot := randf_range(-3.5, 3.5)
		var delay: float = i * 0.04
		
		var tween := create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		
		tween.set_parallel(true)
		tween.tween_property(ghost, "global_position", to_pos + spread_offset * 0.35, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "rotation_degrees", target_rot, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		var scale_tween := create_tween()
		if delay > 0.0:
			scale_tween.tween_interval(delay)
		scale_tween.tween_property(ghost, "scale", Vector2(1.12, 1.12), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(ghost, "scale", Vector2(1.0, 1.0), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		tween.finished.connect(func() -> void:
			if is_instance_valid(ghost):
				ghost.queue_free()
			completed_count += 1
			if completed_count == total_cards:
				on_complete.call()
		)

func animate_pickup_stack(from_pos: Vector2, to_pos: Vector2, count: int, on_complete: Callable) -> void:
	if not is_inside_tree() or animation_layer == null or count <= 0:
		on_complete.call()
		return
	
	var num_visual := mini(count, 3)
	var completed := 0
	
	for i in range(num_visual):
		var ghost := card_scene.instantiate() as CardView
		animation_layer.add_child(ghost)
		ghost.set_card(null, false, "GHOST", 0)
		ghost.is_interactive = false
		ghost.global_position = from_pos + Vector2(i * 3.0, i * 3.0)
		ghost.scale = Vector2(1.0, 1.0)
		
		var delay: float = i * 0.04
		var tween := create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		
		tween.set_parallel(true)
		tween.tween_property(ghost, "global_position", to_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(ghost, "scale", Vector2(0.5, 0.5), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.28)
		
		tween.finished.connect(func() -> void:
			if is_instance_valid(ghost):
				ghost.queue_free()
			completed += 1
			if completed == num_visual:
				on_complete.call()
		)

func animate_burn_cards(from_pos: Vector2, to_pos: Vector2, on_complete: Callable) -> void:
	if not is_inside_tree() or animation_layer == null:
		on_complete.call()
		return
	
	var ghost := card_scene.instantiate() as CardView
	animation_layer.add_child(ghost)
	ghost.set_card(null, false, "GHOST", 0)
	ghost.is_interactive = false
	ghost.global_position = from_pos
	ghost.modulate = Color(2.4, 1.3, 0.4, 1.0)
	ghost.scale = Vector2(1.15, 1.15)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "global_position", to_pos, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "rotation_degrees", 35.0, 0.26)
	tween.tween_property(ghost, "scale", Vector2(0.35, 0.35), 0.26)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.26)
	
	tween.finished.connect(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
		on_complete.call()
	)

func animate_draw_cards(from_pos: Vector2, to_pos: Vector2, count: int, on_complete: Callable) -> void:
	if not is_inside_tree() or count <= 0 or animation_layer == null:
		on_complete.call()
		return
	
	var num_visual := mini(count, 4)
	var completed := 0
	
	for i in range(num_visual):
		var ghost := card_scene.instantiate() as CardView
		animation_layer.add_child(ghost)
		ghost.set_card(null, false, "GHOST", 0)
		ghost.is_interactive = false
		ghost.global_position = from_pos
		ghost.scale = Vector2(0.85, 0.85)
		
		var delay: float = i * 0.06
		var tween := create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		
		tween.set_parallel(true)
		tween.tween_property(ghost, "global_position", to_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "scale", Vector2(1.0, 1.0), 0.24)
		
		tween.finished.connect(func() -> void:
			if is_instance_valid(ghost):
				ghost.queue_free()
			completed += 1
			if completed == num_visual:
				on_complete.call()
		)

func animate_dealing_cascade(on_complete: Callable) -> void:
	if not is_inside_tree() or animation_layer == null:
		on_complete.call()
		return
	
	var from_pos := draw_pile_view.global_position
	var targets: Array[Vector2] = []
	for i in range(current_player_count):
		targets.append(_get_player_global_pos(i))
	
	var total_cards := targets.size() * 3
	if targets.is_empty() or total_cards <= 0:
		on_complete.call()
		return
	
	var finished_count := 0
	
	audio_manager.play_card_slide()
	
	for round_idx in range(3):
		for p_idx in range(targets.size()):
			var ghost := card_scene.instantiate() as CardView
			animation_layer.add_child(ghost)
			ghost.set_card(null, false, "GHOST", 0)
			ghost.is_interactive = false
			ghost.global_position = from_pos
			ghost.scale = Vector2(0.8, 0.8)
			
			var delay: float = (round_idx * targets.size() + p_idx) * 0.035
			var tween := create_tween()
			if delay > 0.0:
				tween.tween_interval(delay)
			
			tween.set_parallel(true)
			tween.tween_property(ghost, "global_position", targets[p_idx], 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(ghost, "scale", Vector2(1.0, 1.0), 0.20)
			
			tween.finished.connect(func() -> void:
				if is_instance_valid(ghost):
					ghost.queue_free()
				finished_count += 1
				if finished_count == total_cards:
					on_complete.call()
			)

# ==========================================
# CARD RENDERING & UI UPDATES
# ==========================================

func render_all_cards() -> void:
	if engine == null or engine.state.players.is_empty():
		return
	
	var human: PlayerState = engine.state.get_player_by_id(local_player_id)
	if human == null:
		return
	
	# Render Opponents based on current_player_count
	_render_opponents()
	
	# Render Human Player Table
	_render_table_group(player_table_container, human, true)
	
	# Render Human Player Hand
	_render_player_hand(human)
	
	# Update Ground Pile View
	_render_ground_pile()

func _render_opponents() -> void:
	if engine == null or engine.state.players.is_empty():
		return
	var active_p := engine.state.get_current_player()
	var active_id: int = active_p.id if active_p != null else -1
	
	if current_player_count == 2:
		opp_top.visible = true
		opp_left.visible = false
		opp_right.visible = false
		var opp_id := (local_player_id + 1) % 2
		var opp := engine.state.get_player_by_id(opp_id)
		if opp != null:
			opp_top.update_opponent(opp, active_id == opp_id)
	elif current_player_count == 3:
		opp_top.visible = false
		opp_left.visible = true
		opp_right.visible = true
		var left_id := (local_player_id + 1) % 3
		var right_id := (local_player_id + 2) % 3
		var p_left := engine.state.get_player_by_id(left_id)
		var p_right := engine.state.get_player_by_id(right_id)
		if p_left != null:
			opp_left.update_opponent(p_left, active_id == left_id)
		if p_right != null:
			opp_right.update_opponent(p_right, active_id == right_id)
	elif current_player_count == 4:
		opp_left.visible = true
		opp_top.visible = true
		opp_right.visible = true
		var left_id := (local_player_id + 1) % 4
		var top_id := (local_player_id + 2) % 4
		var right_id := (local_player_id + 3) % 4
		var p_left := engine.state.get_player_by_id(left_id)
		var p_top := engine.state.get_player_by_id(top_id)
		var p_right := engine.state.get_player_by_id(right_id)
		if p_left != null:
			opp_left.update_opponent(p_left, active_id == left_id)
		if p_top != null:
			opp_top.update_opponent(p_top, active_id == top_id)
		if p_right != null:
			opp_right.update_opponent(p_right, active_id == right_id)

func _render_table_group(container: HBoxContainer, player: PlayerState, is_human: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	
	var max_slots: int = maxi(player.group_c.size(), player.group_b.size())
	for i in range(max_slots):
		var slot_box := Control.new()
		slot_box.custom_minimum_size = Vector2(84, 142)
		container.add_child(slot_box)
		
		# Group C (Face down, top)
		if i < player.group_c.size():
			var c_card := card_scene.instantiate() as CardView
			slot_box.add_child(c_card)
			c_card.position = Vector2(0, 0)
			c_card.set_card(player.group_c[i], false, "C", i)
			var is_my_turn := (engine.state.get_current_player() != null and engine.state.get_current_player().id == local_player_id)
			c_card.is_interactive = is_human and is_my_turn and (engine.state.phase == GameState.GamePhase.PLAYING) and (player.get_active_group_name() == "C")
			c_card.card_clicked.connect(_on_table_card_clicked)
		
		# Group B (Face up, shifted 22px down for peek)
		if i < player.group_b.size():
			var b_card := card_scene.instantiate() as CardView
			slot_box.add_child(b_card)
			b_card.position = Vector2(0, 22)
			b_card.set_card(player.group_b[i], true, "B", i)
			
			if is_human:
				var is_my_turn := (engine.state.get_current_player() != null and engine.state.get_current_player().id == local_player_id)
				var is_swap_phase := engine.state.phase == GameState.GamePhase.SWAP_PHASE
				var is_active_b := is_my_turn and (engine.state.phase == GameState.GamePhase.PLAYING) and (player.get_active_group_name() == "B")
				b_card.is_interactive = is_swap_phase or is_active_b
				b_card.set_selected(selected_swap_table_idx == i or selected_hand_indices.has(i))
				b_card.card_clicked.connect(_on_table_card_clicked)
			else:
				b_card.is_interactive = false

func _render_player_hand(player: PlayerState) -> void:
	for child in player_hand_container.get_children():
		child.queue_free()
	
	var is_my_turn := (engine.state.get_current_player() != null and engine.state.get_current_player().id == local_player_id)
	var is_human_turn := (engine.state.phase == GameState.GamePhase.PLAYING) and is_my_turn and (player.get_active_group_name() == "A")
	var is_swap := engine.state.phase == GameState.GamePhase.SWAP_PHASE
	
	for i in range(player.group_a.size()):
		var card := card_scene.instantiate() as CardView
		player_hand_container.add_child(card)
		card.set_card(player.group_a[i], true, "A", i)
		card.is_interactive = is_human_turn or is_swap
		
		var is_sel: bool = selected_hand_indices.has(i) or (selected_swap_hand_idx == i)
		card.set_selected(is_sel)
		card.card_clicked.connect(_on_hand_card_clicked)
		
		if not is_sel:
			card.modulate.a = 0.0
			card.scale = Vector2(0.95, 0.95)
			var enter_tween := card.create_tween()
			enter_tween.set_parallel(true)
			enter_tween.tween_property(card, "modulate:a", 1.0, 0.12)
			enter_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _render_ground_pile() -> void:
	for child in ground_container.get_children():
		if child is CardView:
			child.queue_free()
	
	var placeholder := ground_container.get_node_or_null("EmptyPlaceholder")
	var top_card := engine.state.get_top_ground_card()
	if top_card != null:
		if placeholder != null:
			placeholder.visible = false
		var top_view := card_scene.instantiate() as CardView
		ground_container.add_child(top_view)
		top_view.set_card(top_card, true, "GROUND", 0)
		top_view.is_interactive = false
		top_view.position = Vector2(0, 0)
		top_view.pivot_offset = Vector2(42, 60)
		top_view.rotation_degrees = randf_range(-2.5, 2.5)
	else:
		if placeholder != null:
			placeholder.visible = true

func update_pile_counts() -> void:
	if engine == null or engine.state == null:
		return
	if not is_instance_valid(draw_count_label) or not is_instance_valid(ground_count_label) or not is_instance_valid(graveyard_count_label):
		return
	draw_count_label.text = "Draw: %d" % [engine.state.draw_pile_count()]
	ground_count_label.text = "Ground: %d" % [engine.state.ground_count()]
	graveyard_count_label.text = "Burned: %d" % [engine.state.graveyard_count()]
	
	# Combo badge for 4-of-a-kind progress
	if not is_instance_valid(combo_badge):
		return
	var ground: Array[CardData] = engine.state.ground_stack
	if not ground.is_empty():
		var top_card: CardData = ground.back()
		var top_rank: CardData.Rank = top_card.rank
		var count: int = 0
		for i in range(ground.size() - 1, -1, -1):
			if ground[i].rank == top_rank:
				count += 1
			else:
				break
		if count > 1:
			combo_badge.text = "%s x%d" % [top_card.get_rank_str(), count]
			combo_badge.visible = true
		else:
			combo_badge.visible = false
	else:
		combo_badge.visible = false

# ==========================================
# USER INPUT HANDLING
# ==========================================

func _on_hand_card_clicked(card_view: CardView) -> void:
	audio_manager.play_click()
	if engine.state.phase == GameState.GamePhase.SWAP_PHASE:
		selected_swap_hand_idx = card_view.group_index
		render_all_cards()
		_attempt_swap()
		return
	
	var is_my_turn := (engine.state.get_current_player() != null and engine.state.get_current_player().id == local_player_id)
	if engine.state.phase != GameState.GamePhase.PLAYING or not is_my_turn:
		return
	
	var human := engine.state.get_player_by_id(local_player_id)
	if human == null:
		return
	
	var idx := card_view.group_index
	if selected_hand_indices.has(idx):
		selected_hand_indices.erase(idx)
	else:
		if not selected_hand_indices.is_empty():
			var first_selected_card: CardData = human.group_a[selected_hand_indices[0]]
			if card_view.data.rank != first_selected_card.rank:
				selected_hand_indices.clear()
		selected_hand_indices.append(idx)
	
	render_all_cards()
	_update_play_button_state()

func _on_table_card_clicked(card_view: CardView) -> void:
	audio_manager.play_click()
	if engine.state.phase == GameState.GamePhase.SWAP_PHASE:
		selected_swap_table_idx = card_view.group_index
		render_all_cards()
		_attempt_swap()
		return
	
	var is_my_turn := (engine.state.get_current_player() != null and engine.state.get_current_player().id == local_player_id)
	if engine.state.phase != GameState.GamePhase.PLAYING or not is_my_turn:
		return
	
	var player := engine.state.get_player_by_id(local_player_id)
	if player == null:
		return
	var active_group := player.get_active_group_name()
	
	if active_group == "C":
		if is_multiplayer_client:
			network_manager.request_blind_flip(card_view.group_index)
		else:
			engine.play_blind_card(local_player_id, card_view.group_index)
	elif active_group == "B":
		var idx := card_view.group_index
		if selected_hand_indices.has(idx):
			selected_hand_indices.erase(idx)
		else:
			if not selected_hand_indices.is_empty():
				var first_selected_card: CardData = player.group_b[selected_hand_indices[0]]
				if card_view.data.rank != first_selected_card.rank:
					selected_hand_indices.clear()
			selected_hand_indices.append(idx)
		render_all_cards()
		_update_play_button_state()

func _attempt_swap() -> void:
	if selected_swap_hand_idx != -1 and selected_swap_table_idx != -1:
		if is_multiplayer_client:
			network_manager.request_swap(selected_swap_hand_idx, selected_swap_table_idx)
		else:
			engine.swap_cards(local_player_id, selected_swap_hand_idx, selected_swap_table_idx)
		selected_swap_hand_idx = -1
		selected_swap_table_idx = -1
		render_all_cards()

func _update_play_button_state() -> void:
	if selected_hand_indices.is_empty():
		play_button.disabled = true
		return
	
	var player := engine.state.get_player_by_id(local_player_id)
	if player == null:
		play_button.disabled = true
		return
	var active_group := player.get_active_group_name()
	var source: Array[CardData] = player.group_a if active_group == "A" else player.group_b
	
	var cards_to_check: Array[CardData] = []
	for idx in selected_hand_indices:
		if idx < source.size():
			cards_to_check.append(source[idx])
	
	var validation := GameRules.validate_play(cards_to_check, engine.state.ground_stack)
	play_button.disabled = not validation.valid

func _on_play_button_pressed() -> void:
	if selected_hand_indices.is_empty():
		return
	var play_indices := selected_hand_indices.duplicate()
	selected_hand_indices.clear()
	if is_multiplayer_client:
		network_manager.request_play_cards(play_indices)
	else:
		engine.play_cards(local_player_id, play_indices)

func _on_pickup_button_pressed() -> void:
	selected_hand_indices.clear()
	if is_multiplayer_client:
		network_manager.request_pickup()
	else:
		engine.pick_up_ground(local_player_id)

func _on_swap_ready_toggled(ready: bool) -> void:
	audio_manager.play_click()
	if is_multiplayer_client:
		network_manager.request_player_ready(ready)
	else:
		engine.set_player_ready(local_player_id, ready)

func show_announcement(msg: String, duration: float = 2.5) -> void:
	if notification_banner == null or announcement_label == null:
		return
	if multiplayer_modal != null and multiplayer_modal.visible:
		return
	announcement_label.text = msg
	notification_banner.visible = true
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func() -> void:
		if announcement_label.text == msg:
			notification_banner.visible = false
	)

func shake_screen(intensity: float = 8.0, duration: float = 0.35) -> void:
	var tween := create_tween()
	var steps: int = 6
	var step_time: float = duration / float(steps)
	for i in range(steps):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "position", _original_position + offset, step_time)
	tween.tween_property(self, "position", _original_position, step_time)
