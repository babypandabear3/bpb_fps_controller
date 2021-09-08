#THIS CONTROLLER IS DESIGNED FOR 60 PHYSIC FPS
extends KinematicBody

class_name BPB_Fps_Controller

signal body_just_landed
signal body_just_jump
signal body_just_crouch
signal body_just_stand
signal body_climb_start
signal body_climb_end
signal body_ladder_start
signal body_ladder_end
signal body_slide_start
signal body_slide_end
signal body_pulled_start
signal body_pulled_end
signal body_wallrun_start
signal body_wallrun_end
signal body_swim_start
signal body_swim_end

enum STATELIST {
	WALK,
	CLIMB,
	LADDER,
	SLIDE,
	WALLRUN,
	PULLED,
	SWIM,
}

enum BODY_HEIGHT_LIST {
	STAND,
	CROUCH,
	UNCROUCHING
}

export (bool) var feat_crouching = true
export (bool) var feat_climbing = true
export (bool) var feat_slide = true
export (bool) var feat_wallrun = true
export (bool) var stand_after_slide = true
export (bool) var stand_after_climb = true

export (float) var MOUSE_SENSITIVITY = 0.07
export (bool) var air_control = false
export (String, "C0.6", "C0.7", "C0.8", "C0.9") var crouch_anim = "C0.9"
export (float) var speed_h_max = 360
export (float) var speed_acc = 30
export (float) var speed_deacc = 48
export (float) var sprint_modi = 1.5
export (float) var crouch_modi = 0.6
export (float) var coyote_time : float = 0.2
export (float) var gravity_force = 30
export (float) var gravity_acc = 20
export (float) var jump_force = -6
export (int) var jump_limit = 1
export (float) var slope_limit = 46.0
export (float) var on_slope_steep_speed = 1.0
export (float) var slide_time = 1.2
export (float) var bump_force = 10
export (float) var swim_h_deacc = 58
export (float) var swim_v_deacc = 0.95

var gravity_vector_default  = Vector3.DOWN
var gravity_vector = gravity_vector_default
var gravity_obj = null

var body_height : int = BODY_HEIGHT_LIST.STAND
var is_grabbing_object = false

var jump_skip_timer = 0
var jump_skip_timeout = 0.1
var just_landed = false

var dir = Vector3()
var prev_vel_h = Vector3()
var prev_vel_v = Vector3()

var velocity = Vector3()
var velocity_h = Vector3()
var velocity_v = Vector3()

var vertical_vector = Vector3.DOWN
var on_floor_vertical_speed = 0.1
var snap_vector = Vector3.DOWN
var snap_vector_length = 0.5

var speed_v = 0
var sprint_modifier = 1
var sprint_modi_nonactive = 1.0

var activate_data = {}

var climb_target0 = Vector3()
var climb_target1 = Vector3()
var climb_timer = 0
var climb_timeout = 0.6
var climb_phase = 0
var climb_y_addition = 0
var climb_stair = false

var automove_dir = Vector3()
var slide_timer = 0

var floor_angle = 0.0
var floor_collision = null
var floor_normal = -gravity_vector
	
var floor_obj = null
var floor_prev_rot = null

var jump_count = 0
var wallrun_left = false
var impulse = Vector3.ZERO

var pulled_distance = 0
var pulled_start = Vector3.ZERO
var pulled_target = Vector3.ZERO
var pulled_speed = 60
var pulled_dir = Vector3.ZERO
var pulled_timer = 0

#SWIM
var swim_area_count = 0

#SIGNAL LOGIC
var ladder_count : int = 0
var external_force : Vector3 = Vector3.ZERO

#INPUT
var input_jump_timeout = 0.2
var air_borne : float = 0.0
var air_borne_disable_snap = 0.4

var input_h : float = 0.0
var input_v : float = 0.0
var input_jump_buffer : float = 0.0
var input_jump_just_pressed : bool = false
var input_sprint : bool = false
var input_sprint_just_pressed : bool = false
var input_crouch_just_pressed : bool = false
var input_jump_pressed : bool = false

onready var state = STATELIST.WALK
onready var ap = $AnimationPlayer
onready var rotation_helper = $rotation_helper
onready var camera_root = $rotation_helper/camera_root

onready var ray_uncrouch = $ray_uncrouch

