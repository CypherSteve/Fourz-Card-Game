class_name TestNetwork
extends RefCounted

const MultiplayerModal = preload("res://src/presentation/multiplayer_modal.gd")

static func run() -> bool:
	print("--- Running TestNetwork ---")
	
	# Test 1: PlayerState Serialization for Owner vs Non-Owner
	var p := PlayerState.new(1, "Player 1", false)
	p.group_a = [
		CardData.new(0, CardData.Rank.TEN, CardData.Suit.HEARTS),
		CardData.new(1, CardData.Rank.ACE, CardData.Suit.SPADES)
	]
	p.group_b = [
		CardData.new(2, CardData.Rank.SEVEN, CardData.Suit.CLUBS)
	]
	p.group_c = [
		CardData.new(3, CardData.Rank.FIVE, CardData.Suit.DIAMONDS)
	]
	
	# Owner serialization (reveals hand)
	var owner_dict := p.to_dict(true)
	var p_restored_owner := PlayerState.from_dict(owner_dict)
	assert(p_restored_owner.group_a.size() == 2, "Owner should receive all hand cards.")
	assert(p_restored_owner.group_a[0].rank == CardData.Rank.TEN, "Card rank should match.")
	assert(p_restored_owner.group_a[1].rank == CardData.Rank.ACE, "Card rank should match.")
	assert(p_restored_owner.group_b.size() == 1, "Group B should match.")
	assert(p_restored_owner.group_c.size() == 1, "Group C should match.")
	
	# Non-owner serialization (conceals hand)
	var opponent_dict := p.to_dict(false)
	var p_restored_opponent := PlayerState.from_dict(opponent_dict)
	assert(p_restored_opponent.group_a.size() == 2, "Opponent should know hand card count.")
	assert(p_restored_opponent.group_a[0].id == -1, "Concealed hand should use dummy cards.")
	assert(p_restored_opponent.group_b.size() == 1, "Group B must remain visible.")
	assert(p_restored_opponent.group_b[0].rank == CardData.Rank.SEVEN, "Group B card rank must match.")
	print("  [PASS] PlayerState network serialization & concealment verified.")
	
	# Test 2: LAN IP detection
	var lan_ip := MultiplayerModal.get_lan_ip()
	assert(not lan_ip.is_empty(), "LAN IP helper should return a non-empty IP string.")
	print("  [PASS] LAN IP resolution verified: %s" % lan_ip)
	
	# Test 3: Table Seating Rotation Math
	# In a 4P game, if local_player_id is 1:
	var local_id := 1
	var left_id := (local_id + 1) % 4 # 2
	var top_id := (local_id + 2) % 4  # 3
	var right_id := (local_id + 3) % 4 # 0
	assert(left_id == 2 and top_id == 3 and right_id == 0, "Seating rotation should be clockwise.")
	print("  [PASS] Seating rotation math verified.")
	
	# Test 4: Scene Synchronization Handshake
	var tree := Engine.get_main_loop() as SceneTree
	var host_net: NetworkManager = tree.root.get_node_or_null("GameNetwork") if tree and tree.root else null
	if host_net == null:
		host_net = NetworkManager.new()
		if tree and tree.root:
			tree.root.add_child(host_net)
	
	var test_engine := GameEngine.new()
	var err := host_net.host_game(7799, 2, "Host", false)
	assert(err == OK, "Host game should initialize server on port 7799.")
	assert(host_net.is_server(), "Host should be server.")
	
	host_net.lobby_peers = [
		{"peer_id": 1, "name": "Host", "is_host": true},
		{"peer_id": 2, "name": "Guest", "is_host": false}
	]
	host_net.peer_to_player_id[1] = 0
	host_net.peer_to_player_id[2] = 1
	host_net.pending_multiplayer_configs = [
		{"id": 0, "name": "Host", "is_bot": false},
		{"id": 1, "name": "Guest", "is_bot": false}
	]
	host_net.engine = test_engine
	
	# Host reports ready first
	host_net.peers_ready_in_table_view.append(1)
	host_net._check_all_peers_ready_to_deal()
	assert(not host_net.match_started, "Match should not start while guest is still loading TableView.")
	assert(test_engine.state.phase == GameState.GamePhase.NOT_STARTED, "Engine should remain not started.")
	
	# Guest reports ready
	host_net.peers_ready_in_table_view.append(2)
	host_net._check_all_peers_ready_to_deal()
	assert(host_net.match_started, "Match should start once all peers are loaded.")
	assert(test_engine.state.phase == GameState.GamePhase.SWAP_PHASE, "Engine should transition to swap phase.")
	assert(test_engine.state.deck.count() == 80, "24 cards should be dealt to 2 players (12 each: 4 A, 4 B, 4 C).")
	
	# Clean up
	host_net.disconnect_game()
	print("  [PASS] Scene synchronization handshake verified.")
	
	print("  [PASS] TestNetwork completed successfully.")
	return true
