extends Node

var player
var points
var required
var selected = []

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

func won():
	return points >= required

func reset():
	selected = []

func add_selected(selection):
	selected += selection

func get_selected():
	return selected

func register(player, win_required):
	self.player = player
	get_node("Name").text = player.name
	self.points = 0
	required = win_required
	add_point(0)
	
	
func update_score():
	get_node("Points").text = "%s / %s" % [points, required]

func add_point(amt):
	points = points + amt
	get_node("AnimationPlayer").play("PlusPoint")

func set_state(state):
	get_node("State").text = state
	


#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
