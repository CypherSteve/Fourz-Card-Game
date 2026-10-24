class_name TestBot
extends RefCounted

static func run() -> bool:
	print("--- Running TestBot ---")
	
	_test_group_b_trap()
	_test_avoid_two_against_group_b()
	_test_group_c_high_card()
	_test_four_of_a_kind_burn()
	
	# Full game simulation
	var engine := GameEngine.new()
	var player_configs: Array[Dictionary] = [
		{"id": 0, "name": "Bot Alpha", "is_bot": true},
		{"id": 1, "name": "Bot Beta", "is_bot": true}
	]
	
	engine.setup_game(player_configs, 42)
	
	var bot0 := BotController.new(0, engine, 101)
	var bot1 := BotController.new(1, engine, 102)
	
	# Connect engine signals to bots
	engine.swap_phase_started.connect(bot0.on_swap_phase_started)
	engine.swap_phase_started.connect(bot1.on_swap_phase_started)
	
	var stats := {"turn_count": 0, "is_processing": false}
	var pending_turns: Array[Dictionary] = []
	
	var process_queue = func() -> void:
		if stats["is_processing"]:
			return
		stats["is_processing"] = true
		while not pending_turns.is_empty() and engine.state.phase == GameState.GamePhase.PLAYING:
			var turn: Dictionary = pending_turns.pop_front()
			stats["turn_count"] += 1
			if stats["turn_count"] % 100 == 0:
				print("    Simulated Turn: %d (P0 cards: %d, P1 cards: %d, Deck: %d)" % [
					stats["turn_count"], 
					engine.state.players[0].total_cards(),
					engine.state.players[1].total_cards(),
					engine.state.deck.count()
				])
			if stats["turn_count"] > 1500:
				print("    Reached safety turn limit.")
				break
			if turn["player_id"] == 0:
				bot0.on_turn_started(turn["group"])
			elif turn["player_id"] == 1:
				bot1.on_turn_started(turn["group"])
		stats["is_processing"] = false
	
	engine.turn_started.connect(func(active_player_id: int, active_group: String) -> void:
		pending_turns.append({"player_id": active_player_id, "group": active_group})
		process_queue.call()
	)
	
	# Trigger swap phase for bots
	bot0.on_swap_phase_started(30.0)
	bot1.on_swap_phase_started(30.0)
	
	print("  Simulated Bot Match ended after %d total turns. Phase: %d, Winner: %d" % [
		stats["turn_count"], engine.state.phase, engine.state.winner_id
	])
	
	assert(stats["turn_count"] > 0, "Bots should successfully execute turns.")
	assert(engine.state.phase == GameState.GamePhase.GAME_OVER, "Game should finish.")
	assert(engine.state.winner_id != -1, "A winner should be declared.")
	print("  [PASS] TestBot completed successfully.")
	return true

static func _test_group_b_trap() -> void:
	print("  Testing Group B Sabotage Trap...")
	var bot := PlayerState.new(0, "Bot")
	bot.group_a = [
		CardData.new(0, CardData.Rank.EIGHT, CardData.Suit.SPADES),
		CardData.new(1, CardData.Rank.JACK, CardData.Suit.HEARTS),
		CardData.new(2, CardData.Rank.ACE, CardData.Suit.DIAMONDS)
	]
	
	var opponent := PlayerState.new(1, "Opponent")
	opponent.group_a = []
	opponent.group_b = [
		CardData.new(10, CardData.Rank.FIVE, CardData.Suit.CLUBS),
		CardData.new(11, CardData.Rank.SEVEN, CardData.Suit.HEARTS),
		CardData.new(12, CardData.Rank.NINE, CardData.Suit.SPADES)
	]
	
	var ground: Array[CardData] = [
		CardData.new(20, CardData.Rank.FOUR, CardData.Suit.CLUBS)
	]
	
	var decision := BotStrategy.choose_best_action(bot, ground, opponent)
	assert(decision.action == "PLAY", "Bot should play.")
	assert(decision.indices.size() == 1 and decision.indices[0] == 1, 
		"Bot should choose Jack (index 1, rank 11 > max 9) to trap opponent, saving Ace (index 2)!")
	print("    [PASS] Bot successfully traps Group B opponent with minimal beating card (Jack).")

