extends Container

enum SELECTION_STATE {NONE, SELECTED}

signal action_pressed(target)

var idx
var pos
var player_id
var text
var state = SELECTION_STATE.NONE
var disabled_state = false
var order = 0

func is_selected():
	return state != SELECTION_STATE.NONE

func selected():
	state = SELECTION_STATE.SELECTED
	get_node("ColorRect").color = Color(0.6, 1, 0.6)
	# get_node("Container/TextureButton").disabled = true

func disable():
	get_node("ColorRect").color = Color(.4, .4, .4)
	state = SELECTION_STATE.NONE
	disabled_state = true
	
func enable():
	get_node("ColorRect").color = Color(1, 1, 1)
	state = SELECTION_STATE.NONE
	disabled_state = false

sync func register(pos, idx, player_id, text):
	self.pos = pos
	self.idx = idx
	self.player_id = player_id
	self.text = text
	get_node("AnimationPlayer").play("Refresh")

func refresh():
	get_node("Container/Text").text = text

func _on_TextureButton_pressed():
	emit_signal("action_pressed", self)
