#THIS CONTROLLER IS DESIGNED FOR 60 PHYSIC FPS

extends KinematicBody

enum STATELIST {
	WALK,
	CLIMB,
	FLY,
	SLIDE,
	WALLRUN,
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

export (float) var MOUSE_SENSITIVITY = 0.07
export (bool) var air_control = false

export (float) var speed_h_max = 360
export (float) var speed_acc = 30
export (float) var speed_deacc = 50
export (float) var sprint_modi = 1.5
export (float) var crouch_modi = 0.6
export (float) var coyote_time : float = 0.2
export (float) var gravity_force = 30
export (float) var gravity_acc = 20
export (float) var jump_force = -6
export (int) var jump_limit = 1
export (float) var slope_limit = 46.0
export (float) var on_slope_steep_speed = 1.0

export (float) var slide_time = 1

export (float) var throw_force = 10
var body_height : int = BODY_HEIGHT_LIST.STAND

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

var automove_dir = Vector3()
var slide_timer = 0

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

var jump_count = 0


onready var state = STATELIST.WALK

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

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ray_activate.add_exception(self)
	ray_climb1.add_exception(self)
	ray_climb2.add_exception(self)
	ray_climb3.add_exception(self)
	ray_uncrouch.add_exception(self)
	
	ray_stair1.add_exception(self)
	ray_stair2.add_exception(self)
	
	air_borne_disable_snap = coyote_time + 0.1
	
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
			start_fly()
		else:
			start_walk()
			
	
		
func _process(delta):
	#GET USER INPUT VALUE
	input_h = Input.get_action_strength("movement_right") - Input.get_action_strength("movement_left")
	input_v = Input.get_action_strength("movement_forward") - Input.get_action_strength("movement_backward")
	
	
	#SPRINT - STOP
	if Input.is_action_just_released("action_sprint"):
		sprint_enabled = false
		sprint_modifier = sprint_modi_nonactive
		
	#TIMER
	if jump_skip_timer > 0:
		jump_skip_timer -= delta
		
	if input_jump_buffer > 0:
		input_jump_buffer -= delta
		
	if slide_timer > 0:
		slide_timer -= delta
		
		
func _physics_process(delta):
	#INPUT JUST PRESSED
	if Input.is_action_just_pressed("movement_jump"):
		input_jump_buffer = input_jump_timeout
		
		
	match state:
		STATELIST.WALK:
			do_walk(delta)
		STATELIST.CLIMB:
			do_climb(delta)
		STATELIST.FLY:
			do_fly(delta)
		STATELIST.SLIDE:
			do_slide(delta)
		STATELIST.WALLRUN:
			do_wallrun(delta)

	if is_on_floor():
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

func body_height_crouch():
	body_height = BODY_HEIGHT_LIST.CROUCH

func body_height_stand():
	body_height = BODY_HEIGHT_LIST.STAND
	sprint_modifier = sprint_modi_nonactive

func start_walk():
	state = STATELIST.WALK
	
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
	var look_at_target = root_ray_stair.global_transform.origin + (velocity_h * Vector3(1,0,1))
	if not look_at_target.is_equal_approx(root_ray_stair.global_transform.origin):
		root_ray_stair.look_at(look_at_target, Vector3.UP)
	
	#DISABLE SNAP WHEN CLIMBING STAIR OR BEING AIR BORNE FOR TOO LONG
	var climb_stair = try_climb_stairs()
	if climb_stair or air_borne > air_borne_disable_snap:
		snap_vector = Vector3()
		
	#VERTICAL VELOCITY
	if input_jump_buffer > 0 and jump_count < jump_limit :
		#START JUMP
		speed_v = jump_force
		velocity_v = vertical_vector * speed_v
		jump_skip_timer = jump_skip_timeout
		input_jump_buffer = 0
		snap_vector = Vector3.ZERO
		jump_count += 1
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
		if body_height == BODY_HEIGHT_LIST.STAND:
			ap.play("CROUCH")
		else:
			body_height = BODY_HEIGHT_LIST.UNCROUCHING
			
	#UNCROUCHING LOGIC
	if body_height == BODY_HEIGHT_LIST.UNCROUCHING:
		if not ray_uncrouch.is_colliding(): #uncrouch if there's enough space above head
			ap.play_backwards("CROUCH")
			
