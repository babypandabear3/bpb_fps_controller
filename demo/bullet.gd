extends KinematicBody

var speed = 2400
var life = 10

# Called when the node enters the scene tree for the first time.
func _ready():
	set_as_toplevel(true)
	pass # Replace with function body.


func _physics_process(delta):
	var _ret = move_and_slide(-global_transform.basis.z * speed * delta)
	if get_slide_count() > 0:
		queue_free()
		
	if life > 0:
		life -= delta
	else:
		queue_free()
