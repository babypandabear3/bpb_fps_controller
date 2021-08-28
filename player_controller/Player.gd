#THIS CONTROLLER IS DESIGNED FOR 60 PHYSIC FPS

extends KinematicBody

enum STATELIST {
	WALK,
	CLIMB,
	FLY
}

export (bool) var feat_crouching = true
export (bool) var feat_climbing = true

export (float) var MOUSE_SENSITIVITY = 0.07
export (bool) var air_control = false

export (float) var speed_h_max = 360
export (float) var speed_acc = 30
export (float) var speed_deacc = 50
export (float) var sprint_modi_active = 1.5

export (float) var gravity_force = 30
export (float) var gravity_acc = 20
export (float) var jump_force = -6

export (float) var slope_limit = 46.0
export (float) var on_slope_steep_speed = 1.0

export (float) var throw_force = 10
export (String, "STAND", "CROUCH", "UNCROUCHING") var body_height = "STAND" #DON"T CHANGE FROM DEFAULT, THIS IS FOR ANIMATION PLAYER TO MAKE KEYFRAME

var jump_skip_timer = 0
var jump_skip_timeout = 0.1

var dir = Vector3()
var prev_vel_h = Vector3()
var prev_vel_v = Vector3()

var velocity = Vector3()
var velocity_h = Vector3()
var velocity_v = Vector3()

var vertical_vector = Vector3.DOWN
var on_floor_vertical_speed = 0.1
var snap_vector = Vector3.DOWN

var speed_v = 0
var sprint_enabled = false
var sprint_modifier = 1
var sprint_modi_nonactive = 1.0

var activate_data = {}

var climb_target = Vector3()
var climb_timer = 0
var climb_timeout = 0.6

onready var ap = $AnimationPlayer
onready var rotation_helper = $rotation_helper
onready var eye_position = $rotation_helper/eye_position
onready var holder = $rotation_helper/eye_position/holder
onready var ray_activate = $rotation_helper/eye_position/ray_activate
onready var ray_uncrouch = $ray_uncrouch

onready var ray_climb1 = $ray_climb1
onready var ray_climb2 = $ray_climb2
onready var ray_climb3 = $ray_climb3

onready var root_ray_stair = $root_ray_stair
onready var ray_stair1 = $root_ray_stair/ray_stair1
onready var ray_stair2 = $root_ray_stair/ray_stair2

var recoil = Vector3.ZERO
var recoil_deacc = 0.9

var floor_angle = 0.0
var floor_collision = null
var floor_normal = Vector3.UP
	
var floor_obj = null
var floor_prev_rot = null

onready var state = STATELIST.WALK

#SIGNAL LOGIC
var ladder_count : int = 0
var external_force : Vector3 = Vector3.ZERO

#INPUT
var input_jump_timeout = 0.2
var coyote_time : float = 0.2
var air_borne : float = 0.0

var input_h : float = 0.0
var input_v : float = 0.0
var input_jump : float = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ray_activate.add_exception(self)
	ray_climb1.add_exception(self)
	ray_climb2.add_exception(self)
	ray_climb3.add_exception(self)
	ray_uncrouch.add_exception(self)
	
	ray_stair1.add_exception(self)
	ray_stair2.add_exception(self)
	#ray_stair3.add_exception(self)
	
func get_default_activate_data():
	activate_data.mouse_sensitivity = MOUSE_SENSITIVITY
	activate_data.body = self
	activate_data.holder = holder
	activate_data.release_force = Vector3.ZERO
	return activate_data
	
