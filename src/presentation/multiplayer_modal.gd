class_name MultiplayerModal
extends Control

## MultiplayerModal: UI dialog for hosting and joining multiplayer matches in Fours.
## Provides room creation, LAN IP display, peer list, and room connection status.

signal host_match_requested(port: int, player_count: int, player_name: String, fill_bots: bool)
signal join_match_requested(address: String, port: int, player_name: String)
signal start_game_requested()
signal modal_closed()

@onready var panel: Panel = $Panel
@onready var close_btn: Button = $Panel/Header/CloseButton

# Tab switching
@onready var tab_host_btn: Button = $Panel/TabBar/HostTabBtn
@onready var tab_join_btn: Button = $Panel/TabBar/JoinTabBtn
@onready var host_container: VBoxContainer = $Panel/HostContainer
@onready var join_container: VBoxContainer = $Panel/JoinContainer

# Host controls
@onready var host_name_input: LineEdit = $Panel/HostContainer/NameBox/HostNameInput
@onready var host_port_input: LineEdit = $Panel/HostContainer/PortBox/HostPortInput
@onready var host_2p_btn: Button = $Panel/HostContainer/CountBox/Btn2P
@onready var host_3p_btn: Button = $Panel/HostContainer/CountBox/Btn3P
@onready var host_4p_btn: Button = $Panel/HostContainer/CountBox/Btn4P
@onready var fill_bots_check: CheckBox = $Panel/HostContainer/FillBotsCheck
@onready var start_hosting_btn: Button = $Panel/HostContainer/StartHostingBtn
@onready var host_info_box: VBoxContainer = $Panel/HostContainer/HostInfoBox
@onready var lan_ip_label: Label = $Panel/HostContainer/HostInfoBox/LanIpLabel
@onready var peers_list_label: Label = $Panel/HostContainer/HostInfoBox/PeersListLabel
@onready var start_match_btn: Button = $Panel/HostContainer/HostInfoBox/StartMatchBtn

# Join controls
@onready var join_name_input: LineEdit = $Panel/JoinContainer/NameBox/JoinNameInput
@onready var join_ip_input: LineEdit = $Panel/JoinContainer/IpBox/JoinIpInput
@onready var join_port_input: LineEdit = $Panel/JoinContainer/PortBox/JoinPortInput
@onready var connect_btn: Button = $Panel/JoinContainer/ConnectBtn
@onready var join_status_label: Label = $Panel/JoinContainer/JoinStatusLabel

var selected_player_count: int = 2
var is_currently_hosting: bool = false

func _ready() -> void:
	visible = false
	_apply_styles()
	_setup_signals()
	_update_host_count_buttons()

