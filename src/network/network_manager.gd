class_name NetworkManager
extends Node

## NetworkManager: Manages ENet multiplayer peer, host/client rooms,
## player peer mappings, and authoritative network replication for Fours.

signal host_started(port: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()
signal lobby_updated(players_info: Array[Dictionary])
signal match_started_network(configs: Array[Dictionary], local_player_id: int)

# Network Game Events relayed from Host
signal net_cards_dealt(players_data: Array, draw_count: int)
signal net_swap_phase_started(duration: float)
signal net_swap_time_updated(seconds: float)
signal net_swap_phase_ended()
signal net_card_swapped(player_id: int, hand_idx: int, table_idx: int)
signal net_turn_started(active_player_id: int, active_group: String)
signal net_cards_played(player_id: int, cards: Array[CardData], active_group: String)
signal net_blind_card_revealed(player_id: int, card: CardData, is_valid: bool)
signal net_pile_burned(player_id: int, reason: String)
signal net_pile_collected(player_id: int, count: int)
signal net_cards_drawn(player_id: int, count: int, drawn_cards: Array[CardData])
signal net_game_won(winner_id: int)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

var peer: ENetMultiplayerPeer
var is_network_active: bool = false
var local_name: String = "Player"
var room_player_count: int = 2
var fill_with_bots: bool = true

# Peer ID -> Dictionary {"peer_id": int, "name": String, "player_id": int}
var lobby_peers: Array[Dictionary] = []
var peer_to_player_id: Dictionary = {}
var player_id_to_peer: Dictionary = {}

var engine: GameEngine = null
var local_player_id: int = 0

# Pending game parameters for scene transitions
var pending_game_mode: String = "SOLO" # "SOLO" or "MULTIPLAYER"
var pending_player_count: int = 2
var pending_multiplayer_configs: Array[Dictionary] = []
var pending_assigned_id: int = 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Starts hosting a room on the given port.
func host_game(port: int = DEFAULT_PORT, target_player_count: int = 2, p_name: String = "Host", p_fill_bots: bool = true) -> Error:
	disconnect_game()
	
	local_name = p_name
	room_player_count = target_player_count
	fill_with_bots = p_fill_bots
	
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		print("Failed to host server on port %d: %s" % [port, error_string(err)])
		return err
	
	multiplayer.multiplayer_peer = peer
	is_network_active = true
	local_player_id = 0
	
	lobby_peers.clear()
	lobby_peers.append({
		"peer_id": 1,
		"name": local_name,
		"player_id": 0,
		"is_host": true
	})
	
	host_started.emit(port)
	lobby_updated.emit(lobby_peers)
	return OK

## Connects to a hosted game at address:port.
func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT, p_name: String = "Player") -> Error:
	disconnect_game()
	
	local_name = p_name
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		print("Failed to connect to %s:%d: %s" % [address, port, error_string(err)])
		return err
	
	multiplayer.multiplayer_peer = peer
	is_network_active = true
	return OK

## Disconnects from current network session.
func disconnect_game() -> void:
	if multiplayer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	is_network_active = false
	lobby_peers.clear()
	peer_to_player_id.clear()
	player_id_to_peer.clear()
	engine = null
	pending_game_mode = "SOLO"
	pending_multiplayer_configs.clear()
	pending_assigned_id = 0

func is_server() -> bool:
	return multiplayer.is_server() if is_network_active else false

# ==========================================
# LOBBY & PEER HANDLING
# ==========================================

func _on_peer_connected(id: int) -> void:
	if is_server():
		print("Peer connected to server: %d" % id)
		# Request peer details
		rpc_id(id, "rpc_request_player_info")

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: %d" % id)
	if is_server():
		for i in range(lobby_peers.size() - 1, -1, -1):
			if lobby_peers[i].peer_id == id:
				lobby_peers.remove_at(i)
				break
		rpc("rpc_sync_lobby", lobby_peers)
		lobby_updated.emit(lobby_peers)

