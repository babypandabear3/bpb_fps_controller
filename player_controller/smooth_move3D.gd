extends Spatial

export (NodePath) var follow_target

var physic_fps : float = 0.0

var target : Spatial

# Called when the node enters the scene tree for the first time.
func _ready():
	set_as_toplevel(true)
	target = get_node_or_null(follow_target)
	if target == null:
		target = get_parent()
	physic_fps = ProjectSettings.get_setting("physics/common/physics_fps") - 0.5
	global_transform = target.global_transform
	
	

func _process(delta):
	global_transform = global_transform.interpolate_with(target.global_transform, delta * physic_fps)
