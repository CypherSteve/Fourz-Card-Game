class_name Deck
extends RefCounted

## Deck: Manages the 2 standard 52-card decks (104 cards total, no jokers).
## Handles creation, shuffling, and drawing for Fours.

var cards: Array[CardData] = []
var _rng: RandomNumberGenerator

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	reset_and_build()

## Rebuilds the double deck (104 cards) from scratch.
func reset_and_build() -> void:
	cards.clear()
	var card_id: int = 0
	
	# Two standard decks (deck 0 and deck 1)
	for deck_idx in range(2):
		for suit_val in CardData.Suit.values():
			for rank_val in CardData.Rank.values():
				var card := CardData.new(card_id, rank_val as CardData.Rank, suit_val as CardData.Suit, deck_idx)
				cards.append(card)
				card_id += 1

## Shuffles the cards. If seed >= 0, uses a deterministic seed for unit testing.
func shuffle(seed_val: int = -1) -> void:
	if seed_val >= 0:
		_rng.seed = seed_val
	else:
		_rng.randomize()
	
	# Fisher-Yates shuffle
	var n: int = cards.size()
	for i in range(n - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp: CardData = cards[i]
		cards[i] = cards[j]
		cards[j] = temp

## Draws a single card from the top of the deck. Returns null if empty.
func draw_card() -> CardData:
	if cards.is_empty():
		return null
	return cards.pop_back()

## Draws up to 'count' cards. Returns an array of drawn cards.
func draw_cards(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i in range(count):
		var card := draw_card()
		if card == null:
			break
		drawn.append(card)
	return drawn

func count() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()