func _on_connected_to_server() -> void:
	print("Successfully connected to host server!")
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("Failed to connect to server.")
	disconnect_game()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("Server disconnected.")
	disconnect_game()
	server_disconnected.emit()

@rpc("any_peer", "reliable")
func rpc_request_player_info() -> void:
	# Client replies with its player name
	var sender_id := multiplayer.get_unique_id()
	rpc_id(1, "rpc_receive_player_info", sender_id, local_name)

@rpc("any_peer", "reliable")
func rpc_receive_player_info(peer_id: int, p_name: String) -> void:
	if not is_server():
		return
	
	var found := false
	for p in lobby_peers:
		if p.peer_id == peer_id:
			p.name = p_name
			found = true
			break
	if not found:
		lobby_peers.append({
			"peer_id": peer_id,
			"name": p_name,
			"player_id": lobby_peers.size(),
			"is_host": false
		})
	
	rpc("rpc_sync_lobby", lobby_peers)
	lobby_updated.emit(lobby_peers)

@rpc("call_local", "reliable")
func rpc_sync_lobby(peers: Array) -> void:
	var updated_peers: Array[Dictionary] = []
	for p in peers:
		updated_peers.append(Dictionary(p))
	lobby_peers = updated_peers
	lobby_updated.emit(lobby_peers)

# ==========================================
# MATCH SETUP (HOST)
# ==========================================

## Starts the multiplayer match from the lobby (Host only).
func start_multiplayer_match(p_engine: GameEngine) -> void:
	if not is_server():
		return
	
	engine = p_engine
	peer_to_player_id.clear()
	player_id_to_peer.clear()
	
	var configs: Array[Dictionary] = []
	var bot_names := ["Bot Alpha", "Bot Beta", "Bot Gamma"]
	
	for slot_idx in range(room_player_count):
		if slot_idx < lobby_peers.size():
			var p_info := lobby_peers[slot_idx]
			peer_to_player_id[p_info.peer_id] = slot_idx
			player_id_to_peer[slot_idx] = p_info.peer_id
			configs.append({
				"id": slot_idx,
				"name": p_info.name,
				"is_bot": false,
				"peer_id": p_info.peer_id
			})
		else:
			# Fill with AI bot
			player_id_to_peer[slot_idx] = -1
			configs.append({
				"id": slot_idx,
				"name": bot_names[slot_idx - 1] if slot_idx <= 3 else "Bot %d" % slot_idx,
				"is_bot": true,
				"peer_id": -1
			})
	
	var match_seed := randi()
	
	# Wire host engine signals to RPC broadcasts
	_bind_engine_signals()
	
	pending_game_mode = "MULTIPLAYER"
	pending_player_count = configs.size()
	pending_multiplayer_configs = configs
	pending_assigned_id = 0
	
	# Broadcast start match ONLY to remote clients (peer_id != 1)
	for p_info in lobby_peers:
		if p_info.peer_id != 1:
			var client_p_id: int = peer_to_player_id.get(p_info.peer_id, 1)
			rpc_id(p_info.peer_id, "rpc_match_started", configs, client_p_id)
	
	# Signal to host locally
	match_started_network.emit(configs, 0)
	
	# Start engine on host
	engine.setup_game(configs, match_seed)

@rpc("call_local", "reliable")
func rpc_match_started(configs: Array, assigned_player_id: int) -> void:
	local_player_id = assigned_player_id
	var typed_configs: Array[Dictionary] = []
	for c in configs:
		typed_configs.append(Dictionary(c))
	
	pending_game_mode = "MULTIPLAYER"
	pending_player_count = typed_configs.size()
	pending_multiplayer_configs = typed_configs
	pending_assigned_id = assigned_player_id
	
	match_started_network.emit(typed_configs, local_player_id)