func _apply_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.18, 0.98)
	panel_style.border_color = Color(0.28, 0.42, 0.68, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", panel_style)

func _setup_signals() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	tab_host_btn.pressed.connect(func(): _switch_tab(true))
	tab_join_btn.pressed.connect(func(): _switch_tab(false))
	
	host_2p_btn.pressed.connect(func(): _set_host_player_count(2))
	host_3p_btn.pressed.connect(func(): _set_host_player_count(3))
	host_4p_btn.pressed.connect(func(): _set_host_player_count(4))
	
	start_hosting_btn.pressed.connect(_on_start_hosting_pressed)
	start_match_btn.pressed.connect(_on_start_match_pressed)
	connect_btn.pressed.connect(_on_connect_pressed)

func open() -> void:
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_switch_tab(true)

func close() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(func():
		visible = false
		modal_closed.emit()
	)

func _on_close_pressed() -> void:
	close()

func _switch_tab(show_host: bool) -> void:
	host_container.visible = show_host
	join_container.visible = not show_host
	
	tab_host_btn.modulate = Color(1.0, 1.0, 1.0) if show_host else Color(0.6, 0.65, 0.75)
	tab_join_btn.modulate = Color(1.0, 1.0, 1.0) if not show_host else Color(0.6, 0.65, 0.75)

func _set_host_player_count(count: int) -> void:
	selected_player_count = count
	_update_host_count_buttons()

func _update_host_count_buttons() -> void:
	host_2p_btn.text = "● 2P" if selected_player_count == 2 else "2P"
	host_3p_btn.text = "● 3P" if selected_player_count == 3 else "3P"
	host_4p_btn.text = "● 4P" if selected_player_count == 4 else "4P"

func _on_start_hosting_pressed() -> void:
	var port := int(host_port_input.text.strip_edges())
	if port <= 0:
		port = 7777
	
	var p_name := host_name_input.text.strip_edges()
	if p_name.is_empty():
		p_name = "Host"
	
	var fill_bots := fill_bots_check.button_pressed
	is_currently_hosting = true
	
	start_hosting_btn.visible = false
	host_info_box.visible = true
	
	var lan_ip := get_lan_ip()
	lan_ip_label.text = "📍 Local IP: 127.0.0.1  |  LAN IP: %s (Port: %d)" % [lan_ip, port]
	
	host_match_requested.emit(port, selected_player_count, p_name, fill_bots)

func _on_start_match_pressed() -> void:
	start_game_requested.emit()
	close()

func _on_connect_pressed() -> void:
	var ip_addr := join_ip_input.text.strip_edges()
	if ip_addr.is_empty():
		ip_addr = "127.0.0.1"
	
	var port := int(join_port_input.text.strip_edges())
	if port <= 0:
		port = 7777
	
	var p_name := join_name_input.text.strip_edges()
	if p_name.is_empty():
		p_name = "Guest"
	
	join_status_label.text = "Connecting to %s:%d..." % [ip_addr, port]
	join_status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	connect_btn.disabled = true
	
	join_match_requested.emit(ip_addr, port, p_name)

func update_lobby_peers(peers: Array[Dictionary]) -> void:
	if not is_inside_tree():
		return
	
	var peer_lines: Array[String] = []
	for i in range(peers.size()):
		var p := peers[i]
		var tag := "👑 " if p.get("is_host", false) else "👤 "
		peer_lines.append("%s%s (Player %d)" % [tag, p.get("name", "Player"), i])
	
	for slot in range(peers.size(), selected_player_count):
		if fill_bots_check.button_pressed:
			peer_lines.append("🤖 [AI Bot: Bot %s (Slot %d)]" % ["Alpha" if slot == 1 else ("Beta" if slot == 2 else "Gamma"), slot + 1])
		else:
			peer_lines.append("⏳ [Waiting for player %d...]" % [slot + 1])
	
	peers_list_label.text = "Players in Room (%dP):\n" % selected_player_count + "\n".join(peer_lines)
	
	# Also update Join tab status if client is connected
	if not is_currently_hosting and join_status_label != null:
		join_status_label.text = "✅ Connected to Host!\n\nPlayers in Room (%dP):\n" % selected_player_count + "\n".join(peer_lines) + "\n\n⏳ Waiting for Host to start match..."
		join_status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	
	# Update host Start Match button
	if is_currently_hosting and start_match_btn != null:
		var ready_to_start := (peers.size() >= selected_player_count) or fill_bots_check.button_pressed
		start_match_btn.disabled = not ready_to_start
		if peers.size() >= selected_player_count:
			if selected_player_count == 2:
				start_match_btn.text = "🚀 START MATCH (1v1 Human vs Human - No Bots!)"
			else:
				start_match_btn.text = "🚀 START MATCH (%d Humans - All Ready!)" % [peers.size()]
		elif fill_bots_check.button_pressed:
			var bot_count := selected_player_count - peers.size()
			start_match_btn.text = "🚀 START MATCH (%d Human + %d Bot%s)" % [peers.size(), bot_count, "s" if bot_count > 1 else ""]
		else:
			start_match_btn.text = "⏳ WAITING FOR PLAYERS (%d/%d)" % [peers.size(), selected_player_count]

func on_connection_success() -> void:
	join_status_label.text = "✅ Connected to Host! Waiting for match to start..."
	join_status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))

func on_connection_failed(msg: String = "Connection failed.") -> void:
	join_status_label.text = "❌ " + msg
	join_status_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	connect_btn.disabled = false

static func get_lan_ip() -> String:
	var addresses := IP.get_local_addresses()
	
	# Priority 1: Standard Home Wi-Fi / LAN router range (192.168.x.x)
	for ip in addresses:
		if ip.begins_with("192.168."):
			return ip
	
	# Priority 2: Standard Class A private LAN (10.x.x.x)
	for ip in addresses:
		if ip.begins_with("10."):
			return ip
	
	# Priority 3: Other valid non-loopback, non-link-local, non-docker IPs
	for ip in addresses:
		if ip.find(".") != -1 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			# Exclude Docker / WSL / virtual container subnets (172.16.x.x to 172.31.x.x)
			if ip.begins_with("172."):
				var parts := ip.split(".")
				if parts.size() >= 2:
					var second_octet := int(parts[1])
					if second_octet >= 16 and second_octet <= 31:
						continue # Skip Docker virtual adapter
			return ip
	
	# Fallback if only Docker / local exists
	for ip in addresses:
		if ip.find(".") != -1 and not ip.begins_with("127."):
			return ip
			
	return "127.0.0.1"
