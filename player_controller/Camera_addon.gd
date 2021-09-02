extends Spatial

export (NodePath) var follow_target
export (bool) var feat_head_bob = true
export (bool) var feat_lean = true
export (bool) var feat_lean_on_wallrun = true
export (bool) var feat_crouch_crawl = true
export (float) var head_bob_h = 0.0
export (float) var head_bob_v = 0.024
export (float) var head_bob_rotation = 0.00
export (float) var head_bob_speed = 8
export (float) var lean_angle = 10
export (float) var lean_pivot_move_speed = 12

var physic_fps : float = 0.0

#SCREEN SHAKE
var trauma = 0.0
var max_x = 2
var max_y = 2
var max_r = 5
var time_scale = 150
var decay = 0.9
var time = 0
var noise : OpenSimplexNoise
var target : Spatial
var target_rotation_helper

#HEAD BOB
var hb_sin_speed = 60 * head_bob_speed
var hb_lean_sin_progress = 0
var hb_sin_progress = 0

#LEAN
var lean_speed = 6
var lean_target = 0

var lean_pivot_move_target = Vector3.ZERO


#CRAWL CROUCH
var crawl_crouch = 0
var crawl_crouch_speed = 6


onready var camera_root = $bob_pivot/lean_pivot/rotation_helper_point/camera_root
onready var bob_pivot = $bob_pivot
onready var lean_pivot = $bob_pivot/lean_pivot
onready var ray_crouch_point_L = $ray_crouch_point_L
onready var ray_crouch_point_R = $ray_crouch_point_R
onready var crouch_point = $bob_pivot/lean_pivot/rotation_helper_point/crouch_point
onready var crawl_point = $bob_pivot/lean_pivot/rotation_helper_point/crawl_point
onready var camera = $bob_pivot/lean_pivot/rotation_helper_point/camera_root/Camera
onready var ray_lean = $bob_pivot/ray_lean
onready var ray_activate = $bob_pivot/lean_pivot/rotation_helper_point/camera_root/ray_activate
onready var holder = $bob_pivot/lean_pivot/rotation_helper_point/camera_root/holder
onready var ray_blink = $bob_pivot/lean_pivot/rotation_helper_point/camera_root/ray_blink

# Called when the node enters the scene tree for the first time.
func _ready():
	camera.current = true
	noise = OpenSimplexNoise.new()
	set_as_toplevel(true)
	target = get_node_or_null(follow_target)
	if target == null:
		target = get_parent()
	
	physic_fps = ProjectSettings.get_setting("physics/common/physics_fps") - 0.5
	global_transform = target.global_transform
	
	ray_crouch_point_L.add_exception(target)
	ray_crouch_point_R.add_exception(target)
	ray_lean.add_exception(target)
	
	#DELAY PROCESS ONE FRAME
	set_process(false)
	call_deferred("activate_process")
	
func activate_process():
	#DELAY PROCESS ONE FRAME SO target.get_rotation_helper() DOESN'T RETURN NULL
	target_rotation_helper = target.get_rotation_helper()
	ray_activate.add_exception(target)
	target.replace_ray_activate_holder(ray_activate, holder)
	set_process(true)
	
func _process(delta):
	global_transform = global_transform.interpolate_with(target.global_transform, delta * physic_fps)
	camera_root.rotation.x = lerp_angle(camera_root.rotation.x, target_rotation_helper.rotation.x, delta * physic_fps)
	
	#HEAD BOB
	if feat_head_bob:
		do_headbob(delta)
		
	if feat_crouch_crawl:
		do_crouch_crawl(delta)
		
	if feat_lean or feat_lean_on_wallrun:
		if feat_lean_on_wallrun and target.state == target.STATELIST.WALLRUN:
			do_lean_on_wallrun(delta)
		elif feat_lean:
			do_lean(delta)
		lean_pivot.rotation.z = lerp_angle(lean_pivot.rotation.z, deg2rad(lean_target), delta * lean_speed)
		
	screen_shake(delta)
	
	do_input()
		