func _input(event):
	#MOUSE CAMERA
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(-deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
	
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
		
	#PRESS ESC TO QUIT GAME
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
		
	#TOGGLE FLY MODE
	if Input.is_action_just_pressed("action_toggle_fly"):
		if state == STATELIST.WALK:
			state = STATELIST.FLY
		else:
			state = STATELIST.WALK
			
	
		
func _process(delta):
	#GET USER INPUT VALUE
	input_h = Input.get_action_strength("movement_right") - Input.get_action_strength("movement_left")
	input_v = Input.get_action_strength("movement_forward") - Input.get_action_strength("movement_backward")
	if Input.is_action_just_pressed("movement_jump"):
		input_jump = input_jump_timeout
	
	#SPRINT - STOP
	if Input.is_action_just_released("action_sprint"):
		sprint_enabled = false
		sprint_modifier = sprint_modi_nonactive
		
	#TIMER
	if jump_skip_timer > 0:
		jump_skip_timer -= delta
		
	if input_jump > 0:
		input_jump -= delta
		
		
func _physics_process(delta):
	match state:
		STATELIST.WALK:
			do_walk(delta)
		STATELIST.CLIMB:
			do_climb(delta)
		STATELIST.FLY:
			do_fly(delta)

	if is_on_floor():
		air_borne = 0.0
	else:
		air_borne += delta
		
func try_climb_stairs():
	ray_stair1.force_update_transform()
	ray_stair2.force_update_transform()
	ray_stair1.force_raycast_update()
	ray_stair2.force_raycast_update()
	
	var ret = false
	if ray_stair2.is_colliding() and velocity_h.length() > 4.0:
		if Vector3.UP.angle_to(ray_stair2.get_collision_normal()) > deg2rad(80):
			if ray_stair1.is_colliding():
				var d1 = ray_stair1.global_transform.origin.distance_to(ray_stair1.get_collision_point())
				var d2 = ray_stair2.global_transform.origin.distance_to(ray_stair2.get_collision_point())
				if d1 - d2 > 0.1:
					ret = true
			else:
				ret = true
	return ret


func do_walk(delta):
	#DEFAULT VERTICAL MOVEMENT VALUE
	floor_normal = Vector3.UP
	vertical_vector = Vector3.DOWN
	snap_vector = Vector3.DOWN
	floor_angle = 0.0
	floor_collision = null
	if jump_skip_timer > 0:
		snap_vector = Vector3.ZERO
			
	#IF CAN DETECT FLOOR, GET COLLISION INFORMATION WITH FLOOR, WITH LARGEST ANGLE
	if is_on_floor() and get_slide_count() > 0:
		for i in get_slide_count():
			var tmp_col = get_slide_collision(i)
			var tmp_floor_angle = Vector3.UP.angle_to(tmp_col.normal)
			if tmp_floor_angle > floor_angle:
				floor_angle = tmp_floor_angle
				floor_collision = tmp_col
				floor_normal = tmp_col.normal
			elif i == 0:
				floor_angle = tmp_floor_angle
				floor_collision = tmp_col
				floor_normal = tmp_col.normal
		
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
	var dir_x = eye_position.global_transform.basis.x * input_h
	var dir_z = -eye_position.global_transform.basis.z * input_v
	var horizontal_vector = (dir_x + dir_z).slide(floor_normal).normalized()
	
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
		
	#IF NOT USING AIR CONTROL, THEN USE PREVIOUS HORIZONTAL VELOCITY WHEN ON AIR
	if not is_on_floor() and not air_control:
		velocity_h = prev_vel_h
	
	#ROTATE ROOT RAY STAIR
	var look_at_target = root_ray_stair.global_transform.origin + (velocity_h * Vector3(1,0,1))
	if not look_at_target.is_equal_approx(root_ray_stair.global_transform.origin):
		root_ray_stair.look_at(look_at_target, Vector3.UP)
	
	#CLIMBING STAIR CHECKING
	var climb_stair = try_climb_stairs()
	if climb_stair:
		snap_vector = Vector3()
		
	#VERTICAL VELOCITY
	if input_jump > 0 and air_borne < coyote_time: 
		#START JUMP
		speed_v = jump_force
		velocity_v = vertical_vector * speed_v
		jump_skip_timer = jump_skip_timeout
		input_jump = 0
		snap_vector = Vector3.ZERO
	elif is_on_floor() and jump_skip_timer <= 0: 
		#ON FLOOR
		if floor_angle <= deg2rad(slope_limit): #STICKING ON FLOOR / SLOPE
			if floor_collision:
				vertical_vector = -floor_collision.normal
				snap_vector = -floor_collision.normal
			speed_v = 0.1
		else: #SLOPE TOO STEEP, SLIDE DOWN
			if not climb_stair:
				var slide_vector = floor_normal
				slide_vector.y = 0
				slide_vector = slide_vector.normalized()
				velocity_h = velocity_h.slide(slide_vector)
				vertical_vector = Vector3.DOWN.slide(floor_collision.normal)
				speed_v = on_slope_steep_speed
		velocity_v = vertical_vector * speed_v
	else:
		#ON AIR
		speed_v = clamp(speed_v + (delta * gravity_acc), jump_force, gravity_force)
		velocity_v = vertical_vector * speed_v
	 
	velocity = velocity_h + velocity_v

	#ADD EXTERNAL FORCE TO OVERALL VELOCITY
	if not external_force.is_equal_approx(Vector3.ZERO):
		velocity += external_force
		
	#ADD FLOOR VELOCITY FOR MOVING PLATFORM
	if is_on_floor():
		velocity += get_floor_velocity() * delta
		
	#RECOIL
	var recoil_force = (global_transform.basis.x * recoil.x) + (global_transform.basis.y * recoil.y) + (global_transform.basis.z * recoil.z)
	velocity += recoil_force * delta * 60
	recoil *= recoil_deacc * delta * 60
		
	var _vel = move_and_slide_with_snap(velocity, snap_vector, Vector3.UP, true, 4, deg2rad(45), false)
	
	#CLIMB STAIR
	if climb_stair:
		var _ret = move_and_collide(Vector3.UP * 0.1, false)
	
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v

	### ACTIONS LOGIC ###
	
	#GRAB / RELEASE
	if Input.is_action_just_pressed("action_activate"):
		if ray_activate.is_colliding():
			var obj = ray_activate.get_collider()
			if obj.has_method("activate"):
				obj.activate(get_default_activate_data())
	
	#THROW GRABBED OBJECT
	if Input.is_action_just_pressed("action_m0"):
		if ray_activate.is_colliding():
			var obj = ray_activate.get_collider()
			if obj.has_method("activate"):
				var adata = get_default_activate_data()
				adata.release_force = -eye_position.global_transform.basis.z * throw_force
				obj.activate(adata)
				
	#TOGGLE CROUCH
	if Input.is_action_just_pressed("action_crouch_toggle") and feat_crouching:
		if body_height == "STAND":
			ap.play("CROUCH")
		else:
			body_height = "UNCROUCHING"
			
	#UNCROUCHING LOGIC
	if body_height == "UNCROUCHING":
		if not ray_uncrouch.is_colliding(): #uncrouch if there's enough space above head
			ap.play_backwards("CROUCH")
			
	#CLIMBING
	if Input.is_action_pressed("movement_jump") and not is_on_floor() and feat_climbing: #CLIMBING EDGE
		if not ray_climb1.is_colliding() and ray_climb2.is_colliding() and ray_climb3.is_colliding():
			start_climb()
			
	#SPRINT
	if Input.is_action_pressed("action_sprint"):
		sprint_enabled = true
		sprint_modifier = sprint_modi_active
	

func start_climb():
	#START CLIMBING LOGIC
	state = STATELIST.CLIMB
	climb_target = ray_climb3.get_collision_point()	
	climb_timer = climb_timeout
	if body_height != "CROUCH":
		ap.play("CROUCH")
	
	
func do_climb(delta):
	dir = (climb_target - global_transform.origin).normalized()
	dir.y += 0.1 #this is a fix to avoid getting stuck when climbing
	velocity = dir * speed_h_max * delta
	
	var _vel = move_and_slide(velocity)
	
	prev_vel_h = velocity
	prev_vel_v = Vector3.ZERO
	
	climb_timer -= delta
	if climb_timer <= 0:
		state = STATELIST.WALK
		

func do_fly(delta):
	#GET USER INPUT VALUE
	
	#DEFINE HORIZONTAL MOVEMENT VECTOR
	var dir_x = eye_position.global_transform.basis.x * input_h
	var dir_z = -eye_position.global_transform.basis.z * input_v
	var horizontal_vector = (dir_x + dir_z).normalized()
	
	#HORIZONTAL VELOCITY
	if Vector2(input_h, input_v).length() < 0.4:
		#DEACCELERATION
		velocity_h = prev_vel_h * 0.88
	else:
		#ACCELERATION
		if velocity_h.length() > (speed_h_max * sprint_modifier * delta):
			#SPEED LIMIT. IF GOING TOO FAST, MAKE HORIZONTAL VELOCITY VECTOR SHORTER / SLOWER
			velocity_h *= 0.88
		else:
			#INCREASE MOVEMENT VECTOR BY ADDING NEW MOVEMENT VECTOR TO PREVIOS FRAME HORIZONTAL VELOCITY
			velocity_h = prev_vel_h + (horizontal_vector * speed_acc * delta)
		
	
	#VERTICAL VELOCITY
	velocity_v = Vector3.ZERO
	
	velocity = velocity_h + velocity_v
	
	var _vel = move_and_slide(velocity, Vector3.UP, true, 4, deg2rad(45), false)
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v
	
#SIGNAL LOGIC
func ladder_add(par):
	ladder_count += par
	if ladder_count > 0:
		state = STATELIST.FLY
	else:
		state = STATELIST.WALK

func wind_force_add(force):
	external_force += force

func add_recoil(par, camera_recoil_force):
	recoil = par
	call_deferred("camera_recoil", camera_recoil_force)

func camera_recoil(force):
	var ry = rand_range(-force, force)
	var rx = rand_range(-force, force)

	rotate_y(deg2rad(ry))
	rotation_helper.rotate_x(deg2rad(rx))
