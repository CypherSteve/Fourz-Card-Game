class_name BotStrategy
extends RefCounted

## BotStrategy: Pure heuristic decision-making for Fours AI.
## Evaluates optimal card swaps, valid play choices, multi-card drops, and pickup decisions.

## Assigns a strategic value to a card for the pre-game swap phase.
## High cards and special cards (10, 2, A, K) are prioritized for Group B (Face-Up Table),
## while low cards (3, 4, 5) are best kept in Group A (Hand) to shed immediately.
static func get_swap_value(card: CardData) -> int:
	match card.rank:
		CardData.Rank.TEN: return 100 # Burn card - ultimate defense
		CardData.Rank.TWO: return 90   # Reset card - saves lives
		CardData.Rank.ACE: return 80
		CardData.Rank.KING: return 70
		CardData.Rank.QUEEN: return 60
		CardData.Rank.JACK: return 50
		CardData.Rank.NINE: return 40
		CardData.Rank.EIGHT: return 35
		CardData.Rank.SEVEN: return 30
		CardData.Rank.SIX: return 25
		CardData.Rank.FIVE: return 20
		CardData.Rank.FOUR: return 15
		CardData.Rank.THREE: return 10 # Lowest starting cards are great in hand
	return 0

## Computes the best swaps between Group A and Group B for a player.
## Returns an Array of swap actions: [{"hand_idx": int, "table_idx": int}, ...]
static func calculate_optimal_swaps(player: PlayerState) -> Array[Dictionary]:
	var swaps: Array[Dictionary] = []
	
	# Simulate copies of lists
	var hand := player.group_a.duplicate()
	var table := player.group_b.duplicate()
	
	# We want table cards to have higher swap value than hand cards
	var made_swap: bool = true
	var max_iterations: int = 8 # Prevent infinite loops
	
	while made_swap and max_iterations > 0:
		made_swap = false
		max_iterations -= 1
		
		# Find the best card in hand that is better than the worst card on table
		var best_hand_idx: int = -1
		var best_hand_val: int = -1
		for i in range(hand.size()):
			var val := get_swap_value(hand[i])
			if val > best_hand_val:
				best_hand_val = val
				best_hand_idx = i
		
		var worst_table_idx: int = -1
		var worst_table_val: int = 999
		for j in range(table.size()):
			var val := get_swap_value(table[j])
			if val < worst_table_val:
				worst_table_val = val
				worst_table_idx = j
		
		if best_hand_idx != -1 and worst_table_idx != -1 and best_hand_val > worst_table_val:
			swaps.append({"hand_idx": best_hand_idx, "table_idx": worst_table_idx})
			# Swap in simulated arrays
			var temp: CardData = hand[best_hand_idx]
			hand[best_hand_idx] = table[worst_table_idx]
			table[worst_table_idx] = temp
			made_swap = true
	
	return swaps

## Finds all valid move options for a player from the given card pool.
## Automatically groups identical ranks (e.g. playing 1, 2, 3, or 4 of the same rank).
## Returns Array of Dictionaries: [{"indices": Array[int], "rank": Rank, "is_special": bool, ...}]
static func get_legal_moves(cards: Array[CardData], ground_stack: Array[CardData]) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	
	# Group indices by rank
	var rank_to_indices: Dictionary = {}
	for i in range(cards.size()):
		var r: CardData.Rank = cards[i].rank
		if not rank_to_indices.has(r):
			rank_to_indices[r] = []
		rank_to_indices[r].append(i)
	
	# For each rank, check if it's legally playable
	for r in rank_to_indices.keys():
		var indices: Array = rank_to_indices[r]
		var sample_card: CardData = cards[indices[0]]
		
		var validation := GameRules.validate_play([sample_card], ground_stack)
		if validation.valid:
			# Play all cards of this rank simultaneously to shed hand faster
			var typed_indices: Array[int] = []
			for idx in indices:
				typed_indices.append(int(idx))
			
			moves.append({
				"indices": typed_indices,
				"rank": r,
				"card_count": typed_indices.size(),
				"is_two": sample_card.is_two(),
				"is_ten": sample_card.is_ten()
			})
	
	return moves

