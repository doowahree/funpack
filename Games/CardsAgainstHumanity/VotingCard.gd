extends Container

const CardTextRenderScript = preload("res://Games/CardsAgainstHumanity/CardTextRender.gd")
var player_id
signal chosen(player_id, idx)
signal reveal(id)
signal voted
var valid
var text
var revealable = false
var idx = 0

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

func enable():
	get_node("Container/Select").disabled = false
	get_node("Container/Text").bbcode_text = "[center][url={'data'='hi'}]Click to Reveal[/url][/center]"

func disable():
	get_node("Container/Select").disabled = true

func register(player_id, black_card, white_cards):
	if white_cards.size() == 0:
		get_node("Container/Text").bbcode_text = "Czar"
		disable()
		valid = false
		return
	
	valid = true
	self.player_id = player_id
	text = CardTextRenderScript.Render(black_card, white_cards)
	get_node("Container/Text").bbcode_text = "[center][url={'data'='hi'}]Waiting for Czar to reveal[/url][/center]"

func set_text():
	get_node("Container/Text").bbcode_text = text

func _on_Select_pressed():
	emit_signal("chosen", player_id, idx)

sync func sync_reveal():
	get_node("AnimationPlayer").play("Reveal")

func _on_Text_meta_clicked( meta ):
	if revealable:
		emit_signal("reveal", idx)

func selected_anim():
	emit_signal("voted")
	
func play_chosen():
	get_node("AnimationPlayer").play("Select")
