class_name GameRules
extends RefCounted

## GameRules: Pure validation and rule checking for Fours.
## Implements rank comparisons, burn triggers, starting player selection, and move validation.

## Returns effective comparison value of a card during standard gameplay.
## 3 = 3, 4 = 4, ..., Ace = 14.
## 2 and 10 are special (handled separately).
static func get_play_rank_value(rank: CardData.Rank) -> int:
	return int(rank)

## Determines the effective required rank to beat the top of the ground stack.
## If the stack is empty, or the top card is a 2 (reset), required rank is 0 (any card valid).
static func get_effective_ground_rank(ground_stack: Array[CardData]) -> int:
	if ground_stack.is_empty():
		return 0
	
	var top_card: CardData = ground_stack.back()
	if top_card.is_two():
		return 0 # 2 resets the count to 0!
	
	return get_play_rank_value(top_card.rank)

## Validates whether a proposed set of cards can legally be played onto the ground stack.
## Returns a Dictionary with {"valid": bool, "reason": String}.
static func validate_play(cards_to_play: Array[CardData], ground_stack: Array[CardData]) -> Dictionary:
	if cards_to_play.is_empty():
		return {"valid": false, "reason": "No cards selected."}
	
	# Rule: All played cards in a single turn must have the exact same rank
	var first_rank: CardData.Rank = cards_to_play[0].rank
	for i in range(1, cards_to_play.size()):
		if cards_to_play[i].rank != first_rank:
			return {"valid": false, "reason": "All played cards must have the same rank."}
	
	# Rule: 2 can be played on anything
	if first_rank == CardData.Rank.TWO:
		return {"valid": true, "reason": "Special 2 played (resets count)."}
	
	# Rule: 10 can be played on anything
	if first_rank == CardData.Rank.TEN:
		return {"valid": true, "reason": "Special 10 played (burns stack)."}
	
	# Standard rule: played rank must be >= effective ground rank
	var effective_rank: int = get_effective_ground_rank(ground_stack)
	var played_val: int = get_play_rank_value(first_rank)
	
	if played_val >= effective_rank:
		return {"valid": true, "reason": "Valid move."}
	else:
		return {
			"valid": false,
			"reason": "Card value (%s) is lower than ground stack (%d)." % [cards_to_play[0].get_rank_str(), effective_rank]
		}

## Checks if the ground stack triggers a burn.
## Burns occur if:
## 1. Top played card is a 10.
## 2. 4 or more consecutive cards on top of the ground stack share the exact same rank.
## Returns a Dictionary: {"burn": bool, "reason": String}
static func check_burn(ground_stack: Array[CardData]) -> Dictionary:
	if ground_stack.is_empty():
		return {"burn": false, "reason": ""}
	
	var top_card: CardData = ground_stack.back()
	
	# 1. Ten burn
	if top_card.is_ten():
		return {"burn": true, "reason": "TEN_PLAYED"}
	
	# 2. Four or more consecutive cards of identical rank
	if ground_stack.size() >= 4:
		var target_rank: CardData.Rank = top_card.rank
		var consecutive_count: int = 0
		
		# Count backwards from top of stack
		for i in range(ground_stack.size() - 1, -1, -1):
			if ground_stack[i].rank == target_rank:
				consecutive_count += 1
			else:
				break
		
		if consecutive_count >= 4:
			return {
				"burn": true,
				"reason": "FOUR_OF_A_KIND",
				"rank": target_rank,
				"count": consecutive_count
			}
	
	return {"burn": false, "reason": ""}

## Determines which player starts the game.
## Scans all players' Group A (Hand) for the lowest card.
## Tie-breaking: ♣ < ♦ < ♥ < ♠. If two players have the exact same rank and suit, resolves by coin flip.
static func determine_starting_player(players: Array[PlayerState], rng: RandomNumberGenerator = null) -> int:
	if players.is_empty():
		return 0
	
	var best_player_index: int = 0
	var best_card: CardData = players[0].get_lowest_hand_card()
	var best_weight: int = PlayerState.get_starting_rank_weight(best_card.rank) if best_card != null else 999
	
	for i in range(1, players.size()):
		var candidate_card: CardData = players[i].get_lowest_hand_card()
		if candidate_card == null:
			continue
		
		var candidate_weight: int = PlayerState.get_starting_rank_weight(candidate_card.rank)
		
		if candidate_weight < best_weight:
			best_player_index = i
			best_card = candidate_card
			best_weight = candidate_weight
		elif candidate_weight == best_weight:
			# Same rank: check suit (♣ < ♦ < ♥ < ♠)
			if candidate_card.suit < best_card.suit:
				best_player_index = i
				best_card = candidate_card
				best_weight = candidate_weight
			elif candidate_card.suit == best_card.suit:
				# Exact same card in double deck! Coin toss (50/50)
				var coin_toss: bool = (rng.randi() % 2 == 1) if rng != null else (randi() % 2 == 1)
				if coin_toss:
					best_player_index = i
					best_card = candidate_card
					best_weight = candidate_weight
	
	return best_player_index