	#CLIMBING
	if Input.is_action_pressed("movement_jump") and not is_on_floor() and feat_climbing: #CLIMBING EDGE
		if not ray_climb1.is_colliding() and ray_climb2.is_colliding() and ray_climb3.is_colliding():
			start_climb()
			
	#SPRINT
	if Input.is_action_pressed("action_sprint"):
		sprint_enabled = true
		sprint_modifier = sprint_modi
		
		#SLIDE
		if body_height == BODY_HEIGHT_LIST.STAND and Input.is_action_just_pressed("action_crouch_toggle") and feat_slide:
			start_slide()
			
		#WALLRUN
		if is_wallrun_allowed() and feat_wallrun:
			start_wallrun()
	
func start_climb():
	#START CLIMBING LOGIC
	state = STATELIST.CLIMB
	climb_target = ray_climb3.get_collision_point()	
	climb_timer = climb_timeout
	if body_height != BODY_HEIGHT_LIST.CROUCH:
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
		start_walk()
		
func start_fly():
	state = STATELIST.FLY
	
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

func start_slide():
	automove_dir = -global_transform.basis.z
	slide_timer = slide_time
	state = STATELIST.SLIDE
	
func do_slide(delta):
	sprint_modifier = sprint_modi
	if velocity_h.length() > (speed_h_max * sprint_modifier * delta):
		#SPEED LIMIT. IF GOING TOO FAST, MAKE HORIZONTAL VELOCITY VECTOR SHORTER / SLOWER
		velocity_h *= 0.88
	else:
		#INCREASE MOVEMENT VECTOR BY ADDING NEW MOVEMENT VECTOR TO PREVIOS FRAME HORIZONTAL VELOCITY
		velocity_h = prev_vel_h + (automove_dir * speed_acc * delta)
		
	if is_on_floor() and jump_skip_timer <= 0: 
		#ON FLOOR
		if floor_angle <= deg2rad(slope_limit): #STICKING ON FLOOR / SLOPE
			if floor_collision:
				vertical_vector = -floor_collision.normal
				snap_vector = -floor_collision.normal
			speed_v = 0.1
		else: #SLOPE TOO STEEP, SLIDE DOWN
			
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
	
	var _vel = move_and_slide(velocity, Vector3.UP, true, 4, deg2rad(45), false)
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v
	
	if slide_timer <= 0:
		start_walk()
	
func is_wallrun_allowed():
	if not is_on_floor() and is_on_wall() and Input.is_action_pressed("action_sprint") and jump_skip_timer <= 0 :
		return true
	else:
		return false
	
func start_wallrun():
	var normal = get_slide_collision(0).normal
	automove_dir = (-global_transform.basis.z.slide(normal)).normalized()
	
	state = STATELIST.WALLRUN
	
func do_wallrun(delta):
	if not is_wallrun_allowed():
		start_walk()
		return
	var normal = get_slide_collision(0).normal
	sprint_modifier = sprint_modi
	if velocity_h.length() > (speed_h_max * sprint_modifier * delta):
		#SPEED LIMIT. IF GOING TOO FAST, MAKE HORIZONTAL VELOCITY VECTOR SHORTER / SLOWER
		velocity_h *= 0.88
	else:
		#INCREASE MOVEMENT VECTOR BY ADDING NEW MOVEMENT VECTOR TO PREVIOS FRAME HORIZONTAL VELOCITY
		velocity_h = prev_vel_h + (automove_dir * speed_acc * delta)
	velocity_h -= normal * 0.1
	
	velocity_v = Vector3.ZERO
	
	if Input.is_action_just_pressed("movement_jump"):
		#START JUMP
		speed_v = jump_force
		velocity_v = vertical_vector * speed_v
		jump_skip_timer = jump_skip_timeout
		input_jump_buffer = 0
		velocity_h += normal * (speed_h_max * sprint_modifier * delta)
		
	
	velocity = velocity_h + velocity_v
	
	var _vel = move_and_slide(velocity, Vector3.UP, true, 4, deg2rad(45), false)
	prev_vel_h = velocity_h
	prev_vel_v = velocity_v
	
	
#SIGNAL LOGIC
func ladder_add(par):
	ladder_count += par
	if ladder_count > 0:
		start_fly()
	else:
		start_walk()

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