func _bind_engine_signals() -> void:
	if engine == null:
		return
	
	engine.cards_dealt.connect(_on_host_cards_dealt)
	engine.swap_phase_started.connect(func(duration: float) -> void:
		rpc("rpc_sync_swap_phase_started", duration)
	)
	engine.swap_time_updated.connect(func(seconds: float) -> void:
		rpc("rpc_sync_swap_time_updated", seconds)
	)
	engine.swap_phase_ended.connect(func() -> void:
		rpc("rpc_sync_swap_phase_ended")
	)
	engine.card_swapped.connect(func(p_id: int, h_idx: int, t_idx: int) -> void:
		rpc("rpc_sync_card_swapped", p_id, h_idx, t_idx)
	)
	engine.turn_started.connect(func(p_id: int, group: String) -> void:
		rpc("rpc_sync_turn_started", p_id, group)
	)
	engine.cards_played.connect(func(p_id: int, cards: Array[CardData], group: String) -> void:
		var cards_data: Array[Dictionary] = []
		for c in cards:
			cards_data.append(c.to_dict())
		rpc("rpc_sync_cards_played", p_id, cards_data, group)
	)
	engine.blind_card_revealed.connect(func(p_id: int, card: CardData, is_valid: bool) -> void:
		rpc("rpc_sync_blind_card_revealed", p_id, card.to_dict(), is_valid)
	)
	engine.pile_burned.connect(func(p_id: int, reason: String) -> void:
		rpc("rpc_sync_pile_burned", p_id, reason)
	)
	engine.pile_collected.connect(func(p_id: int, count: int) -> void:
		rpc("rpc_sync_pile_collected", p_id, count)
	)
	engine.cards_drawn.connect(_on_host_cards_drawn)
	engine.game_won.connect(func(winner_id: int) -> void:
		rpc("rpc_sync_game_won", winner_id)
	)

func _on_host_cards_dealt() -> void:
	# Broadcast customized card data to each remote peer (concealing private hands)
	for peer_info in lobby_peers:
		var p_peer_id: int = peer_info.peer_id
		if p_peer_id == 1:
			continue
		var assigned_id: int = peer_to_player_id.get(p_peer_id, 1)
		
		var players_data: Array[Dictionary] = []
		for player in engine.state.players:
			var for_owner := (player.id == assigned_id)
			players_data.append(player.to_dict(for_owner))
		
		rpc_id(p_peer_id, "rpc_sync_cards_dealt", players_data, engine.state.deck.count())

func _on_host_cards_drawn(player_id: int, count: int, drawn_cards: Array[CardData] = []) -> void:
	var target_peer: int = player_id_to_peer.get(player_id, -1)
	
	# Send exact drawn cards to owner, and empty array to other players to preserve private hands
	var drawn_cards_dict: Array[Dictionary] = []
	for c in drawn_cards:
		drawn_cards_dict.append(c.to_dict())
	
	for peer_info in lobby_peers:
		var p_peer: int = peer_info.peer_id
		if p_peer == 1:
			continue
		if p_peer == target_peer:
			rpc_id(p_peer, "rpc_sync_cards_drawn", player_id, count, drawn_cards_dict)
		else:
			rpc_id(p_peer, "rpc_sync_cards_drawn", player_id, count, [])

# ==========================================
# CLIENT REQUESTS -> HOST
# ==========================================

func request_swap(hand_idx: int, table_idx: int) -> void:
	if not is_network_active:
		return
	if is_server():
		engine.swap_cards(0, hand_idx, table_idx)
	else:
		rpc_id(1, "rpc_request_swap", hand_idx, table_idx)

func request_player_ready(is_ready: bool) -> void:
	if not is_network_active:
		return
	if is_server():
		engine.set_player_ready(0, is_ready)
	else:
		rpc_id(1, "rpc_request_player_ready", is_ready)

func request_play_cards(indices: Array[int]) -> void:
	if not is_network_active:
		return
	if is_server():
		engine.play_cards(0, indices)
	else:
		rpc_id(1, "rpc_request_play_cards", indices)

func request_pickup() -> void:
	if not is_network_active:
		return
	if is_server():
		engine.pick_up_ground(0)
	else:
		rpc_id(1, "rpc_request_pickup")

