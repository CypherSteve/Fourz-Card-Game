class_name GameEngine
extends RefCounted

## GameEngine: Central authoritative state machine for Fours.
## Completely headless with zero Node/UI dependencies.
## Emits signals for presentation layers (Godot UI, Audio, VFX) and network synchronization.

signal cards_dealt()
signal swap_phase_started(duration: float)
signal swap_time_updated(seconds_remaining: float)
signal card_swapped(player_id: int, hand_index: int, table_index: int)
signal player_ready_changed(player_id: int, is_ready: bool)
signal swap_phase_ended()
signal turn_started(player_id: int, active_group: String)
signal cards_played(player_id: int, cards: Array[CardData], group_name: String)
signal blind_card_revealed(player_id: int, card: CardData, is_valid: bool)
signal pile_burned(player_id: int, reason: String)
signal pile_collected(player_id: int, card_count: int)
signal cards_drawn(player_id: int, card_count: int)
signal game_won(winner_id: int)

var state: GameState
var _rng: RandomNumberGenerator

func _init() -> void:
	state = GameState.new()
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

## Initializes and deals a new game.
## player_configs is an Array of Dictionaries: [{"id": 0, "name": "Alice", "is_bot": false}, ...]
func setup_game(player_configs: Array[Dictionary], rng_seed: int = -1) -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	
	state.reset()
	state.phase = GameState.GamePhase.DEALING
	
	# Instantiate players
	for config in player_configs:
		var p := PlayerState.new(
			int(config.get("id", 0)),
			str(config.get("name", "Player")),
			bool(config.get("is_bot", false))
		)
		state.players.append(p)
	
	# Shuffle 104-card double deck
	state.deck.shuffle(rng_seed)
	
	# Deal 4 cards to Group C (Face-down table)
	for p in state.players:
		p.group_c = state.deck.draw_cards(4)
	
	# Deal 4 cards to Group B (Face-up table)
	for p in state.players:
		p.group_b = state.deck.draw_cards(4)
	
	# Deal 4 cards to Group A (Hand)
	for p in state.players:
		p.group_a = state.deck.draw_cards(4)
		p.sort_hand()
	
	cards_dealt.emit()
	
	# Begin the 30-second swap phase
	state.phase = GameState.GamePhase.SWAP_PHASE
	state.swap_time_remaining = 30.0
	swap_phase_started.emit(state.swap_time_remaining)

## Swaps cards between Group A (Hand) and Group B (Face-Up) during the swap phase.
func swap_cards(player_id: int, hand_index: int, table_index: int) -> bool:
	if state.phase != GameState.GamePhase.SWAP_PHASE:
		return false
	
	var player := state.get_player_by_id(player_id)
	if player == null:
		return false
	
	var success := player.swap_a_and_b(hand_index, table_index)
	if success:
		card_swapped.emit(player_id, hand_index, table_index)
	return success

## Sets whether a player has confirmed they are ready during the swap phase.
func set_player_ready(player_id: int, is_ready: bool) -> void:
	if state.phase != GameState.GamePhase.SWAP_PHASE:
		return
	
	var player := state.get_player_by_id(player_id)
	if player == null:
		return
	
	player.is_ready_swap = is_ready
	player_ready_changed.emit(player_id, is_ready)
	
	# If all players are ready, end swap phase immediately
	_check_all_ready()

func _check_all_ready() -> void:
	var all_ready: bool = true
	for p in state.players:
		if not p.is_ready_swap:
			all_ready = false
			break
	
	if all_ready and state.players.size() > 0:
		_end_swap_phase_and_start_play()

## Advances the swap phase countdown. Called each frame/tick by presentation timer.
func tick_swap_timer(delta: float) -> void:
	if state.phase != GameState.GamePhase.SWAP_PHASE:
		return
	
	state.swap_time_remaining -= delta
	swap_time_updated.emit(max(0.0, state.swap_time_remaining))
	
	if state.swap_time_remaining <= 0.0:
		_end_swap_phase_and_start_play()

func _end_swap_phase_and_start_play() -> void:
	if state.phase != GameState.GamePhase.SWAP_PHASE:
		return
	
	state.phase = GameState.GamePhase.PLAYING
	swap_phase_ended.emit()
	
	# Determine starting player (lowest card in Group A)
	state.current_player_index = GameRules.determine_starting_player(state.players, _rng)
	var starter := state.get_current_player()
	turn_started.emit(starter.id, starter.get_active_group_name())

