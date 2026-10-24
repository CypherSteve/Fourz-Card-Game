class_name PlayerState
extends RefCounted

## PlayerState: Represents a single player's complete state in Fours.
## Manages Group A (Hand), Group B (Face-Up Table), and Group C (Face-Down Table).

var id: int = 0
var name: String = "Player"
var is_bot: bool = false
var is_ready_swap: bool = false

# Card groups (each starts with 4 cards)
var group_a: Array[CardData] = [] # Hand (Private)
var group_b: Array[CardData] = [] # Face-Up (Public Table)
var group_c: Array[CardData] = [] # Face-Down (Hidden Table)

func _init(p_id: int = 0, p_name: String = "Player", p_is_bot: bool = false) -> void:
	id = p_id
	name = p_name
	is_bot = p_is_bot
	reset()

func reset() -> void:
	group_a.clear()
	group_b.clear()
	group_c.clear()
	is_ready_swap = false

## Total cards remaining in all groups.
func total_cards() -> int:
	return group_a.size() + group_b.size() + group_c.size()

## True if player has shed all cards and won.
func has_won() -> bool:
	return total_cards() == 0

## Swaps a card between Group A (Hand) and Group B (Face-Up) during the 30s swap phase.
func swap_a_and_b(hand_index: int, table_index: int) -> bool:
	if hand_index < 0 or hand_index >= group_a.size():
		return false
	if table_index < 0 or table_index >= group_b.size():
		return false
	
	var temp: CardData = group_a[hand_index]
	group_a[hand_index] = group_b[table_index]
	group_b[table_index] = temp
	return true

## Determines which group the player must play from on their turn.
## Priority: Group A -> Group B (only if A is empty) -> Group C (only if A & B are empty).
func get_active_group_name() -> String:
	if group_a.size() > 0:
		return "A"
	elif group_b.size() > 0:
		return "B"
	elif group_c.size() > 0:
		return "C"
	return "NONE"

## Returns an effective integer weight for the starting player calculation.
## Hierarchy: 3 (lowest = 3) ... A (14), followed by special cards 2 (15) and 10 (16).
static func get_starting_rank_weight(rank: CardData.Rank) -> int:
	match rank:
		CardData.Rank.THREE: return 3
		CardData.Rank.FOUR: return 4
		CardData.Rank.FIVE: return 5
		CardData.Rank.SIX: return 6
		CardData.Rank.SEVEN: return 7
		CardData.Rank.EIGHT: return 8
		CardData.Rank.NINE: return 9
		CardData.Rank.JACK: return 11
		CardData.Rank.QUEEN: return 12
		CardData.Rank.KING: return 13
		CardData.Rank.ACE: return 14
		CardData.Rank.TWO: return 15
		CardData.Rank.TEN: return 16
	return 99

## Finds the lowest card in Group A according to:
## 1. Rank weight (3 is lowest, 10 is highest)
## 2. Suit order (♣ < ♦ < ♥ < ♠)
func get_lowest_hand_card() -> CardData:
	if group_a.is_empty():
		return null
	
	var lowest_card: CardData = group_a[0]
	var lowest_weight: int = get_starting_rank_weight(lowest_card.rank)
	
	for i in range(1, group_a.size()):
		var candidate: CardData = group_a[i]
		var candidate_weight: int = get_starting_rank_weight(candidate.rank)
		
		if candidate_weight < lowest_weight:
			lowest_card = candidate
			lowest_weight = candidate_weight
		elif candidate_weight == lowest_weight:
			# Tie break by suit: Clubs(0) < Diamonds(1) < Hearts(2) < Spades(3)
			if candidate.suit < lowest_card.suit:
				lowest_card = candidate
				lowest_weight = candidate_weight
	
	return lowest_card

## Sorts Group A for comfortable player view (ascending rank, then suit).
func sort_hand() -> void:
	group_a.sort_custom(func(a: CardData, b: CardData) -> bool:
		var wa: int = get_starting_rank_weight(a.rank)
		var wb: int = get_starting_rank_weight(b.rank)
		if wa != wb:
			return wa < wb
		return a.suit < b.suit
	)

## Serializes PlayerState to a Dictionary for network replication.
## If for_owner is false, private Group A hand cards are concealed (only count is sent).
func to_dict(for_owner: bool = true) -> Dictionary:
	var a_cards: Array[Dictionary] = []
	if for_owner:
		for c in group_a:
			a_cards.append(c.to_dict())
	
	var b_cards: Array[Dictionary] = []
	for c in group_b:
		b_cards.append(c.to_dict())
	
	var c_cards: Array[Dictionary] = []
	for c in group_c:
		c_cards.append(c.to_dict())
	
	return {
		"id": id,
		"name": name,
		"is_bot": is_bot,
		"is_ready_swap": is_ready_swap,
		"group_a": a_cards,
		"group_a_count": group_a.size(),
		"group_b": b_cards,
		"group_c": c_cards
	}

## Deserializes PlayerState from a Dictionary received over network.
static func from_dict(data: Dictionary) -> PlayerState:
	var p := PlayerState.new(int(data.get("id", 0)), str(data.get("name", "Player")), bool(data.get("is_bot", false)))
	p.is_ready_swap = bool(data.get("is_ready_swap", false))
	
	p.group_a.clear()
	var raw_a: Array = data.get("group_a", [])
	if not raw_a.is_empty():
		for c_dict in raw_a:
			p.group_a.append(CardData.from_dict(c_dict))
	else:
		# If concealed hand, generate dummy cards to preserve count for opponent view
		var a_count: int = int(data.get("group_a_count", 0))
		for _i in range(a_count):
			p.group_a.append(CardData.new(-1, CardData.Rank.THREE, CardData.Suit.CLUBS))
	
	p.group_b.clear()
	for c_dict in data.get("group_b", []):
		p.group_b.append(CardData.from_dict(c_dict))
	
	p.group_c.clear()
	for c_dict in data.get("group_c", []):
		p.group_c.append(CardData.from_dict(c_dict))
	
	return p

