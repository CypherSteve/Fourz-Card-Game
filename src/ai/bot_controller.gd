class_name BotController
extends PlayerController

## BotController: Autonomous AI player for Fours.
## Listens to turn and swap signals, computes decisions via BotStrategy, and executes moves.

var _rng: RandomNumberGenerator

func _init(p_player_id: int, p_engine: GameEngine, rng_seed: int = -1) -> void:
	super(p_player_id, p_engine)
	_rng = RandomNumberGenerator.new()
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

func on_swap_phase_started(_duration: float) -> void:
	var player := engine.state.get_player_by_id(player_id)
	if player == null:
		return
	
	# Execute optimal card swaps
	var swaps := BotStrategy.calculate_optimal_swaps(player)
	for s in swaps:
		engine.swap_cards(player_id, s.hand_idx, s.table_idx)
	
	# Confirm ready
	engine.set_player_ready(player_id, true)

func on_turn_started(_active_group: String) -> void:
	var player := engine.state.get_player_by_id(player_id)
	if player == null or player.has_won():
		return
	
	var next_player := engine.state.get_next_player()
	var decision := BotStrategy.choose_best_action(player, engine.state.ground_stack, next_player, _rng)
	
	match decision.action:
		"PLAY":
			var indices: Array[int] = []
			for idx in decision.indices:
				indices.append(int(idx))
			engine.play_cards(player_id, indices)
		
		"PICK_UP":
			engine.pick_up_ground(player_id)
		
		"BLIND_FLIP":
			engine.play_blind_card(player_id, int(decision.index))