onready var ray_climb1 = $ray_climb1
onready var ray_climb2 = $ray_climb2
onready var ray_climb3 = $ray_climb3

onready var root_ray_stair = $root_ray_stair
onready var ray_stair1 = $root_ray_stair/ray_stair1
onready var ray_stair2 = $root_ray_stair/ray_stair2
onready var ray_wallrun = $root_ray_stair/ray_wallrun

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	ray_climb1.add_exception(self)
	ray_climb2.add_exception(self)
	ray_climb3.add_exception(self)
	ray_uncrouch.add_exception(self)
	
	ray_stair1.add_exception(self)
	ray_stair2.add_exception(self)
	ray_wallrun.add_exception(self)
	
	air_borne_disable_snap = coyote_time + 0.1
	
	match crouch_anim:
		"C0.6":
			climb_y_addition = 0.3
		"C0.7":
			climb_y_addition = 0.4
		"C0.8":
			climb_y_addition = 0.5
		"C0.9":
			climb_y_addition = 0.6
	
func _input(event):
	#MOUSE CAMERA
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotation.x += -deg2rad(event.relative.y * MOUSE_SENSITIVITY)
		
		var basis_target = global_transform.basis
		basis_target.x = basis_target.x.rotated(-gravity_vector, deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1)).normalized()
		basis_target.y = -gravity_vector.normalized()
		basis_target.z = basis_target.x.cross(basis_target.y).normalized()
		global_transform.basis = basis_target
		
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
		
func _process(delta):
	#ALIGN WITH FLOOR
	var gt_target = global_transform
	gt_target.basis.y = -gravity_vector
	gt_target.basis.z = gt_target.basis.x.cross(gt_target.basis.y)
	gt_target.basis.x = -gt_target.basis.z.cross(gt_target.basis.y)
	gt_target = gt_target.orthonormalized()
	global_transform = global_transform.interpolate_with(gt_target, delta * 6)
	
	#TIMER
	if jump_skip_timer > 0:
		jump_skip_timer -= delta
		
	if input_jump_buffer > 0:
		input_jump_buffer -= delta
		
	if slide_timer > 0:
		slide_timer -= delta
	
func user_input():
	input_sprint = false
	input_sprint_just_pressed = false
	input_crouch_just_pressed = false
	input_jump_pressed = false
	
	input_h = Input.get_action_strength("movement_right") - Input.get_action_strength("movement_left")
	input_v = Input.get_action_strength("movement_forward") - Input.get_action_strength("movement_backward")
	
	#SPRINT - STOP
		
	#INPUT JUST PRESSED
	if Input.is_action_just_pressed("movement_jump"):
		input_jump_buffer = input_jump_timeout
		
	if Input.is_action_pressed("movement_jump"):
		input_jump_pressed = true
		
	if Input.is_action_just_pressed("action_crouch_toggle"):
		input_crouch_just_pressed = true
		
	#SPRINT
	if Input.is_action_pressed("action_sprint"):
		input_sprint = true
		
	#PRESS ESC TO QUIT GAME
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
		
	#TOGGLE FLY (LADDER) MODE
	if Input.is_action_just_pressed("action_fly_toggle"):
		if state == STATELIST.WALK:
			start_ladder()
		else:
			start_walk()
		
func _physics_process(delta):
	if gravity_obj == null:
		gravity_vector = gravity_vector_default
	else:
		if gravity_obj:
			if gravity_obj.gravity_sphere:
				gravity_vector = (gravity_obj.global_transform.origin - global_transform.origin).normalized()
			elif gravity_obj.gravity_local_down:
				gravity_vector = -gravity_obj.global_transform.basis.y

	#GET USER INPUT VALUE
	user_input()
	
	match state:
		STATELIST.WALK:
			do_walk(delta)
		STATELIST.CLIMB:
			do_climb(delta)
		STATELIST.LADDER:
			do_ladder(delta)
		STATELIST.SLIDE:
			do_slide(delta)
		STATELIST.WALLRUN:
			do_wallrun(delta)
		STATELIST.PULLED:
			do_pulled(delta)
		STATELIST.SWIM:
			do_swim(delta)

	if is_on_floor():
		just_landed = false
		if air_borne > 0:
			emit_signal("body_just_landed")
			just_landed = true
		air_borne = 0.0
		jump_count = 0
	else:
		air_borne += delta
		if air_borne > coyote_time and jump_count == 0:
			jump_count += 1
			
	
	