## Counts how many consecutive cards of the specified rank are already on top of the ground stack.
static func count_top_consecutive_rank(ground_stack: Array[CardData], rank: CardData.Rank) -> int:
	var count: int = 0
	for i in range(ground_stack.size() - 1, -1, -1):
		if ground_stack[i].rank == rank:
			count += 1
		else:
			break
	return count

## Analyzes Group B cards of an opponent.
## Returns a Dictionary with:
##   "has_two": bool,
##   "has_ten": bool,
##   "max_standard_rank": int (effective rank value 3..14, or 0 if no standard cards)
static func analyze_group_b(cards: Array[CardData]) -> Dictionary:
	var has_two: bool = false
	var has_ten: bool = false
	var max_standard: int = 0
	
	for card in cards:
		if card.is_two():
			has_two = true
		elif card.is_ten():
			has_ten = true
		else:
			var val: int = GameRules.get_play_rank_value(card.rank)
			if val > max_standard:
				max_standard = val
	
	return {
		"has_two": has_two,
		"has_ten": has_ten,
		"max_standard_rank": max_standard
	}

## Selects the best move for a bot given the current state.
## Supports tactical sabotage against next_player (especially when in Group B or C).
## Returns:
##   {"action": "PLAY", "indices": Array[int]} OR
##   {"action": "PICK_UP"} OR
##   {"action": "BLIND_FLIP", "index": int}
static func choose_best_action(
	player: PlayerState,
	ground_stack: Array[CardData],
	next_player_or_rng = null,
	optional_rng: RandomNumberGenerator = null
) -> Dictionary:
	var next_player: PlayerState = null
	var rng: RandomNumberGenerator = null
	
	if next_player_or_rng is PlayerState:
		next_player = next_player_or_rng
		rng = optional_rng
	elif next_player_or_rng is RandomNumberGenerator:
		rng = next_player_or_rng
	
	var active_group := player.get_active_group_name()
	
	# Group C: Blind gamble!
	if active_group == "C":
		var blind_index: int = 0
		if player.group_c.size() > 1:
			blind_index = (rng.randi() % player.group_c.size()) if rng != null else (randi() % player.group_c.size())
		return {"action": "BLIND_FLIP", "index": blind_index}
	
	var source_cards: Array[CardData] = player.group_a if active_group == "A" else player.group_b
	var legal_moves := get_legal_moves(source_cards, ground_stack)
	
	# No legal move -> must pick up ground
	if legal_moves.is_empty():
		return {"action": "PICK_UP"}
	
	# Separate moves into categories
	var burn_moves: Array[Dictionary] = [] # standard moves that trigger 4-of-a-kind burn
	var standard_moves: Array[Dictionary] = []
	var two_moves: Array[Dictionary] = []
	var ten_moves: Array[Dictionary] = []
	
	for move in legal_moves:
		if move.is_ten:
			ten_moves.append(move)
		elif move.is_two:
			two_moves.append(move)
		else:
			var top_same: int = count_top_consecutive_rank(ground_stack, move.rank)
			if top_same + move.card_count >= 4:
				burn_moves.append(move)
			else:
				standard_moves.append(move)
	
	# 1. 4-of-a-kind burn opportunity is top priority (clears pile & grants immediate extra turn!)
	if not burn_moves.is_empty():
		return {"action": "PLAY", "indices": burn_moves[0].indices}
	
	# 2. Substantial pile burn with 10 (burns cards permanently to graveyard & grants extra turn!)
	if not ten_moves.is_empty() and ground_stack.size() >= 3:
		return {"action": "PLAY", "indices": ten_moves[0].indices}
	
	# 3. Tactical Sabotage: Evaluate next player in turn order
	if next_player != null and next_player != player:
		var next_phase := next_player.get_active_group_name()
		
		# ===================================================================
		# CASE 3A: Next player is playing Group B (Face-Up Table cards!)
		# The bot can see every card the opponent has.
		# If opponent has no 2/10, playing a card > their maximum visible rank
		# guarantees they cannot play and MUST pick up the ground stack into hand (Group A),
		# resetting their endgame progress!
		# Even if opponent has a 2 or 10, playing > their highest card forces them to
		# burn that precious escape card.
		# ===================================================================
		if next_phase == "B":
			var analysis := analyze_group_b(next_player.group_b)
			var max_opp_rank: int = analysis.max_standard_rank
			
			if not standard_moves.is_empty():
				var beating_moves: Array[Dictionary] = []
				for m in standard_moves:
					var m_val: int = GameRules.get_play_rank_value(m.rank)
					if m_val > max_opp_rank:
						beating_moves.append(m)
				
				if not beating_moves.is_empty():
					# Trap them! Pick the lowest rank that beats max_opp_rank
					# to guarantee sabotage without wasting higher cards.
					beating_moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
						var val_a: int = GameRules.get_play_rank_value(a.rank)
						var val_b: int = GameRules.get_play_rank_value(b.rank)
						if val_a != val_b:
							return val_a < val_b # Lowest rank that still beats opponent
						return a.card_count > b.card_count
					)
					return {"action": "PLAY", "indices": beating_moves[0].indices}
				else:
					# Cannot beat their maximum card with standard cards.
					# If ground stack has multiple cards (>= 2) and we have a 10, burn it!
					if not ten_moves.is_empty() and ground_stack.size() >= 2:
						return {"action": "PLAY", "indices": ten_moves[0].indices}
					
					# Otherwise play lowest standard card
					standard_moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
						var val_a: int = GameRules.get_play_rank_value(a.rank)
						var val_b: int = GameRules.get_play_rank_value(b.rank)
						if val_a != val_b:
							return val_a < val_b
						return a.card_count > b.card_count
					)
					return {"action": "PLAY", "indices": standard_moves[0].indices}
			
			# No standard moves playable:
			# Prioritize 10 burn rather than 2 (playing a 2 resets ground to 0 and gives opponent a free escape!)
			if not ten_moves.is_empty():
				return {"action": "PLAY", "indices": ten_moves[0].indices}
			
			if not two_moves.is_empty():
				return {"action": "PLAY", "indices": two_moves[0].indices}
		
		# ===================================================================
		# CASE 2B: Next player is in Group C (Blind gamble!)
		# Play our highest valid card to set a high bar, maximizing the
		# probability that their blind flip fails and they pick up the pile!
		# ===================================================================
		elif next_phase == "C":
			if not standard_moves.is_empty():
				# Sort descending (play highest card: Ace, King, Queen...)
				standard_moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					var val_a: int = GameRules.get_play_rank_value(a.rank)
					var val_b: int = GameRules.get_play_rank_value(b.rank)
					if val_a != val_b:
						return val_a > val_b # Highest first!
					return a.card_count > b.card_count
				)
				return {"action": "PLAY", "indices": standard_moves[0].indices}
			
			# Prefer 10 burn over 2! (Never reset to 0 for a blind flipper!)
			if not ten_moves.is_empty():
				return {"action": "PLAY", "indices": ten_moves[0].indices}
			
			if not two_moves.is_empty():
				return {"action": "PLAY", "indices": two_moves[0].indices}
	
	# 3. Standard move selection (Phase A next player, or no sabotage target)
	# Play lowest valid standard card to shed hand quickly and save high cards.
	if not standard_moves.is_empty():
		standard_moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var val_a: int = GameRules.get_play_rank_value(a.rank)
			var val_b: int = GameRules.get_play_rank_value(b.rank)
			if val_a != val_b:
				return val_a < val_b
			return a.card_count > b.card_count
		)
		return {"action": "PLAY", "indices": standard_moves[0].indices}
	
	# 4. Use 10 to burn if ground pile is substantial (>= 3 cards)
	if not ten_moves.is_empty() and ground_stack.size() >= 3:
		return {"action": "PLAY", "indices": ten_moves[0].indices}
	
	# 5. Use 2 to reset the pile
	if not two_moves.is_empty():
		return {"action": "PLAY", "indices": two_moves[0].indices}
	
	# 6. Use 10 to burn
	if not ten_moves.is_empty():
		return {"action": "PLAY", "indices": ten_moves[0].indices}
	
	# Default fallback: pick up
	return {"action": "PICK_UP"}