## Plays cards from active group.
## card_indices: indices in the active group (Group A or Group B).
func play_cards(player_id: int, card_indices: Array[int]) -> Dictionary:
	if state.phase != GameState.GamePhase.PLAYING:
		return {"success": false, "reason": "Game is not in PLAYING phase."}
	
	var player := state.get_current_player()
	if player == null or player.id != player_id:
		return {"success": false, "reason": "Not your turn."}
	
	var active_group := player.get_active_group_name()
	if active_group == "NONE":
		return {"success": false, "reason": "Player has already won."}
	
	# If active group is Group C, delegate to blind play
	if active_group == "C":
		if card_indices.is_empty():
			return {"success": false, "reason": "Must select one face-down card to play."}
		return play_blind_card(player_id, card_indices[0])
	
	var source_cards: Array[CardData] = player.group_a if active_group == "A" else player.group_b
	
	# Validate indices
	if card_indices.is_empty():
		return {"success": false, "reason": "No cards selected."}
	
	# Check for duplicates or out-of-range indices
	var selected_cards: Array[CardData] = []
	var sorted_indices := card_indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse() # Reverse sort for safe removal later
	
	for idx in sorted_indices:
		if idx < 0 or idx >= source_cards.size():
			return {"success": false, "reason": "Invalid card index."}
		selected_cards.append(source_cards[idx])
	
	# Validate move against game rules
	var validation := GameRules.validate_play(selected_cards, state.ground_stack)
	if not validation.valid:
		return {"success": false, "reason": validation.reason}
	
	# Move is valid: remove cards from player's active group
	for idx in sorted_indices:
		source_cards.remove_at(idx)
	
	# Add played cards to ground stack
	for card in selected_cards:
		state.ground_stack.append(card)
	
	cards_played.emit(player_id, selected_cards, active_group)
	
	# Check for Burn (10 played, or 4+ consecutive cards of identical rank)
	var burn_info := GameRules.check_burn(state.ground_stack)
	if burn_info.burn:
		_execute_burn(player_id, burn_info.reason)
	else:
		_finish_normal_play(player)
	
	return {"success": true, "reason": "Cards played successfully."}

## Plays a blind card from Group C (face-down on table).
func play_blind_card(player_id: int, card_index: int) -> Dictionary:
	if state.phase != GameState.GamePhase.PLAYING:
		return {"success": false, "reason": "Game is not in PLAYING phase."}
	
	var player := state.get_current_player()
	if player == null or player.id != player_id:
		return {"success": false, "reason": "Not your turn."}
	
	if player.get_active_group_name() != "C":
		return {"success": false, "reason": "Must exhaust Group A and Group B before playing Group C."}
	
	if card_index < 0 or card_index >= player.group_c.size():
		return {"success": false, "reason": "Invalid Group C index."}
	
	var blind_card: CardData = player.group_c.pop_at(card_index)
	var validation := GameRules.validate_play([blind_card], state.ground_stack)
	
	if validation.valid:
		# Card is legally played!
		state.ground_stack.append(blind_card)
		blind_card_revealed.emit(player_id, blind_card, true)
		cards_played.emit(player_id, [blind_card], "C")
		
		# Check burn
		var burn_info := GameRules.check_burn(state.ground_stack)
		if burn_info.burn:
			_execute_burn(player_id, burn_info.reason)
		else:
			_finish_normal_play(player)
		
		return {"success": true, "valid_card": true, "card": blind_card}
	else:
		# Blind card failed! Player picks up the entire ground stack PLUS the failed card into Group A!
		blind_card_revealed.emit(player_id, blind_card, false)
		state.ground_stack.append(blind_card)
		
		var picked_count := state.ground_stack.size()
		for card in state.ground_stack:
			player.group_a.append(card)
		state.ground_stack.clear()
		player.sort_hand()
		
		pile_collected.emit(player_id, picked_count)
		
		# Rule: The player who picked up starts the new stack!
		turn_started.emit(player.id, player.get_active_group_name())
		return {"success": true, "valid_card": false, "card": blind_card}

## Player picks up the ground stack into hand (Group A).
func pick_up_ground(player_id: int) -> Dictionary:
	if state.phase != GameState.GamePhase.PLAYING:
		return {"success": false, "reason": "Game is not in PLAYING phase."}
	
	var player := state.get_current_player()
	if player == null or player.id != player_id:
		return {"success": false, "reason": "Not your turn."}
	
	if state.ground_stack.is_empty():
		return {"success": false, "reason": "Ground stack is already empty."}
	
	var count := state.ground_stack.size()
	for card in state.ground_stack:
		player.group_a.append(card)
	state.ground_stack.clear()
	player.sort_hand()
	
	pile_collected.emit(player_id, count)
	
	# Rule: The player who picked up starts the new stack!
	turn_started.emit(player.id, player.get_active_group_name())
	return {"success": true, "picked_up": count}

func _execute_burn(player_id: int, reason: String) -> void:
	for card in state.ground_stack:
		state.graveyard.append(card)
	state.ground_stack.clear()
	
	pile_burned.emit(player_id, reason)
	
	var player := state.get_player_by_id(player_id)
	_refill_hand_if_needed(player)
	
	# Check if player won
	if player.has_won():
		_handle_win(player)
		return
	
	# Burn privilege: The player who burned the stack plays again!
	turn_started.emit(player.id, player.get_active_group_name())

func _finish_normal_play(player: PlayerState) -> void:
	_refill_hand_if_needed(player)
	
	# Check if player won
	if player.has_won():
		_handle_win(player)
		return
	
	# Pass turn to next player
	state.advance_to_next_player()
	var next_player := state.get_current_player()
	turn_started.emit(next_player.id, next_player.get_active_group_name())

## Refills Group A from Side Stack back up to 4 cards (if draw pile has cards).
func _refill_hand_if_needed(player: PlayerState) -> void:
	if player.group_a.size() < 4 and not state.deck.is_empty():
		var needed := 4 - player.group_a.size()
		var drawn := state.deck.draw_cards(needed)
		for card in drawn:
			player.group_a.append(card)
		player.sort_hand()
		cards_drawn.emit(player.id, drawn.size())

func _handle_win(player: PlayerState) -> void:
	state.phase = GameState.GamePhase.GAME_OVER
	state.winner_id = player.id
	game_won.emit(player.id)