func try_climb_stairs():
	
	ray_stair1.force_update_transform()
	ray_stair2.force_update_transform()
	ray_stair1.force_raycast_update()
	ray_stair2.force_raycast_update()
	
	var ret = false
	if ray_stair2.is_colliding() and velocity_h.length() > 0.1:
		var angle2 = rad2deg( ray_stair2.get_collision_normal().angle_to(-gravity_vector) )
		if angle2 > 80.0:
			if ray_stair1.is_colliding():
				var angle = rad2deg( ray_stair1.get_collision_normal().angle_to(-gravity_vector) )
				if angle > 80.0:
					var d1 = ray_stair1.global_transform.origin.distance_to(ray_stair1.get_collision_point())
					var d2 = ray_stair2.global_transform.origin.distance_to(ray_stair2.get_collision_point())
					if (d1 - d2) > 0.1:
						ret = true
			else:
				ret = true
	return ret

func body_height_crouch():
	body_height = BODY_HEIGHT_LIST.CROUCH
	

func body_height_stand():
	body_height = BODY_HEIGHT_LIST.STAND
	sprint_modifier = sprint_modi_nonactive
	
func _on_AnimationPlayer_animation_finished(_anim_name):
	call_deferred("emit_signal_body_height")
	
func emit_signal_body_height():
	if body_height == BODY_HEIGHT_LIST.STAND:
		emit_signal("body_just_stand")
	elif body_height == BODY_HEIGHT_LIST.CROUCH:
		emit_signal("body_just_crouch")
		
func start_walk():
	state = STATELIST.WALK
	
	if stand_after_slide:
		if body_height != BODY_HEIGHT_LIST.STAND:
			body_height = BODY_HEIGHT_LIST.UNCROUCHING
			
	if stand_after_climb:
		if body_height != BODY_HEIGHT_LIST.STAND:
			body_height = BODY_HEIGHT_LIST.UNCROUCHING
	
