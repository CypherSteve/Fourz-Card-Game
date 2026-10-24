class_name GameState
extends RefCounted

## GameState: Holds the complete runtime state of an active match of Fours.

enum GamePhase {
	NOT_STARTED,
	DEALING,
	SWAP_PHASE,
	PLAYING,
	GAME_OVER
}

var phase: GamePhase = GamePhase.NOT_STARTED
var players: Array[PlayerState] = []
var current_player_index: int = 0
var deck: Deck = null

var ground_stack: Array[CardData] = []
var graveyard: Array[CardData] = [] # Burned cards out of play

var swap_time_remaining: float = 30.0
var winner_id: int = -1

func _init() -> void:
	deck = Deck.new()
	reset()

func reset() -> void:
	phase = GamePhase.NOT_STARTED
	players.clear()
	current_player_index = 0
	ground_stack.clear()
	graveyard.clear()
	swap_time_remaining = 30.0
	winner_id = -1
	deck.reset_and_build()

func get_current_player() -> PlayerState:
	if players.is_empty():
		return null
	return players[current_player_index]

func get_player_by_id(player_id: int) -> PlayerState:
	for p in players:
		if p.id == player_id:
			return p
	return null

func get_top_ground_card() -> CardData:
	if ground_stack.is_empty():
		return null
	return ground_stack.back()

func ground_count() -> int:
	return ground_stack.size()

func draw_pile_count() -> int:
	return deck.count()

func graveyard_count() -> int:
	return graveyard.size()

## Advance current player to next player in clockwise order.
func advance_to_next_player() -> void:
	if players.is_empty():
		return
	current_player_index = (current_player_index + 1) % players.size()

## Returns the player whose turn is next in clockwise order.
func get_next_player() -> PlayerState:
	if players.is_empty():
		return null
	var next_idx: int = (current_player_index + 1) % players.size()
	return players[next_idx]