static func _test_avoid_two_against_group_b() -> void:
	print("  Testing Avoid 2 Against Group B Opponent...")
	var bot := PlayerState.new(0, "Bot")
	bot.group_a = [
		CardData.new(0, CardData.Rank.TWO, CardData.Suit.SPADES),
		CardData.new(1, CardData.Rank.SIX, CardData.Suit.HEARTS)
	]
	
	var opponent := PlayerState.new(1, "Opponent")
	opponent.group_a = []
	opponent.group_b = [
		CardData.new(10, CardData.Rank.FOUR, CardData.Suit.CLUBS),
		CardData.new(11, CardData.Rank.SEVEN, CardData.Suit.SPADES)
	]
	
	var ground: Array[CardData] = []
	var decision := BotStrategy.choose_best_action(bot, ground, opponent)
	assert(decision.action == "PLAY", "Bot should play.")
	assert(decision.indices.size() == 1 and decision.indices[0] == 1, 
		"Bot should play 6 (index 1) rather than 2 (index 0) to avoid resetting ground to 0 for opponent!")
	print("    [PASS] Bot avoids playing 2 when Group B opponent would benefit from reset.")

static func _test_group_c_high_card() -> void:
	print("  Testing High Card against Group C Blind Gambler...")
	var bot := PlayerState.new(0, "Bot")
	bot.group_a = [
		CardData.new(0, CardData.Rank.FOUR, CardData.Suit.HEARTS),
		CardData.new(1, CardData.Rank.KING, CardData.Suit.SPADES)
	]
	
	var opponent := PlayerState.new(1, "Opponent")
	opponent.group_a = []
	opponent.group_b = []
	opponent.group_c = [
		CardData.new(10, CardData.Rank.FIVE, CardData.Suit.CLUBS),
		CardData.new(11, CardData.Rank.SEVEN, CardData.Suit.SPADES)
	]
	
	var ground: Array[CardData] = [
		CardData.new(20, CardData.Rank.THREE, CardData.Suit.CLUBS)
	]
	
	var decision := BotStrategy.choose_best_action(bot, ground, opponent)
	assert(decision.action == "PLAY", "Bot should play.")
	assert(decision.indices.size() == 1 and decision.indices[0] == 1, 
		"Bot should play King (index 1) against Group C blind player to maximize fail rate!")
	print("    [PASS] Bot successfully sets highest hurdle (King) against Group C player.")

static func _test_four_of_a_kind_burn() -> void:
	print("  Testing 4-of-a-Kind Burn Priority...")
	var bot := PlayerState.new(0, "Bot")
	bot.group_a = [
		CardData.new(0, CardData.Rank.SEVEN, CardData.Suit.DIAMONDS),
		CardData.new(1, CardData.Rank.SEVEN, CardData.Suit.SPADES),
		CardData.new(2, CardData.Rank.ACE, CardData.Suit.CLUBS)
	]
	
	var opponent := PlayerState.new(1, "Opponent")
	
	var ground: Array[CardData] = [
		CardData.new(20, CardData.Rank.SEVEN, CardData.Suit.CLUBS),
		CardData.new(21, CardData.Rank.SEVEN, CardData.Suit.HEARTS)
	]
	
	var decision := BotStrategy.choose_best_action(bot, ground, opponent)
	assert(decision.action == "PLAY", "Bot should play.")
	assert(decision.indices.size() == 2, "Bot should play both 7s to burn the pile!")
	print("    [PASS] Bot prioritizes 4-of-a-kind burn to clear pile and earn extra turn.")

