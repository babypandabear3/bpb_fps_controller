extends Area

export (Vector3) var force = Vector3(0, 20, 0)
export (bool) var clear_velocity_h = false
export (bool) var clear_velocity_v = true


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_jump_pad_body_entered(body):
	if body.has_method("back_to_walk"):
		body.back_to_walk()
		
	if clear_velocity_h:
		if body.has_method("clear_velocity_h"):
			body.clear_velocity_h()
		if body is RigidBody:
			body.linear_velocity *= Vector3(0,1,0)
	
	if clear_velocity_v:
		if body.has_method("clear_velocity_v"):
			body.clear_velocity_v()
		if body is RigidBody:
			body.linear_velocity *= Vector3(1,0,1)
		
	if body.has_method("apply_central_impulse"):
		var force_vector = (global_transform.basis.x * force.x) + (global_transform.basis.y * force.y) + (global_transform.basis.z * force.z)
		body.apply_central_impulse(force_vector)