func do_walk(delta):
	if input_sprint:
		sprint_modifier = sprint_modi
	else:
		sprint_modifier = sprint_modi_nonactive
		
	#DEFAULT VERTICAL MOVEMENT VALUE
	floor_normal = -gravity_vector
	vertical_vector = gravity_vector
	snap_vector = gravity_vector * snap_vector_length
	floor_angle = 0.0
	floor_collision = null
	if jump_skip_timer > 0:
		snap_vector = Vector3.ZERO
			
	
	#IF CAN DETECT FLOOR, GET COLLISION INFORMATION WITH FLOOR, WITH LARGEST ANGLE
	if is_on_floor() and get_slide_count() > 0:
		for i in get_slide_count():
			var tmp_col = get_slide_collision(i)
			
			floor_collision = tmp_col
			floor_normal = tmp_col.normal
		
		if ray_wallrun.is_colliding():
			floor_normal = ray_wallrun.get_collision_normal()
		floor_angle = -gravity_vector.angle_to(floor_normal)
		
		if gravity_obj == null:
			#ROTATE BODY TO FOLLOW FLOOR ROTATION, Y AXIS ONLY
			if floor_obj != floor_collision.collider: #FIRST TIME BEING ON FLOOR, SAVE CURRENT FLOOR ROTATION FOR CALCULATION NEXT FRAME
				floor_obj = floor_collision.collider
				floor_prev_rot = floor_obj.rotation * Vector3(0,1,0)
			else: #APPLY FLOOR ROTATION TO BODY
				var floor_rot = (floor_obj.rotation - floor_prev_rot) * Vector3(0,1,0)
				rotation += floor_rot
				floor_prev_rot = floor_obj.rotation * Vector3(0,1,0)
			
	else: #NOT TOUCHING FLOOR, DISABLE FLOOR ROTATION
		floor_obj = null
		floor_prev_rot = null
		
	#DEFINE HORIZONTAL MOVEMENT VECTOR
	var dir_x = camera_root.global_transform.basis.x * input_h
	var dir_z = -camera_root.global_transform.basis.z * input_v
	var horizontal_vector = (dir_x + dir_z).slide(floor_normal).normalized()
	
	#HORIZONTAL VELOCITY
	if Vector2(input_h, input_v).length() < 0.4:
		#DEACCELERATION
		velocity_h = prev_vel_h * delta * speed_deacc
	else:
		#ACCELERATION
		if body_height == BODY_HEIGHT_LIST.CROUCH:
			sprint_modifier = crouch_modi
		if velocity_h.length() > (speed_h_max * sprint_modifier * delta):
			#SPEED LIMIT. IF GOING TOO FAST, MAKE HORIZONTAL VELOCITY VECTOR SHORTER / SLOWER
			velocity_h = prev_vel_h * delta * speed_deacc
		else:
			#INCREASE MOVEMENT VECTOR BY ADDING NEW MOVEMENT VECTOR TO PREVIOS FRAME HORIZONTAL VELOCITY
			velocity_h = prev_vel_h + (horizontal_vector * speed_acc * delta)
		
	#IF NOT USING AIR CONTROL, THEN USE PREVIOUS HORIZONTAL VELOCITY WHEN ON AIR
	if not is_on_floor() and not air_control:
		velocity_h = prev_vel_h
	
	#ROTATE ROOT RAY STAIR
	var look_at_target = root_ray_stair.global_transform.origin + velocity_h.slide(-gravity_vector)
	if not look_at_target.is_equal_approx(root_ray_stair.global_transform.origin):
		root_ray_stair.look_at(look_at_target, -gravity_vector)
	
	#DISABLE SNAP WHEN CLIMBING STAIR OR BEING AIR BORNE FOR TOO LONG
	climb_stair = try_climb_stairs()
	
	if climb_stair or air_borne > air_borne_disable_snap:
		snap_vector = Vector3()
		
	#VERTICAL VELOCITY
	if input_jump_buffer > 0 and jump_count < jump_limit :
		#START JUMP
		velocity_v = vertical_vector * jump_force
		jump_skip_timer = jump_skip_timeout
		input_jump_buffer = 0
		snap_vector = Vector3.ZERO
		jump_count += 1
		emit_signal("body_just_jump")
	elif is_on_floor() and jump_skip_timer <= 0: 
		#ON FLOOR
		if floor_angle <= deg2rad(slope_limit): #STICKING ON FLOOR / SLOPE
			if floor_collision:
				vertical_vector = -floor_collision.normal
				snap_vector = -floor_collision.normal
			velocity_v = vertical_vector * 0.1
		else: #SLOPE TOO STEEP, SLIDE DOWN
			if not climb_stair:
				var slide_vector = floor_normal
				slide_vector.y = 0
				slide_vector = slide_vector.normalized()
				velocity_h = velocity_h.slide(slide_vector)
				vertical_vector = vertical_vector.slide(floor_collision.normal)
				velocity_v = vertical_vector * on_slope_steep_speed
	else:
		#ON AIR
		if velocity_v.length() < gravity_force:
			velocity_v += vertical_vector * (delta * gravity_acc)
	 
	#ADD IMPULSE FROM apply_central_impulse FUNCTION
	if impulse != Vector3.ZERO:
		if impulse.y > 0:
			jump_skip_timer = jump_skip_timeout
			input_jump_buffer = 0
			snap_vector = Vector3.ZERO
			jump_count += 1
			emit_signal("body_just_jump")
		velocity_h += impulse * Vector3(1,0,1)
		velocity_v += impulse * Vector3(0,1,0)
		impulse = Vector3.ZERO
		
	velocity = velocity_h + velocity_v

	#ADD EXTERNAL FORCE TO OVERALL VELOCITY
	if not external_force.is_equal_approx(Vector3.ZERO):
		velocity += external_force
		
	#ADD FLOOR VELOCITY FOR MOVING PLATFORM
	if is_on_floor():
		#IF JUST LANDED, HALVED HORIZONTAL VELOCITY SO PLAYER DON'T SLIDE WHEN JUMP TO MOVING PLATFORM
		if just_landed:
			if Vector2(input_h, input_v).length() < 0.2:
				velocity_h *= 0.5
		else:
			velocity += get_floor_velocity() * delta
		
	var _vel = move_and_slide_with_snap(velocity, snap_vector, -gravity_vector, true, 4, deg2rad(45), false)
	
	#CLIMB STAIR
	if climb_stair:
		var climb_stair_vec = ((velocity_h * Vector3(1,0,1)).normalized() + (-gravity_vector)).normalized() * 0.2
		var _ret = move_and_collide(climb_stair_vec, false)
	
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v
	
	#UNCROUCHING LOGIC
	if body_height == BODY_HEIGHT_LIST.UNCROUCHING:
		if not ray_uncrouch.is_colliding(): #uncrouch if there's enough space above head
			ap.play_backwards(crouch_anim)
	
	#PUSH RIGIDBODY 
	if is_on_wall() and bump_force > 0:
		for i in get_slide_count():
			if get_slide_collision(i).collider is RigidBody:
				var o : RigidBody = get_slide_collision(i).collider
				var bump_impulse = (o.global_transform.origin - global_transform.origin).normalized() * bump_force
				o.apply_central_impulse(bump_impulse)
				
	#CROUCHING
	if input_crouch_just_pressed and feat_crouching:
		if body_height == BODY_HEIGHT_LIST.STAND:
			ap.play(crouch_anim)
		else:
			body_height = BODY_HEIGHT_LIST.UNCROUCHING
			
	#SLIDE
	if input_sprint and body_height == BODY_HEIGHT_LIST.STAND and input_crouch_just_pressed and is_on_floor() and feat_slide:
		start_slide()
		
	#WALLRUN
	if input_sprint and is_wallrun_allowed() and feat_wallrun:
		var wall_normal = get_slide_collision(0).normal
		if global_transform.basis.z.angle_to(wall_normal) > deg2rad(10):
			start_wallrun()
			
	#CLIMBING
	if input_jump_pressed and not is_on_floor() and feat_climbing: #CLIMBING EDGE
		if not ray_climb1.is_colliding() and ray_climb2.is_colliding() and ray_climb3.is_colliding():
			start_climb()
	
