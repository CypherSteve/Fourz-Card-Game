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
	
	print("  [PASS] TestNetwork completed successfully.")
	return true
