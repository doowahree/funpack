extends Node

signal PlayerListChanged
signal PlayerExists(id, name)
signal WaitingForPlayers
signal APlayerReady(remaining)
signal AllReady

var PlayerMapping = {}
sync var remaining_players = 0

class Player:
	var id = -1
	var raw_name = ""
	var name = ""
	var ready = false
	func _init(id, name, your_id):
		self.id = id
		self.name = name
		self.raw_name = name
		if id == your_id:
			self.name = "*%s*" % name
		if id == 1:
			self.name += "(Host)"
	
	static func sort_by_id(a, b):
		if a.id < b.id:
			return true
		return false

func get_player(player_id):
	return PlayerMapping[player_id]

func get_player_by_name(name):
	for player in get_players_mapping():
		if player.name == name:
			return player

func get_players_mapping():
	var players = PlayerMapping.values()
	players.sort_custom(Player, "sort_by_id")
	return players

func count_not_ready_players():
	var counter = 0
	for player in self.get_players_mapping():
		if !player.ready:
			counter += 1
	return counter

sync func all_players_ready():
	get_tree().paused = false
	emit_signal("AllReady")

sync func ready_player(id):
	PlayerMapping[id].ready = true
	emit_signal("APlayerReady", remaining_players - 1)
	
	if (is_network_master()):
		var remaining = count_not_ready_players()
		rset("remaining_players", remaining)
		print("Player registered - remaining %s" % remaining)
		if remaining == 0:
			rpc("all_players_ready")

func wait_for_players():
	emit_signal("WaitingForPlayers")
	get_tree().paused = true
	rpc("ready_player", get_tree().get_network_unique_id())

# This needs to be called before the nodes actually start loading!
master func prep_master():
	for player in self.get_players_mapping():
		player.ready = false
	rset("remaining_players", PlayerMapping.size())
	
sync func sync_register_player(id, name):
	print("%s joined" % name)
	if is_network_master() and id != 1:
		for player_id in PlayerMapping:
			rpc_id(id, "sync_register_player", player_id, PlayerMapping[player_id].raw_name)
			if player_id != 1:
				rpc_id(player_id, "sync_register_player", id, name)
	PlayerMapping[id] = Player.new(id, name, get_tree().get_network_unique_id())
	emit_signal("PlayerListChanged")

master func register_player(id, name):
	for player in get_players_mapping():
		if player.name == name:
			emit_signal("PlayerExists", id, name)
			return
	rpc("sync_register_player", id, name)
	

sync func unregister_player(id):
	if id in PlayerMapping:
		PlayerMapping.erase(id)	
		emit_signal("PlayerListChanged")