func start_climb():
	#START CLIMBING LOGIC
	state = STATELIST.CLIMB
	climb_target1 = ray_climb3.get_collision_point()
	var y_diff = climb_target1.distance_to(global_transform.origin)
	climb_target0 = global_transform.origin + (-gravity_vector * y_diff)
	climb_phase = 0
	climb_timer = climb_timeout
	if body_height != BODY_HEIGHT_LIST.CROUCH:
		ap.play(crouch_anim)
	emit_signal("body_climb_start")
	
func do_climb(delta):
	if climb_phase == 0:
		dir = (climb_target0 - global_transform.origin).normalized()
		if global_transform.origin.distance_to(climb_target0) < 0.1:
			climb_phase += 1
	else:
		dir = -global_transform.basis.z * 0.3
	velocity = dir * speed_h_max * delta
	
	var _vel = move_and_slide(velocity)
	
	prev_vel_h = velocity * Vector3(1,0,1)
	prev_vel_v = Vector3.ZERO
	
	climb_timer -= delta
	if climb_timer <= 0:
		emit_signal("body_climb_end")
		start_walk()
		velocity_v = Vector3.ZERO
		
		
	if global_transform.origin.distance_to(climb_target1) < 0.1:
		emit_signal("body_climb_end")
		start_walk()
		velocity_v = Vector3.ZERO
		
		
		
func start_ladder():
	clear_velocity_h()
	clear_velocity_v()
	state = STATELIST.LADDER
	emit_signal("body_ladder_start")
	
func do_ladder(delta):
	#GET USER INPUT VALUE
	
	#DEFINE HORIZONTAL MOVEMENT VECTOR
	var dir_x = camera_root.global_transform.basis.x * input_h
	var dir_z = -camera_root.global_transform.basis.z * input_v
	var horizontal_vector = (dir_x + dir_z).normalized()
	
	#HORIZONTAL VELOCITY
	if Vector2(input_h, input_v).length() < 0.4:
		#DEACCELERATION
		velocity_h = prev_vel_h * delta * speed_deacc
	else:
		#ACCELERATION
		if velocity_h.length() > (speed_h_max * sprint_modifier * delta):
			#SPEED LIMIT. IF GOING TOO FAST, MAKE HORIZONTAL VELOCITY VECTOR SHORTER / SLOWER
			velocity_h = prev_vel_h * delta * speed_deacc
		else:
			#INCREASE MOVEMENT VECTOR BY ADDING NEW MOVEMENT VECTOR TO PREVIOS FRAME HORIZONTAL VELOCITY
			velocity_h = prev_vel_h + (horizontal_vector * speed_acc * delta)
	
	#VERTICAL VELOCITY
	velocity_v = Vector3.ZERO
	
	velocity = velocity_h + velocity_v
	
	var _vel = move_and_slide(velocity, -gravity_vector, true, 4, deg2rad(45), false)
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v

