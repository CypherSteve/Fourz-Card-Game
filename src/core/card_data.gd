class_name CardData
extends RefCounted

## CardData: Represents an individual playing card in Fours.
## Two standard 52-card decks are used (104 cards total, no jokers).

enum Suit {
	CLUBS = 0,     # ♣
	DIAMONDS = 1,  # ♦
	HEARTS = 2,    # ♥
	SPADES = 3     # ♠
}

enum Rank {
	TWO = 2,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	EIGHT = 8,
	NINE = 9,
	TEN = 10,
	JACK = 11,
	QUEEN = 12,
	KING = 13,
	ACE = 14
}

const SUIT_SYMBOLS: Dictionary = {
	Suit.CLUBS: "♣",
	Suit.DIAMONDS: "♦",
	Suit.HEARTS: "♥",
	Suit.SPADES: "♠"
}

const SUIT_NAMES: Dictionary = {
	Suit.CLUBS: "Clubs",
	Suit.DIAMONDS: "Diamonds",
	Suit.HEARTS: "Hearts",
	Suit.SPADES: "Spades"
}

const RANK_NAMES: Dictionary = {
	Rank.TWO: "2",
	Rank.THREE: "3",
	Rank.FOUR: "4",
	Rank.FIVE: "5",
	Rank.SIX: "6",
	Rank.SEVEN: "7",
	Rank.EIGHT: "8",
	Rank.NINE: "9",
	Rank.TEN: "10",
	Rank.JACK: "J",
	Rank.QUEEN: "Q",
	Rank.KING: "K",
	Rank.ACE: "A"
}

var id: int = -1
var rank: Rank = Rank.THREE
var suit: Suit = Suit.CLUBS
var deck_index: int = 0 # 0 for first deck, 1 for second deck

func _init(p_id: int = -1, p_rank: Rank = Rank.THREE, p_suit: Suit = Suit.CLUBS, p_deck_index: int = 0) -> void:
	id = p_id
	rank = p_rank
	suit = p_suit
	deck_index = p_deck_index

## Returns true if the card is a 2 (reset) or 10 (burn).
func is_special() -> bool:
	return rank == Rank.TWO or rank == Rank.TEN

func is_two() -> bool:
	return rank == Rank.TWO

func is_ten() -> bool:
	return rank == Rank.TEN

func get_suit_symbol() -> String:
	return SUIT_SYMBOLS.get(suit, "?")

func get_rank_str() -> String:
	return RANK_NAMES.get(rank, "?")

func get_display_name() -> String:
	return "%s%s" % [get_rank_str(), get_suit_symbol()]

func get_full_name() -> String:
	return "%s of %s (Deck %d)" % [get_rank_str(), SUIT_NAMES.get(suit, "?"), deck_index + 1]

## Compares two cards for the starting player rule:
## 1. Lowest rank (3 is lowest, Ace is highest; 2 and 10 are special)
## 2. If ranks match, suit order: Clubs < Diamonds < Hearts < Spades
## Returns -1 if self < other, 1 if self > other, 0 if identical.
func compare_starting_order(other: CardData) -> int:
	if self.rank != other.rank:
		return -1 if self.rank < other.rank else 1
	if self.suit != other.suit:
		return -1 if self.suit < other.suit else 1
	return 0

func to_dict() -> Dictionary:
	return {
		"id": id,
		"rank": rank,
		"suit": suit,
		"deck_index": deck_index
	}

static func from_dict(data: Dictionary) -> CardData:
	return CardData.new(
		int(data.get("id", -1)),
		int(data.get("rank", Rank.THREE)) as Rank,
		int(data.get("suit", Suit.CLUBS)) as Suit,
		int(data.get("deck_index", 0))
	)
