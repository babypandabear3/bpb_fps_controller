extends Area

export (float) var wind_force = 0
export (bool) var ladder = false
export (bool) var gravity_sphere = false
export (bool) var gravity_local_down = false
export (bool) var swim_area = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if gravity_sphere:
		var area = Area.new()
		area.space_override = SPACE_OVERRIDE_REPLACE
		area.gravity_point = true
		for o in get_children():
			if o is CollisionShape or o is CollisionPolygon:
				var dup = o.duplicate()
				area.add_child(dup)
				
		add_child(area)
		
	elif gravity_local_down:
		var area = Area.new()
		area.space_override = SPACE_OVERRIDE_REPLACE
		area.gravity_vec = -global_transform.basis.y
		for o in get_children():
			if o is CollisionShape or o is CollisionPolygon:
				var dup = o.duplicate()
				area.add_child(dup)
				
		add_child(area)
		
	elif swim_area:
		var area = Area.new()
		area.space_override = SPACE_OVERRIDE_REPLACE
		area.gravity = 1.0
		for o in get_children():
			if o is CollisionShape or o is CollisionPolygon:
				var dup = o.duplicate()
				area.add_child(dup)
				
		add_child(area)
		area.connect("body_entered", self, "swim_area_body_entered")
	
func swim_area_body_entered(body):
	if body is RigidBody:
		body.linear_velocity *= 0.4
		body.angular_velocity *= 0.4