func do_headbob(delta):
	if target.velocity.length() > 1.0 and target.is_on_floor():
		hb_lean_sin_progress += deg2rad(delta * hb_sin_speed * target.sprint_modifier)
		if rad2deg(hb_lean_sin_progress) > 360:
			hb_lean_sin_progress = 0
		hb_sin_progress = sin(hb_lean_sin_progress)
	else:
		if hb_lean_sin_progress != 0:
			if rad2deg(hb_lean_sin_progress) < 180 and hb_lean_sin_progress != 0:
				hb_lean_sin_progress += deg2rad(delta * hb_sin_speed)
				if rad2deg(hb_lean_sin_progress) > 180:
					hb_lean_sin_progress = 0

			elif rad2deg(hb_lean_sin_progress) < 360 and hb_lean_sin_progress != 0:
				hb_lean_sin_progress += deg2rad(delta * hb_sin_speed)
				if rad2deg(hb_lean_sin_progress) > 360:
					hb_lean_sin_progress = 0
			
			hb_sin_progress = sin(hb_lean_sin_progress)
	
	bob_pivot.translation.x = lerp(0, head_bob_h, hb_sin_progress)
	if target.body_height == target.BODY_HEIGHT_LIST.CROUCH :
		bob_pivot.translation.y = lerp(0, -head_bob_v/2, hb_sin_progress*2)
	else:
		bob_pivot.translation.y = lerp(0, -head_bob_v, hb_sin_progress*2)
	if head_bob_rotation != 0:
		bob_pivot.rotation.z = lerp_angle(0, deg2rad(head_bob_rotation), hb_sin_progress)


func do_lean(_delta):
	var lean_dir = 0
	lean_pivot_move_target = Vector3.ZERO
	if Input.is_action_pressed("action_lean_left"):
		lean_dir += 1
		ray_lean.cast_to = Vector3.LEFT
		lean_pivot_move_target = Vector3.LEFT
		ray_lean.force_raycast_update()
		if ray_lean.is_colliding():
			lean_pivot_move_target *= ray_lean.global_transform.origin.distance_to(ray_lean.get_collision_point()) * 0.5
	if Input.is_action_pressed("action_lean_right"):
		lean_dir -= 1
		ray_lean.cast_to = Vector3.RIGHT
		lean_pivot_move_target = Vector3.RIGHT
		ray_lean.force_raycast_update()
		if ray_lean.is_colliding():
			lean_pivot_move_target *= ray_lean.global_transform.origin.distance_to(ray_lean.get_collision_point()) * 0.5
		
	lean_target = lean_angle * lean_dir
	lean_pivot.translation = lean_pivot.translation.linear_interpolate(lean_pivot_move_target, lean_pivot_move_speed * _delta)
	

func do_lean_on_wallrun(_delta):
	var lean_dir = 0
	lean_target = 0
	if target.wallrun_left:
		lean_dir -= 1
	else:
		lean_dir += 1
	lean_target = lean_angle * lean_dir
	
func do_crouch_crawl(delta):
	if target.body_height == target.BODY_HEIGHT_LIST.CROUCH :
		if ray_crouch_point_L.is_colliding() or ray_crouch_point_R.is_colliding():
			camera_root.translation = crouch_point.translation.linear_interpolate(crawl_point.translation, crawl_crouch)
			crawl_crouch = clamp(crawl_crouch + (delta * crawl_crouch_speed), 0, 1)
		else:
			camera_root.translation = crouch_point.translation.linear_interpolate(crawl_point.translation, crawl_crouch)
			crawl_crouch = clamp(crawl_crouch - (delta * crawl_crouch_speed), 0, 1)
	else:
		camera_root.translation = crouch_point.translation.linear_interpolate(crawl_point.translation, crawl_crouch)
		crawl_crouch = clamp(crawl_crouch - (delta * crawl_crouch_speed), 0, 1)

func add_screen_shake(trauma_in):
	trauma = clamp(trauma + trauma_in, 0, 1)
	
func screen_shake(delta):
	time += delta
	
	var shake = pow(trauma, 2)
	camera.translation.x = noise.get_noise_3d(time * time_scale, 0, 0) * max_x * shake
	camera.translation.y = noise.get_noise_3d(0, time * time_scale, 0) * max_y * shake
	camera.rotation_degrees.z = noise.get_noise_3d(0, 0, time * time_scale) * max_r * shake
	
	if trauma > 0: trauma = clamp(trauma - (delta * decay), 0, 1)

func do_input():
	if Input.is_action_just_pressed("action_m1"):
		#BLINK
		var blink_dist = ray_blink.cast_to.length()
		if ray_blink.is_colliding():
			blink_dist = ray_blink.global_transform.origin.distance_to(ray_blink.get_collision_point()) - 0.4
		var blink_target = ray_blink.global_transform.origin + (-ray_blink.global_transform.basis.z * blink_dist)
		target.execute_pulled(blink_target, 45, 1)
