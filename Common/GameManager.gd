extends Node

signal start_game
signal end_game(msg)

enum GAME_STATE {GAME_LOBBY, GAME_STARTED}
var game_state = GAME_STATE.GAME_LOBBY

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

sync func game_start():
	if game_state == GAME_STATE.GAME_LOBBY:
		game_state = GAME_STATE.GAME_STARTED
		emit_signal("start_game")
	
func game_started():
	return game_state == GAME_STATE.GAME_STARTED

sync func game_end(msg):
	if game_state == GAME_STATE.GAME_STARTED:
		game_state = GAME_STATE.GAME_LOBBY
		emit_signal("end_game", msg)