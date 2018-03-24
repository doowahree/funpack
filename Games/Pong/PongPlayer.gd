extends KinematicBody2D

slave var pos = Vector2()
slave var vel = Vector2()

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

func _physics_process(delta):
	var motion = Vector2(0, 0)
	if (is_network_master()):
		if (Input.is_action_pressed("move_left")):
			motion += Vector2(-1, 0)
		if (Input.is_action_pressed("move_right")):
			motion += Vector2(1, 0)
		if (Input.is_action_pressed("move_up")):
			motion += Vector2(0, -1)
		if (Input.is_action_pressed("move_down")):
			motion += Vector2(0, 1)
			
		rset_unreliable("vel", motion)
		rset_unreliable("pos", position)
	else:
		position = pos
		motion = vel
	move_and_slide(motion * 200)
	if (not is_network_master()):
		pos = position # To avoid jitter
#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
