extends Spatial

export (NodePath) var follow_target
export (bool) var feat_head_bob = true
export (bool) var feat_lean = true
export (bool) var feat_lean_on_wallrun = true
export (bool) var feat_crouch_crawl = true
export (float) var head_bob_h = 0.02
export (float) var head_bob_v = 0.02
export (float) var head_bob_rotation = 0.01
export (float) var head_bob_speed = 10
export (float) var lean_angle = 15

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

#CRAWL CROUCH
var crawl_crouch = 0
var crawl_crouch_speed = 6


onready var camera_root = $bob_pivot/lean_pivot/rotation_helper_point/camera_root
onready var bob_pivot = $bob_pivot
onready var lean_pivot = $bob_pivot/lean_pivot
onready var ray_crouch_point = $ray_crouch_point
onready var crouch_point = $bob_pivot/lean_pivot/rotation_helper_point/crouch_point
onready var crawl_point = $bob_pivot/lean_pivot/rotation_helper_point/crawl_point
onready var camera = $bob_pivot/lean_pivot/rotation_helper_point/camera_root/Camera

# Called when the node enters the scene tree for the first time.
func _ready():
	camera.current = true
	noise = OpenSimplexNoise.new()
	set_as_toplevel(true)
	target = get_node_or_null(follow_target)
	if target == null:
		target = get_parent()
	target_rotation_helper = target.get_node("rotation_helper")
	physic_fps = ProjectSettings.get_setting("physics/common/physics_fps") - 0.5
	global_transform = target.global_transform
	
	ray_crouch_point.add_exception(target)
	
func _process(delta):
	global_transform = global_transform.interpolate_with(target.global_transform, delta * physic_fps)
	camera_root.rotation = target_rotation_helper.rotation
	
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
		
func do_headbob(delta):
	if target.velocity_h.length() > 1.0 and target.is_on_floor():
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
	bob_pivot.translation.y = lerp(0, -head_bob_v, hb_sin_progress*2)
	if head_bob_rotation != 0:
		bob_pivot.rotation.z = lerp_angle(0, deg2rad(head_bob_rotation), hb_sin_progress)


func do_lean(_delta):
	var lean_dir = 0
	if Input.is_action_pressed("action_lean_left"):
		lean_dir += 1
	if Input.is_action_pressed("action_lean_right"):
		lean_dir -= 1
		
	lean_target = lean_angle * lean_dir
	

func do_lean_on_wallrun(_delta):
	var lean_dir = 0
	lean_target = 0
	if target.wallrun_left:
		lean_dir -= 1
	else:
		lean_dir += 1
	lean_target = lean_angle * lean_dir
	
func do_crouch_crawl(delta):
	if ray_crouch_point.is_colliding() and target.body_height == target.BODY_HEIGHT_LIST.CROUCH:
		camera_root.translation = crouch_point.translation.linear_interpolate(crawl_point.translation, crawl_crouch)
		crawl_crouch = clamp(crawl_crouch + (delta * crawl_crouch_speed), 0, 1)
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