func request_blind_flip(index: int) -> void:
	if not is_network_active:
		return
	if is_server():
		engine.play_blind_card(0, index)
	else:
		rpc_id(1, "rpc_request_blind_flip", index)

# Host execution of client requests
@rpc("any_peer", "reliable")
func rpc_request_swap(hand_idx: int, table_idx: int) -> void:
	if not is_server() or engine == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var p_id: int = peer_to_player_id.get(sender, -1)
	if p_id != -1:
		engine.swap_cards(p_id, hand_idx, table_idx)

@rpc("any_peer", "reliable")
func rpc_request_player_ready(is_ready: bool) -> void:
	if not is_server() or engine == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var p_id: int = peer_to_player_id.get(sender, -1)
	if p_id != -1:
		engine.set_player_ready(p_id, is_ready)

@rpc("any_peer", "reliable")
func rpc_request_play_cards(indices: Array) -> void:
	if not is_server() or engine == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var p_id: int = peer_to_player_id.get(sender, -1)
	if p_id != -1:
		var typed_indices: Array[int] = []
		for idx in indices:
			typed_indices.append(int(idx))
		engine.play_cards(p_id, typed_indices)

@rpc("any_peer", "reliable")
func rpc_request_pickup() -> void:
	if not is_server() or engine == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var p_id: int = peer_to_player_id.get(sender, -1)
	if p_id != -1:
		engine.pick_up_ground(p_id)

@rpc("any_peer", "reliable")
func rpc_request_blind_flip(index: int) -> void:
	if not is_server() or engine == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var p_id: int = peer_to_player_id.get(sender, -1)
	if p_id != -1:
		engine.play_blind_card(p_id, index)

# ==========================================
# CLIENT INCOMING SYNC RPCS (Sent from host to remote clients)
# ==========================================

@rpc("reliable")
func rpc_sync_cards_dealt(players_data: Array, draw_count: int) -> void:
	net_cards_dealt.emit(players_data, draw_count)

@rpc("reliable")
func rpc_sync_swap_phase_started(duration: float) -> void:
	net_swap_phase_started.emit(duration)

@rpc("reliable")
func rpc_sync_swap_time_updated(seconds: float) -> void:
	net_swap_time_updated.emit(seconds)

@rpc("reliable")
func rpc_sync_swap_phase_ended() -> void:
	net_swap_phase_ended.emit()

@rpc("reliable")
func rpc_sync_card_swapped(p_id: int, h_idx: int, t_idx: int) -> void:
	net_card_swapped.emit(p_id, h_idx, t_idx)

@rpc("reliable")
func rpc_sync_turn_started(active_p_id: int, active_group: String) -> void:
	net_turn_started.emit(active_p_id, active_group)

@rpc("reliable")
func rpc_sync_cards_played(p_id: int, cards_data: Array, active_group: String) -> void:
	var cards: Array[CardData] = []
	for c_dict in cards_data:
		cards.append(CardData.from_dict(c_dict))
	net_cards_played.emit(p_id, cards, active_group)

@rpc("reliable")
func rpc_sync_blind_card_revealed(p_id: int, card_dict: Dictionary, is_valid: bool) -> void:
	var card := CardData.from_dict(card_dict)
	net_blind_card_revealed.emit(p_id, card, is_valid)

@rpc("reliable")
func rpc_sync_pile_burned(p_id: int, reason: String) -> void:
	net_pile_burned.emit(p_id, reason)

@rpc("reliable")
func rpc_sync_pile_collected(p_id: int, count: int) -> void:
	net_pile_collected.emit(p_id, count)

@rpc("reliable")
func rpc_sync_cards_drawn(p_id: int, count: int, cards_data: Array) -> void:
	var drawn: Array[CardData] = []
	for c_dict in cards_data:
		drawn.append(CardData.from_dict(c_dict))
	net_cards_drawn.emit(p_id, count, drawn)

@rpc("reliable")
func rpc_sync_game_won(winner_id: int) -> void:
	net_game_won.emit(winner_id)
