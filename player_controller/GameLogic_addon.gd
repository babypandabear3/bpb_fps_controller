extends Spatial

export (NodePath) var path_body
export (NodePath) var path_camera
export (bool) var feat_grab = true
export (float) var throw_force = 10
var target_body
var target_camera
var target
var activate_data = {}

onready var root = $root
onready var ray_activate =$root/ray_activate
onready var ray_blink = $root/ray_blink
onready var grab_point = $root/grab_point
onready var blink_marker = $blink_marker

var blink_marker_update = false

# Called when the node enters the scene tree for the first time.
func _ready():
	#DELAY PROCESS ONE FRAME
	set_process(false)
	call_deferred("init_setup")
	blink_marker.hide()
	
func init_setup():
	target_body = get_node_or_null(path_body)
	target_camera = get_node_or_null(path_camera)
	if target_camera != null:
		#FROM Camera Addon
		target = target_camera.get_camera_root()
	else:
		#FROM PLAYER
		target = target_body.get_camera_root()
		
	remove_child(root)
	target.add_child(root)
	root.global_transform = target.global_transform

	blink_marker.set_as_toplevel(true)
	set_process(true)

func _input(_event):
	if Input.is_action_just_pressed("action_activate"):
		try_activate_just_pressed()
		
	if Input.is_action_just_released("action_activate"):
		try_activate_just_released()
		
	if Input.is_action_just_pressed("action_m0"):
		try_action_m0_just_pressed()
		
	if Input.is_action_just_released("action_m0"):
		try_action_m0_just_released()
	
	if Input.is_action_just_pressed("action_m1"):
		try_action_m1_just_pressed()
		
	if Input.is_action_just_released("action_m1"):
		try_action_m1_just_released()
		
func _process(_delta):
	if blink_marker_update:
		update_blink_marker()
		
func update_blink_marker():
	if ray_blink.is_colliding():
		blink_marker.global_transform.origin = ray_blink.get_collision_point()
	else:
		blink_marker.global_transform.origin = root.global_transform.origin + (-root.global_transform.basis.z * (ray_blink.cast_to.length()))
	
func get_default_activate_data():
	activate_data.body = target_body
	activate_data.grab_point = grab_point
	activate_data.release_force = Vector3.ZERO
	return activate_data
	
func try_throw():
	if ray_activate.is_colliding():
		var obj = ray_activate.get_collider()
		if obj.has_method("get_grabbed_status"):
			if obj.get_grabbed_status():
				var adata = get_default_activate_data()
				adata.release_force = -root.global_transform.basis.z * throw_force
				obj.activate(adata)
	
func try_activate_just_pressed():
	if feat_grab:
		if ray_activate.is_colliding():
			var obj = ray_activate.get_collider()
			if obj.has_method("activate"):
				obj.activate(get_default_activate_data())
	
func try_activate_just_released():
	pass
	
func try_action_m0_just_pressed():
	if feat_grab:
		try_throw()
	
func try_action_m0_just_released():
	pass
	
func try_action_m1_just_pressed():
	blink_marker.show()
	blink_marker_update = true
	if target_camera:
		target_camera.tween_fov_to(80, 0.1)

func try_action_m1_just_released():
	blink_marker.hide()
	blink_marker_update = false
	
	var blink_dist = ray_blink.cast_to.length()
	if ray_blink.is_colliding():
		blink_dist = ray_blink.global_transform.origin.distance_to(ray_blink.get_collision_point()) - 0.4
	var blink_target = ray_blink.global_transform.origin + (-ray_blink.global_transform.basis.z * blink_dist)
	target_body.execute_pulled(blink_target, -ray_blink.global_transform.basis.z, 46, 1)
	if target_camera:
		target_camera.tween_fov_to_default(80, 0.5)

