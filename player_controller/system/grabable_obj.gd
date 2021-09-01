extends RigidBody

var grabbed = false
var target_obj = null
var target_rotation_body = null
var speed = 1000

var first_x
var first_y
var first_z

var rot_y_add = 0

var external_force = Vector3.ZERO

func _ready():
	pass # Replace with function body.


func _physics_process(delta):
	if grabbed:

		var vel = (target_obj.global_transform.origin - global_transform.origin)
		
		var lerp_x = lerp_angle(rotation.x, first_x, 0.1)
		var lerp_y = lerp_angle(rotation.y, target_rotation_body.rotation.y + rot_y_add, 0.1)
		var lerp_z = lerp_angle(rotation.z, first_z, 0.1)
		
		lerp_x = (lerp_x - rotation.x)
		lerp_y = (lerp_y - rotation.y)
		lerp_z = (lerp_z - rotation.z)
		
		var new_rot = Vector3(lerp_x * delta * 30, lerp_y  * delta * 2400, lerp_z * delta * 30)
		
		
		angular_velocity = new_rot
		linear_velocity = vel * speed * delta
		
		
		if vel.length() > 5 : #drop because it's too far
			grabbed = false
			target_obj = null
			angular_velocity = Vector3()
			linear_velocity = Vector3()
			gravity_scale = 1
		
	else:
		if not external_force.is_equal_approx(Vector3.ZERO):
			apply_central_impulse((external_force * delta) + (Vector3.UP * 0.1))
			# "+ (Vector3.UP * 0.1)" PART IS A FIX TO PREVENT STUCK ON FLOOR
			
func activate(adata):
	if not grabbed:
		grabbed = true
		target_obj = adata.holder
		target_rotation_body = adata.body
		gravity_scale = 0
		angular_velocity = Vector3()
		
		first_x = rotation.x
		first_y = rotation.y
		first_z = rotation.z
		
		var deg_first_y = rad2deg(first_y)
		var deg_body_y = rad2deg(target_rotation_body.rotation.y)
		
		if deg_first_y < -135 and deg_body_y > 135:
			deg_first_y += 360
			
		if deg_first_y > 135 and deg_body_y < -135:
			deg_body_y += 360
		
		var deg_diff = (deg_first_y - deg_body_y) + 45

		if deg_diff >= 0 and deg_diff <= 90:
			rot_y_add = deg2rad(0)
		elif deg_diff > 90 and deg_diff <= 180:
			rot_y_add = deg2rad(90)
		elif deg_diff > 180 and deg_diff <= 270:
			rot_y_add = deg2rad(180)
		elif deg_diff > 270 and deg_diff <= 360:
			rot_y_add = deg2rad(-90)
			
		elif deg_diff < 0 and deg_diff >= -90:
			rot_y_add = deg2rad(-90)
		elif deg_diff < -90 and deg_diff >= -180:
			rot_y_add = deg2rad(-180)
		elif deg_diff < -180 and deg_diff >= -270:
			rot_y_add = deg2rad(90)
		elif deg_diff < -270 and deg_diff >= -360:
			rot_y_add = deg2rad(0)
			
		else:
			print("wrongly calculated ", deg_diff)
			rot_y_add = deg2rad(0)
			
	else:
		grabbed = false
		target_obj = null
		target_rotation_body = null
		angular_velocity = Vector3()
		linear_velocity = adata.release_force
		gravity_scale = 1
		
		
func wind_force_add(force):
	external_force += force
	
func get_grabbed_status():
	return grabbed
