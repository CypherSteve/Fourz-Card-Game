class_name TestDeck
extends RefCounted

static func run() -> bool:
	print("--- Running TestDeck ---")
	var deck := Deck.new()
	
	# Test 1: 104 cards total
	assert(deck.count() == 104, "Double deck must contain 104 cards.")
	
	# Test 2: Verify 8 cards of each rank (4 suits x 2 decks)
	var rank_counts: Dictionary = {}
	var suit_counts: Dictionary = {}
	for card in deck.cards:
		rank_counts[card.rank] = rank_counts.get(card.rank, 0) + 1
		suit_counts[card.suit] = suit_counts.get(card.suit, 0) + 1
	
	for rank_val in CardData.Rank.values():
		assert(rank_counts[rank_val] == 8, "Each rank must appear exactly 8 times in 2 decks.")
	
	for suit_val in CardData.Suit.values():
		assert(suit_counts[suit_val] == 26, "Each suit must appear exactly 26 times in 2 decks.")
	
	# Test 3: Drawing cards
	var drawn := deck.draw_cards(12)
	assert(drawn.size() == 12, "Should draw exactly 12 cards.")
	assert(deck.count() == 92, "Deck count should decrease to 92.")
	
	print("  [PASS] TestDeck completed successfully.")
	return true
