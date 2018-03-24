extends Node2D

enum GAME_STYLE {CARD_CZAR, GOD_IS_DEAD}

const game_state_class = preload("res://Games/CardsAgainstHumanity/GameState.gd")
var game_state = game_state_class.new()

var game_style = GAME_STYLE.CARD_CZAR
var wins_required = 10

var victor = ""

var config
var whitecards = []
var blackcards = []
var available_whitecards_indexes = []
var available_blackcards_indexes = []
var white_cards_deck
var black_cards_deck
var card_dealing_required = 10

var hand = []
var voting_cards = []
var players = {}
sync var selection_required = 1
var card_czar = -1
var card_czar_id = -1
var waiting_for_players = 0
var card_selected = []
var is_czar = false
sync var current_blackcard_idx = -1

const Player = preload("res://Games/CardsAgainstHumanity/Player.tscn")
const Card = preload("res://Games/CardsAgainstHumanity/Card.tscn")
const VotingCard = preload("res://Games/CardsAgainstHumanity/VotingCard.tscn")
const Deck = preload("res://Games/CardsAgainstHumanity/Deck.gd")
const CardTextRenderScript = preload("res://Games/CardsAgainstHumanity/CardTextRender.gd")

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	PlayerManager.connect("AllReady", self, "_all_ready")
	PlayerManager.connect("APlayerReady", self, "_a_player_ready")
	PlayerManager.connect("WaitingForPlayers", self, "_waiting")
	whitecards = config.parsed_results["whiteCards"]
	blackcards = config.parsed_results["blackCards"]
	if (is_network_master()):
		do_host_work()
	
	for i in range(10):
		var card = Card.instance()
		hand.append(card)
		get_node("Hand/CardContainer").add_child(card)
		card.connect("action_pressed", self, "card_selected_action")
	
	PlayerManager.wait_for_players()

func do_host_work():
	for expansion in (["Base"] + config.expansions_selected):
		var expansion_info = config.parsed_results[expansion]
		available_whitecards_indexes += expansion_info["white"]
		available_blackcards_indexes += expansion_info["black"]
	white_cards_deck = Deck.new(available_whitecards_indexes)
	black_cards_deck = Deck.new(available_blackcards_indexes)
	if game_style == GAME_STYLE.CARD_CZAR:
		card_czar = 0
	

func _all_ready():
	
	for player in PlayerManager.get_players_mapping():
		if player.id == get_tree().get_network_unique_id():
			get_node("Label").text = "Goodluck Have Fun %s!" % player.name
		var p = Player.instance()
		p.register(player, wins_required)
		players[player.id] = p
		get_node("Panel/Players").add_child(p)
		
		var voting_card = VotingCard.instance()
		voting_card.idx = voting_cards.size()
		get_node("Selection/CardContainer").add_child(voting_card)
		voting_cards.append(voting_card)
		voting_card.connect("chosen", self, "vote_player")
		voting_card.connect("reveal", self, "reveal_voting_card")
		print("Registered %s" % get_node("Selection/CardContainer").get_children().size())
	call_deferred("start_round")
	if (is_network_master()):
		deal_starting_hand()
	

func _waiting():
	get_node("Label").text = "Waiting for sync..."
	
func _a_player_ready(remaining):
	get_node("Label").text = "Waiting for sync... %s remain" % remaining

sync func set_blackcard_text(txt):
	get_node("Hand/BlackCard/Description").bbcode_text = txt

remote func set_whitecard_text(idx, card_idx):
	hand[idx].register(idx, card_idx, get_tree().get_network_unique_id(), whitecards[card_idx])

func deal_starting_hand():
	for i in range(10):
		for player in PlayerManager.get_players_mapping():
			if player.id == 1:
				set_whitecard_text(i, white_cards_deck.deal())
			else:
				rpc_id(player.id, "set_whitecard_text", i, white_cards_deck.deal())

remote func set_hand_state(enable):
	for i in range(10):
		if enable:
			hand[i].enable()
		else:
			hand[i].disable()

sync func set_status(id, status, enable):
	players[id].set_state(status)
	if (get_tree().get_network_unique_id() == id):
		set_hand_state(enable)
		

sync func set_czar(id):
	players[id].set_state("Czar")
	if (get_tree().get_network_unique_id() == id):
		set_hand_state(false)
		is_czar = true

master func refresh_card(id, hand_idx):
	print("refresh called")
	if id == 1:
		set_whitecard_text(hand_idx, white_cards_deck.deal())
	else:
		rpc_id(id, "set_whitecard_text", hand_idx, white_cards_deck.deal())

sync func update_hand_buttons():
	
	var _white_card_texts = []
	if card_selected.size() == 0:
		get_node("Hand/BlackCard/Description").bbcode_text = blackcards[current_blackcard_idx].text
	
	for i in range(selection_required):
		if i < card_selected.size():
			_white_card_texts.append(card_selected[i].text)
		else:
			_white_card_texts.append("_")
	get_node("Hand/BlackCard/Description").bbcode_text = (
		CardTextRenderScript.Render(blackcards[current_blackcard_idx], _white_card_texts))
	if is_czar:
		get_node("Hand/Submit").disabled = true
		get_node("Hand/Submit").text = "You are czar"
	elif card_selected.size() != selection_required:
		get_node("Hand/Submit").disabled = true
		get_node("Hand/Submit").text = "Pick %s more" % (selection_required - card_selected.size())
	else:
		get_node("Hand/Submit").disabled = false
		get_node("Hand/Submit").text = "Submit"
		for i in range(10):
			if !(hand[i] in card_selected):
				hand[i].disable()
		