func start_slide():
	automove_dir = -global_transform.basis.z
	slide_timer = slide_time
	state = STATELIST.SLIDE
	emit_signal("body_slide_start")
	if body_height == BODY_HEIGHT_LIST.STAND:
		ap.play(crouch_anim)
	
func do_slide(delta):
	sprint_modifier = sprint_modi
	if velocity_h.length() > (speed_h_max * sprint_modifier * delta):
		#SPEED LIMIT. IF GOING TOO FAST, MAKE HORIZONTAL VELOCITY VECTOR SHORTER / SLOWER
		velocity_h = prev_vel_h * delta * speed_deacc
	else:
		#INCREASE MOVEMENT VECTOR BY ADDING NEW MOVEMENT VECTOR TO PREVIOS FRAME HORIZONTAL VELOCITY
		velocity_h = prev_vel_h + (automove_dir * speed_acc * delta)
	
	
	if is_on_floor() and jump_skip_timer <= 0: 
		#ON FLOOR
		if floor_angle <= deg2rad(slope_limit): #STICKING ON FLOOR / SLOPE
			if floor_collision:
				vertical_vector = -floor_collision.normal
				snap_vector = -floor_collision.normal
			velocity_v = vertical_vector * 0.1
		else: #SLOPE TOO STEEP, SLIDE DOWN
			if not climb_stair:
				var slide_vector = floor_normal
				slide_vector.y = 0
				slide_vector = slide_vector.normalized()
				velocity_h = velocity_h.slide(slide_vector)
				vertical_vector = vertical_vector.slide(floor_collision.normal)
				velocity_v = vertical_vector * on_slope_steep_speed
	else:
		#ON AIR
		if velocity_v.length() < gravity_force:
			velocity_v += vertical_vector * (delta * gravity_acc)
	
	velocity = velocity_h + velocity_v
	
	var _vel = move_and_slide(velocity, -gravity_vector, true, 4, deg2rad(45), false)
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v
	
	if slide_timer <= 0:
		emit_signal("body_slide_end")
		start_walk()
		

func start_pulled():
	state = STATELIST.PULLED
	emit_signal("body_pulled_start")
	
func do_pulled(delta):
	velocity_h = pulled_dir.normalized() * pulled_speed
		
	#VERTICAL VELOCITY
	velocity_v = Vector3.ZERO
	
	velocity = velocity_h + velocity_v
	
	var _vel = move_and_slide(velocity, -gravity_vector, true, 4, deg2rad(45), false)
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v
	
	pulled_timer -= delta
	
	if global_transform.origin.distance_to(pulled_start) > pulled_distance or pulled_timer < 0:
		clear_velocity_h()
		clear_velocity_v()
		emit_signal("body_pulled_end")
		start_walk()
		
func start_swim():
	state = STATELIST.SWIM
	emit_signal("body_swim_start")
	
func do_swim(delta):
	#GET USER INPUT VALUE
	
	#DEFINE HORIZONTAL MOVEMENT VECTOR
	var dir_x = camera_root.global_transform.basis.x * input_h
	var dir_z = -camera_root.global_transform.basis.z * input_v
	var horizontal_vector = (dir_x + dir_z).normalized()
	
	#HORIZONTAL VELOCITY
	if Vector2(input_h, input_v).length() < 0.4:
		#DEACCELERATION
		velocity_h = prev_vel_h * delta * swim_h_deacc
	else:
		#ACCELERATION
		if velocity_h.length() > (speed_h_max * sprint_modifier * delta):
			#SPEED LIMIT. IF GOING TOO FAST, MAKE HORIZONTAL VELOCITY VECTOR SHORTER / SLOWER
			velocity_h = prev_vel_h * delta * swim_h_deacc
		else:
			#INCREASE MOVEMENT VECTOR BY ADDING NEW MOVEMENT VECTOR TO PREVIOS FRAME HORIZONTAL VELOCITY
			velocity_h = prev_vel_h + (horizontal_vector * speed_acc * delta)
		
		
	
	#VERTICAL VELOCITY
	velocity_v = prev_vel_v
	velocity_v *= swim_v_deacc
	
	velocity = velocity_h + velocity_v
	
	var _vel = move_and_slide(velocity, -gravity_vector, true, 4, deg2rad(45), false)
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v
	
