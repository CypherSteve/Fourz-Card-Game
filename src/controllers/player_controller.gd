class_name PlayerController
extends RefCounted

## PlayerController: Abstract base class for player interaction.
## Implementations: HumanController (UI events), BotController (AI), NetworkController (multiplayer).

var player_id: int = 0
var engine: GameEngine = null

func _init(p_player_id: int, p_engine: GameEngine) -> void:
	player_id = p_player_id
	engine = p_engine

func on_turn_started(active_group: String) -> void:
	pass

func on_swap_phase_started(duration: float) -> void:
	pass
