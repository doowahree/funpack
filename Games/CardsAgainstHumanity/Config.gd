extends Node2D

"""
Contains the config to show for CardsAgainstHumanity.
"""

const GameStyle_CardCzar = "Card Czar"
# TODO: Imlement this.
const GameStyle_GodIsDead = "God Is Dead"

var target_location = ""
var expansions_mappings = {}
var expansions_selected = []
var parsed_results = {}

func read_data():
	"""Reads the cards against humanity card set.
	
	Returns:
		json data.
	"""
	var cah_json_file = File.new()
	cah_json_file.open("res://Games/CardsAgainstHumanity/Asset/full.json", File.READ)
	var resulting_data = parse_json(cah_json_file.get_line())
	return resulting_data

func sync_config():
	"""Syncs the state for other players.
	"""
	rpc("_sync_expansions", expansions_selected)
	rpc("_sync_gamestyle", get_node("Container/GameStyle/Options").selected)
	rpc("_sync_points_needed", get_node("Container/PointsRequired/SpinBox").value)

slave func _sync_expansions(selected):
	"""Syncs expansion states.
	
	Args:
		selected: array of string, all expansions selected.
	"""
	if !is_network_master():
		expansions_selected = selected;
		for expansion in expansions_mappings:
			expansions_mappings[expansion].pressed = expansions_selected.has(expansion)

slave func _sync_gamestyle(id):
	"""Syncs the gamestyle.
	"""
	get_node("Container/GameStyle/Options").select(id)

slave func _sync_points_needed(amt):
	"""Syncs the points required to win.
	"""
	get_node("Container/PointsRequired/SpinBox").value = amt

func _ready():
	get_node("Container/GameStyle/Options").add_item(GameStyle_CardCzar)
	get_node("Container/GameStyle/Options").add_item(GameStyle_GodIsDead)
	# Gets the parsed results.
	parsed_results = read_data()
	
	# For each result, create a checkbox for each expansion.
	# The black/whiteCards, Base, and order are not expansions.
	for result in parsed_results:
		if !(result in ["blackCards", "whiteCards", "Base", "order"]):
			var new_box = CheckBox.new()
			new_box.text = result
			get_node("Container/Expansions").add_child(new_box)
			expansions_mappings[new_box.text] = new_box
			new_box.connect("toggled", self, "checkbox_pressed", [new_box])
			new_box.disabled = true
			new_box.hint_tooltip = parsed_results[result]["name"]

func setup_for_master():
	"""Sets up selectibility for the master.
	"""
	get_node("Container/PointsRequired/SpinBox").editable = true
	get_node("Container/GameStyle/Options").disabled = false
	get_node("Container/Button").disabled = false
	for cb in expansions_mappings.values():
		cb.disabled = false

func checkbox_pressed(state, box_ref):
	"""Callback for when checkbox is pressed.
	"""
	if (state):
		expansions_selected.append(box_ref.text)
	else:
		expansions_selected.erase(box_ref.text)
	sync_config()
	print(expansions_selected)

func _on_Options_item_selected( ID ):
	"""Callback for when option is changed."""
	sync_config()

func _on_SpinBox_value_changed( value ):
	"""Callback for when value is changed for wins required."""
	sync_config()


func _on_Button_pressed():
	"""Callback for game start."""
	if (is_network_master()):
		# Be sure to call the prep master first before any game start!
		# This makes sure that the master is expecting sync!
		PlayerManager.prep_master()
		rpc("start_game")

sync func start_game():
	"""Starts the game."""
	var game = load("res://Games/CardsAgainstHumanity/Main.tscn").instance()
	game.config = self
	if get_node("Container/GameStyle/Options").text == GameStyle_GodIsDead:
		game.game_style = game.GAME_STYLE.GOD_IS_DEAD
	game.wins_required = get_node("Container/PointsRequired/SpinBox").value
	GameManager.game_start()
	get_node(target_location).add_child(game)