func is_wallrun_allowed():
	if input_sprint and not is_on_floor() and not ray_wallrun.is_colliding() and is_on_wall() and jump_skip_timer <= 0 and body_height == BODY_HEIGHT_LIST.STAND and not climb_stair:
		if ray_stair1.is_colliding() and ray_stair2.is_colliding():
			var d1 : float = ray_stair1.global_transform.origin.distance_to(ray_stair1.get_collision_point())
			var d2 : float = ray_stair2.global_transform.origin.distance_to(ray_stair2.get_collision_point())
			if Vector2(d1,0).is_equal_approx(Vector2(d2,0)):
				return true
			else:
				return false
		elif not ray_stair1.is_colliding() and ray_stair2.is_colliding():
			return false
		else:
			return true
	else:
		return false
	
func start_wallrun():
	var normal = get_slide_collision(0).normal
	
	automove_dir = velocity_h
	automove_dir = automove_dir.slide(-gravity_vector)
	automove_dir = automove_dir.slide(normal)
	automove_dir = automove_dir.normalized()
	
	state = STATELIST.WALLRUN
	if global_transform.basis.x.angle_to(normal) < deg2rad(90):
		wallrun_left = true
	else:
		wallrun_left = false
	emit_signal("body_wallrun_start")
	
func do_wallrun(delta):
	if not is_wallrun_allowed():
		emit_signal("body_wallrun_end")
		start_walk()
		return
		
	
	var normal = get_slide_collision(0).normal
	sprint_modifier = sprint_modi
	if velocity_h.length() > (speed_h_max * sprint_modifier * delta):
		#SPEED LIMIT. IF GOING TOO FAST, MAKE HORIZONTAL VELOCITY VECTOR SHORTER / SLOWER
		velocity_h = prev_vel_h * delta * speed_deacc
	else:
		#INCREASE MOVEMENT VECTOR BY ADDING NEW MOVEMENT VECTOR TO PREVIOS FRAME HORIZONTAL VELOCITY
		velocity_h = prev_vel_h + (automove_dir * speed_acc * delta)
	velocity_h -= normal * 0.1
	
	velocity_v = Vector3.ZERO
	
	if input_jump_buffer > 0:
		#START JUMP
		speed_v = jump_force
		velocity_v = vertical_vector * speed_v
		jump_skip_timer = jump_skip_timeout
		input_jump_buffer = 0
		velocity_h += normal * (speed_h_max * sprint_modifier * delta)
		jump_count = 1
		emit_signal("body_just_jump")
	
	velocity = velocity_h + velocity_v
	
	var _vel = move_and_slide(velocity, -gravity_vector, true, 4, deg2rad(45), false)
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v
	
	
#SIGNAL LOGIC
func signal_in_ladder(par):
	ladder_count += par
	if ladder_count > 0:
		start_ladder()
	else:
		emit_signal("body_ladder_end")
		start_walk()
		
func signal_in_gravity_dir(par):
	gravity_obj = par
	
func signal_in_swim_area(par):
	swim_area_count += par
	if swim_area_count > 0:
		start_swim()
	else:
		emit_signal("body_swim_end")
		start_walk()

func signal_in_wind_force(force):
	external_force += force

#THESE ARE CALLED BY ADDONS
func get_rotation_helper():
	return rotation_helper
	
func get_camera_root():
	return camera_root

#PUBLIC FUNCTIONS
func camera_recoil(force):
	var ry = rand_range(-force, force)
	var rx = rand_range(-force, force)

	rotate_y(deg2rad(ry))
	rotation_helper.rotate_x(deg2rad(rx))

func apply_central_impulse(par):
	impulse = par

func clear_velocity_h():
	velocity_h = Vector3.ZERO
	prev_vel_h = velocity_h
	
func clear_velocity_v():
	velocity_v = Vector3.ZERO
	prev_vel_v = velocity_v

func back_to_walk():
	start_walk()

func execute_pulled(p_target, p_dir,  p_speed, p_max_time):
	pulled_dir = p_dir
	pulled_timer = p_max_time
	pulled_start = global_transform.origin
	pulled_target = p_target
	pulled_speed = p_speed
	pulled_distance = pulled_start.distance_to(pulled_target)
	start_pulled()


