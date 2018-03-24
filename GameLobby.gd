extends Node2D
const DEFAULT_PORT = 9044

var names = []
const GameMappings = {"CardsAgainstHumanity": preload("res://Games/CardsAgainstHumanity/Config.tscn")}
const NameFile = "res://Common/Asset/names.txt"

var player_info = {}

func ready_name():
	"""Readies names to be used by reading a file of names.
	
	The "names" var will be set.
	"""
	var name_file = File.new()
	name_file.open(NameFile, File.READ)
	while !name_file.eof_reached():
		names.append(name_file.get_line())
	

func _ready():
	randomize()
	ready_name()
	get_node("Base/Port").text = ":%s" % DEFAULT_PORT
	get_node("Base/PlayerName").text = names[randi() % names.size()]
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	PlayerManager.connect("PlayerListChanged", self, "_refresh_players")
	PlayerManager.connect("PlayerExists", self, "_player_exists")
	GameManager.connect("start_game", self, "prepare")
	GameManager.connect("end_game", self, "restore")
	
	get_node("Base/GameOptions").add_item("Choose a game")
	for game in GameMappings:
		get_node("Base/GameOptions").add_item(game)
		var config = GameMappings[game].instance()
		config.target_location = get_node("GameLocation").get_path()
		GameMappings[game] = config
		get_node("Base/ConfigContainers").add_child(config)
		config.visible = false
	print(get_node("GameLocation").get_path())

func make_credit_visible(visibility):
	"""Makes credit visible/hidden.
	
	Args:
		visibility: bool, if true makes it visible.
	"""
	if visibility:
		get_node("Base/Credit/CenterContainer").show()
	else:
		get_node("Base/Credit/CenterContainer").hide()

func toggle_credit_visibility():
	"""Toggles credit.
	
	If visible, turns it hidden, otherwise makes it visible.
	"""
	if get_node("Base/Credit/CenterContainer").visible:
		make_credit_visible(false)
	else:
		make_credit_visible(true)

func prepare():
	"""Prepares games to be played.
	
	This must be called before any games happen.
	"""
	get_node("Base").hide()
	get_node("GameLocation").show()

func restore(msg):
	"""Restores to lobby mode.
	
	This destroys all things under GameLocation.
	
	Args:
		msg: string, the string to set the status message as.
	"""
	get_node("Base").show()
	get_node("GameLocation").hide()
	_set_status(msg)
	
	for child in get_node("GameLocation").get_children():
		child.queue_free()

func _refresh_players():
	"""Refreshes players listing.
	"""
	get_node("Base/PlayerList").clear()
	for player in PlayerManager.get_players_mapping():
		get_node("Base/PlayerList").add_item(player.name)

func _player_exists(id, name):
	"""Callback for disconnecting the given id with the name that is duplicated.
	"""
	rpc_id(id, "disconnected_from_server", "Name [%s] already exists, pick a new one!" % name)
	

func _player_connected(id):
	"""Callback for player connecting with the given id.
	
	This is to sync configs for the newly joining player.
	"""
	sync_configs(get_node("Base/GameOptions").selected)

func _player_disconnected(id):
	"""Callback for player disconnecting with the given id.
	
	This ends any games currently playing if game is playing.
	Also unregisters player from player listing.
	"""
	if (is_network_master()):
		if GameManager.game_started():
			var name = PlayerManager.PlayerMapping[id].name
			GameManager.rpc("game_end", "%s left the game" % name)
	PlayerManager.rpc("unregister_player", id)

func _connected_ok():
	"""Callback for client connection okay.
	
	Asks to register the player on the main server.
	"""
	PlayerManager.rpc("register_player", get_tree().get_network_unique_id(), get_node("Base/PlayerName").text)
	_set_status("Connected~")

func _server_disconnected():
	"""Callback for when sever disconnects.
	
	Ends the game if game is being played and enables hosting/joining again.
	"""
	get_node("Base/PlayerList").clear()
	set_joinstate(false, "Server disconnected!")
	if GameManager.game_started():
		GameManager.game_end("Server disconnected!")

func _connected_fail():
	"""Callback for when joining to a server fails."""
	set_joinstate(false, "Connection failed - is the target correct or host port open?")

func _on_host_pressed():
	"""Callback for when host button is clicked.
	
	Hosts the game.
	"""
	make_credit_visible(false)
	var host = NetworkedMultiplayerENet.new()
	host.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	var err = host.create_server(DEFAULT_PORT,12) # max: 1 peer, since it's a 2 players game
	if (err!=OK):
		#is another server running?
		set_joinstate(false, "Can't host, address in use.")
		return

	get_tree().set_network_peer(host)
	get_tree().set_meta("network_peer", host)
	
	set_joinstate(true, "You are the host!")
	get_node("Base/GameOptions").disabled = false
	
	PlayerManager.register_player(get_tree().get_network_unique_id(), get_node("Base/PlayerName").text)
	for game in GameMappings.values():
		game.setup_for_master()

func _on_join_pressed():
	"""Callback for when join button is clicked.
	
	Tries to join the given game address.
	"""
	make_credit_visible(false)
	set_joinstate(true, "Connecting...")

	var ip = get_node("Base/Target").text
	if (not ip.is_valid_ip_address()):
		set_joinstate(false, "Can't host, address in use.")
		return
	
	var host = NetworkedMultiplayerENet.new()
	host.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	host.create_client(ip,DEFAULT_PORT)
	get_tree().set_network_peer(host)
	get_tree().set_meta("network_peer", host)
	
sync func update_configs(id):
	"""Updates config to a config index.
	
	This is normally called whenever player list changes.
	"""
	make_credit_visible(false)
	var txt = get_node("Base/GameOptions").get_item_text(id)
	for game in GameMappings:
		GameMappings[game].visible = false
		if game == txt:
			GameMappings[game].visible = true
			GameMappings[game].sync_config()
	if (!is_network_master()):
		get_node("Base/GameOptions").select(id)

func sync_configs(id):
	"""Syncs configs for all players for the given config index.
	"""
	if (is_network_master()):
		rpc("update_configs", id)
		
func set_joinstate(disabled, msg):
	"""Enables/disables join/host button.
	
	Args:
		disabled: bool, if true, disables join/host button otherwise enables.
		msg: string, msg to set status as. """
	get_node("Base/PlayerName/JoinButton").set_disabled(disabled)
	get_node("Base/PlayerName/HostButton").set_disabled(disabled)
	_set_status(msg)
	
remote func disconnected_from_server(reason):
	"""For disconnecting players from the server.
	
	Usually called for duplicate name or for kicking players.	
	"""
	get_tree().get_meta("network_peer").close_connection()
	set_joinstate(false, reason)
	
func _set_status(msg):
	"""Sets the message status."""
	get_node("Base/Status").text = msg
	

func _on_Credit_pressed():
	"""For toggling credit when clicking credit button."""
	toggle_credit_visibility()


func _on_RichTextLabel_meta_clicked(meta):
	"""For clicking open links."""
	OS.shell_open(meta)