sync func start_round():
	card_selected = []
	is_czar = false
	get_node("Hand").visible = true
	get_node("Selection").visible = false
	if (is_network_master()):
		rset("current_blackcard_idx", black_cards_deck.deal())
		black_cards_deck.add_back(current_blackcard_idx)
		var selected_black_card = blackcards[current_blackcard_idx] 
		rpc("set_blackcard_text", selected_black_card.text)
		rset("selection_required", selected_black_card.pick)
		
		if card_czar != -1:
			card_czar_id = players.keys()[card_czar]
			card_czar = (card_czar + 1) % players.size()
		for player_id in players:
			players[player_id].reset()
			if player_id == card_czar_id:
				rpc("set_czar", player_id)
			else:
				rpc("set_status", player_id, "Choosing", true)
		rpc("update_hand_buttons")

sync func start_voting():
	get_node("Hand").visible = false
	get_node("Selection").visible = true
	get_node("AnimationPlayer").play("RevealChoices")
	for card in voting_cards:
		if is_czar:
			card.revealable = true
			if card.valid:
				card.enable()
			else:
				card.disable()
		else:
			card.revealable = false
			card.disable()

func vote_player(player_id, card_idx):
	rpc("synced_vote_player", get_tree().get_network_unique_id(), player_id, card_idx)
	for card in voting_cards:
		card.disable()

sync func victory(player_name):
	get_node("AnimationPlayer").play("Victory")
	get_node("VictorySweep/Label").text = "Congrats %s" % player_name
	victor = player_name

func end_game_for_all():
	if is_network_master():
		GameManager.rpc("game_end", "Congrats! %s won" % victor)

sync func give_point(player_id, amt, card_idx, start_new_round):
	players[player_id].add_point(amt)
	if is_network_master():
		
		if voting_cards[card_idx].is_connected("voted", self, "rpc"):
			voting_cards[card_idx].disconnect("voted", self, "rpc")
		if players[player_id].won():
			rpc("victory", PlayerManager.get_player(player_id).name)
		else:
			if start_new_round:
				voting_cards[card_idx].connect("voted", self, "rpc", ["start_round"])
	voting_cards[card_idx].play_chosen()
	

master func synced_vote_player(voting_id, voted_id, card_idx):
	if card_czar_id == voting_id:
		rpc("give_point", voted_id, 1, card_idx, true)

sync func sync_vote_card(card_pos, player_id, black_card_id, white_card_ids):
	var whitecard_selected = []
	for id in white_card_ids:
		whitecard_selected.append(whitecards[id])
	voting_cards[card_pos].register(player_id, blackcards[black_card_id], whitecard_selected)

master func sync_card_selected(player_id, card_ids, white_card_ids):
	for card_id in card_ids:
		refresh_card(player_id, card_id)
	players[player_id].add_selected(white_card_ids)
	rpc("set_status", player_id, "Done", false)
	for player_id in players:
		if players[player_id].get_selected().size() == 0 and player_id != card_czar_id:
			print("%s not meets requirement" % player_id)
			return
	# All players are ready
	# Register voteable cards.
	var card_positions = range(players.size())
	for i in range(players.size()):
		var idx_1 = randi() % card_positions.size()
		var idx_2 = randi() % card_positions.size()
		var tmp_store = card_positions[idx_1]
		card_positions[idx_1] = card_positions[idx_2]
		card_positions[idx_2] = tmp_store
		
	var card_pos = 0
	for player_id in players:
		rpc("sync_vote_card", card_positions[card_pos], player_id, current_blackcard_idx, players[player_id].get_selected())
		card_pos += 1
	
	# Let's go to reveal phase!.
	rpc("start_voting")

func reveal_voting_card(idx):
	if is_czar:
		rpc("sync_reveal_voting_card", idx)

sync func sync_reveal_voting_card(idx):
	voting_cards[idx].sync_reveal()
	

func card_selected_action(card):
	if is_czar:
		return
	if card_selected.size() >= selection_required or card.is_selected(): 
		card_selected = []
		set_hand_state(true)
	card.selected()
	card_selected.append(card)
	update_hand_buttons()

func _on_hand_reset_pressed():
	card_selected = []
	set_hand_state(true)
	update_hand_buttons()


func _on_hand_submit_pressed():
	var card_ids = []
	var white_card_ids = []
	
	for card in card_selected:
		card_ids.append(card.pos)
		white_card_ids.append(card.idx)
	set_hand_state(false)
	get_node("Hand/Submit").disabled = true
	rpc("sync_card_selected", get_tree().get_network_unique_id(), card_ids, white_card_ids)
