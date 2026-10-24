class_name TestEngine
extends RefCounted

static func run() -> bool:
	print("--- Running TestEngine ---")
	
	var engine := GameEngine.new()
	var player_configs: Array[Dictionary] = [
		{"id": 0, "name": "Player 1", "is_bot": false},
		{"id": 1, "name": "Player 2", "is_bot": true}
	]
	
	# Test 1: Setup and dealing
	engine.setup_game(player_configs, 12345)
	assert(engine.state.players.size() == 2, "Should have 2 players.")
	assert(engine.state.deck.count() == 104 - 24, "Deck should have 80 cards remaining after dealing 12 to each player.")
	for p in engine.state.players:
		assert(p.group_a.size() == 4, "Group A should have 4 cards.")
		assert(p.group_b.size() == 4, "Group B should have 4 cards.")
		assert(p.group_c.size() == 4, "Group C should have 4 cards.")
	
	# Test 2: Swap phase
	assert(engine.state.phase == GameState.GamePhase.SWAP_PHASE, "Should start in SWAP_PHASE.")
	var p0 := engine.state.players[0]
	var old_hand_0: CardData = p0.group_a[0]
	var old_table_0: CardData = p0.group_b[0]
	
	var swap_ok := engine.swap_cards(0, 0, 0)
	assert(swap_ok, "Swap should succeed.")
	assert(p0.group_a[0] == old_table_0, "Hand should now contain old table card.")
	assert(p0.group_b[0] == old_hand_0, "Table should now contain old hand card.")
	
	# Both players ready ends swap phase immediately
	engine.set_player_ready(0, true)
	engine.set_player_ready(1, true)
	assert(engine.state.phase == GameState.GamePhase.PLAYING, "Game should advance to PLAYING phase after both ready.")
	
	# Test 3: Playing and Hand Refill
	var current_player := engine.state.get_current_player()
	var starter_id := current_player.id
	
	# Force a valid card into starter's hand for testing
	current_player.group_a[0] = CardData.new(999, CardData.Rank.EIGHT, CardData.Suit.SPADES)
	var play_res := engine.play_cards(starter_id, [0])
	assert(play_res.success, "Valid play should succeed.")
	assert(engine.state.ground_count() == 1, "Ground should have 1 card.")
	assert(current_player.group_a.size() == 4, "Hand should have refilled from draw pile back to 4 cards.")
	assert(engine.state.deck.count() == 79, "Deck should have 79 cards after 1 refill.")
	
	# Turn should have advanced to other player
	assert(engine.state.get_current_player().id != starter_id, "Turn should advance to opponent.")
	
	# Test 4: Pickup rule — picker starts new stack!
	var next_player := engine.state.get_current_player()
	var next_id := next_player.id
	var initial_hand_size := next_player.group_a.size()
	
	var pickup_res := engine.pick_up_ground(next_id)
	assert(pickup_res.success, "Pickup should succeed.")
	assert(engine.state.ground_count() == 0, "Ground should be empty after pickup.")
	assert(next_player.group_a.size() == initial_hand_size + 1, "Hand size should increase by picked cards.")
	assert(engine.state.get_current_player().id == next_id, "Picker must start the new stack (retains turn)!")
	
	# Test 5: Win Condition
	next_player.group_a.clear()
	next_player.group_b.clear()
	next_player.group_c.clear()
	assert(next_player.has_won(), "Player with 0 cards should have won.")
	
	# Test 6: 3-Player and 4-Player setup
	var engine3 := GameEngine.new()
	engine3.setup_game([
		{"id": 0, "name": "P1"},
		{"id": 1, "name": "P2"},
		{"id": 2, "name": "P3"}
	])
	assert(engine3.state.players.size() == 3, "Should have 3 players.")
	assert(engine3.state.deck.count() == 104 - 36, "3-player deck should have 68 cards remaining.")
	
	var engine4 := GameEngine.new()
	engine4.setup_game([
		{"id": 0, "name": "P1"},
		{"id": 1, "name": "P2"},
		{"id": 2, "name": "P3"},
		{"id": 3, "name": "P4"}
	])
	assert(engine4.state.players.size() == 4, "Should have 4 players.")
	assert(engine4.state.deck.count() == 104 - 48, "4-player deck should have 56 cards remaining.")
	
	print("  [PASS] TestEngine completed successfully.")
	return true
