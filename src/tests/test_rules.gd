class_name TestRules
extends RefCounted

static func run() -> bool:
	print("--- Running TestRules ---")
	
	# Test 1: Starting player comparison (lowest card in Group A)
	var p1 := PlayerState.new(0, "Alice")
	var p2 := PlayerState.new(1, "Bob")
	
	# Alice has 3 of Diamonds, Bob has 3 of Clubs
	p1.group_a = [
		CardData.new(0, CardData.Rank.THREE, CardData.Suit.DIAMONDS),
		CardData.new(1, CardData.Rank.SEVEN, CardData.Suit.SPADES)
	]
	p2.group_a = [
		CardData.new(2, CardData.Rank.THREE, CardData.Suit.CLUBS),
		CardData.new(3, CardData.Rank.ACE, CardData.Suit.HEARTS)
	]
	
	var starter := GameRules.determine_starting_player([p1, p2])
	assert(starter == 1, "Bob with 3 of Clubs should start over Alice with 3 of Diamonds (♣ < ♦).")
	
	# Test 2: Standard move validation
	var ground: Array[CardData] = [
		CardData.new(10, CardData.Rank.SEVEN, CardData.Suit.HEARTS)
	]
	
	# Playing a 6 on top of 7 is invalid
	var low_play: Array[CardData] = [CardData.new(11, CardData.Rank.SIX, CardData.Suit.CLUBS)]
	var res1 := GameRules.validate_play(low_play, ground)
	assert(not res1.valid, "Rank 6 should not be playable on top of 7.")
	
	# Playing a 7 or 8 on top of 7 is valid
	var equal_play: Array[CardData] = [CardData.new(12, CardData.Rank.SEVEN, CardData.Suit.SPADES)]
	var res2 := GameRules.validate_play(equal_play, ground)
	assert(res2.valid, "Rank 7 should be playable on top of 7.")
	
	var high_play: Array[CardData] = [CardData.new(13, CardData.Rank.JACK, CardData.Suit.DIAMONDS)]
	var res3 := GameRules.validate_play(high_play, ground)
	assert(res3.valid, "Rank Jack should be playable on top of 7.")
	
	# Test 3: Multi-card plays of identical rank
	var multi_valid: Array[CardData] = [
		CardData.new(14, CardData.Rank.EIGHT, CardData.Suit.CLUBS),
		CardData.new(15, CardData.Rank.EIGHT, CardData.Suit.HEARTS)
	]
	var res_multi := GameRules.validate_play(multi_valid, ground)
	assert(res_multi.valid, "Multiple cards of same rank should be valid together.")
	
	var multi_mismatch: Array[CardData] = [
		CardData.new(16, CardData.Rank.EIGHT, CardData.Suit.CLUBS),
		CardData.new(17, CardData.Rank.NINE, CardData.Suit.HEARTS)
	]
	var res_mismatch := GameRules.validate_play(multi_mismatch, ground)
	assert(not res_mismatch.valid, "Mismatched ranks in a single play must be rejected.")
	
	# Test 4: Special card 2 (resets count to 0)
	var two_card: Array[CardData] = [CardData.new(20, CardData.Rank.TWO, CardData.Suit.CLUBS)]
	var res_two := GameRules.validate_play(two_card, [CardData.new(21, CardData.Rank.ACE, CardData.Suit.SPADES)])
	assert(res_two.valid, "2 should be playable on top of Ace.")
	
	# Ground with 2 on top has effective rank 0
	var ground_with_two: Array[CardData] = [
		CardData.new(22, CardData.Rank.KING, CardData.Suit.HEARTS),
		CardData.new(23, CardData.Rank.TWO, CardData.Suit.DIAMONDS)
	]
	assert(GameRules.get_effective_ground_rank(ground_with_two) == 0, "Top 2 must reset effective ground rank to 0.")
	var play_after_two := GameRules.validate_play([CardData.new(24, CardData.Rank.THREE, CardData.Suit.CLUBS)], ground_with_two)
	assert(play_after_two.valid, "3 should be playable on top of 2.")
	
	# Test 5: Special card 10 (burns pile)
	var ten_card: Array[CardData] = [CardData.new(30, CardData.Rank.TEN, CardData.Suit.HEARTS)]
	var ground_burn_test: Array[CardData] = [
		CardData.new(31, CardData.Rank.ACE, CardData.Suit.SPADES),
		ten_card[0]
	]
	var burn_res_10 := GameRules.check_burn(ground_burn_test)
	assert(burn_res_10.burn and burn_res_10.reason == "TEN_PLAYED", "10 on top must trigger burn.")
	
	# Test 6: Four-of-a-kind consecutive burn
	var ground_four_of_a_kind: Array[CardData] = [
		CardData.new(40, CardData.Rank.FIVE, CardData.Suit.CLUBS),
		CardData.new(41, CardData.Rank.EIGHT, CardData.Suit.CLUBS),
		CardData.new(42, CardData.Rank.EIGHT, CardData.Suit.DIAMONDS),
		CardData.new(43, CardData.Rank.EIGHT, CardData.Suit.HEARTS),
		CardData.new(44, CardData.Rank.EIGHT, CardData.Suit.SPADES)
	]
	var burn_res_4 := GameRules.check_burn(ground_four_of_a_kind)
	assert(burn_res_4.burn and burn_res_4.reason == "FOUR_OF_A_KIND", "4 consecutive 8s on top must trigger burn.")
	
	print("  [PASS] TestRules completed successfully.")
	return true
