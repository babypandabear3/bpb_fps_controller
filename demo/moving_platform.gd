extends Spatial

export (Vector3) var move_to = Vector3(0,0,-6)

# Called when the node enters the scene tree for the first time.
func _ready():
	get_node("platform_kine").set_target(move_to)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
