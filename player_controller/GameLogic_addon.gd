extends Spatial

class_name BPB_GameLogic_addon

enum WEAPON_LIST {
	PISTOL,
	SHOTGUN,
	SMG,
}

enum ABILITY_LIST {
	BLINK,
	WIND_BLAST,
}

export (NodePath) var path_body
export (NodePath) var path_camera
export (bool) var feat_grab = true
export (float) var throw_force = 10

var target_body : BPB_Fps_Controller
var target_camera : BPB_Camera_addon

var target
var activate_data = {}

var weapon_data = {}

var active_weapon = WEAPON_LIST.PISTOL
var active_ability = ABILITY_LIST.BLINK

var is_grabbing = false

var fire_cooldown = 0

var blink_marker_update = false
var blink_fov = 30

var wind_blast_force = 50
var wind_blast_timer = 0

onready var root = $root
onready var ray_activate =$root/ray_activate
onready var ray_blink = $root/ray_blink
onready var grab_point = $root/grab_point
onready var blink_marker = $root/ray_blink/blink_marker
onready var area_wind_blast = $root/Area_wind_blast
onready var bullet_origin = $root/bullet_origin

#PRELOAD
onready var bullet_i = preload("res://demo/bullet.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	#DELAY PROCESS ONE FRAME
	set_process(false)
	call_deferred("init_setup")
	blink_marker.hide()
	area_wind_blast.hide()
	setup_weapon_data()
	
	
func init_setup():
	target_body = get_node_or_null(path_body)
	target_camera = get_node_or_null(path_camera)
	if target_camera != null:
		#FROM Camera Addon
		target = target_camera.get_camera_root()
	else:
		#FROM PLAYER
		target = target_body.get_camera_root()
		
	get_parent().remove_child(self)
	target.add_child(self)
	global_transform = target.global_transform

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
		
	if Input.is_action_just_pressed("hotkey_1"):
		active_weapon = WEAPON_LIST.PISTOL
		
	if Input.is_action_just_pressed("hotkey_2"):
		active_weapon = WEAPON_LIST.SHOTGUN
	
	if Input.is_action_just_pressed("hotkey_3"):
		active_weapon = WEAPON_LIST.SMG
			
	if Input.is_action_just_pressed("hotkey_4"):
		active_ability = ABILITY_LIST.BLINK
		
	if Input.is_action_just_pressed("hotkey_5"):
		active_ability = ABILITY_LIST.WIND_BLAST

func _process(delta):
	if blink_marker_update:
		update_blink_marker()
		
	if Input.is_action_pressed("action_m0"):
		try_shoot()
		
	#TIMERS
	if fire_cooldown > 0:
		fire_cooldown -= delta
		
	if area_wind_blast.visible:
		wind_blast_timer -= delta
		if wind_blast_timer <= 0:
			area_wind_blast.hide()
			
func setup_weapon_data():
	weapon_data[WEAPON_LIST.PISTOL] = {"bullet_shot" : 1, "spread" : 0, "fire_rate" : 0.6}
	weapon_data[WEAPON_LIST.SHOTGUN] = {"bullet_shot" : 30, "spread" : 30, "fire_rate" : 1.0}
	weapon_data[WEAPON_LIST.SMG] = {"bullet_shot" : 1, "spread" : 0, "fire_rate" : 0.16}
		
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
				is_grabbing = false
				fire_cooldown = 0.5
	
func try_activate_just_pressed():
	if feat_grab:
		if ray_activate.is_colliding():
			var obj = ray_activate.get_collider()
			if obj.has_method("activate"):
				obj.activate(get_default_activate_data())
				is_grabbing = true
	
func try_activate_just_released():
	pass
	
func try_action_m0_just_pressed():
	if feat_grab:
		try_throw()
	
func try_action_m0_just_released():
	pass
	
func try_action_m1_just_pressed():
	if active_ability == ABILITY_LIST.BLINK:
		blink_marker.show()
		blink_marker_update = true
	
func try_action_m1_just_released():
	match active_ability:
		ABILITY_LIST.BLINK:
			do_blink()
		ABILITY_LIST.WIND_BLAST:
			do_wind_blast()
			
func do_blink():
	var blink_dist = ray_blink.cast_to.length()
	if ray_blink.is_colliding():
		blink_dist = ray_blink.global_transform.origin.distance_to(ray_blink.get_collision_point()) - 0.4
	var blink_target = ray_blink.global_transform.origin + (-ray_blink.global_transform.basis.z * blink_dist)
	target_body.execute_pulled(blink_target, -ray_blink.global_transform.basis.z, 46, 1)
	if target_camera:
		blink_fov = target_camera.get_fov() + 30
		blink_marker.hide()
		blink_marker_update = false
		target_camera.tween_fov_then_back_default(blink_fov, 0.3, 0.5, 0.1)
		
func do_wind_blast():
	for o in area_wind_blast.get_overlapping_bodies():
		if o.has_method("apply_central_impulse") and o != target_body:
			var force = (o.global_transform.origin - area_wind_blast.global_transform.origin).normalized() * wind_blast_force
			o.apply_central_impulse(force)
	area_wind_blast.show()
	wind_blast_timer = 0.5

func try_shoot():
	if fire_cooldown > 0:
		return 
		
	for i in weapon_data[active_weapon].bullet_shot:
		var bullet = bullet_i.instance()
		add_child(bullet)
		bullet.global_transform = bullet_origin.global_transform
		var rx = rand_range(-deg2rad(weapon_data[active_weapon].spread/2), deg2rad(weapon_data[active_weapon].spread/2))
		var ry = rand_range(-deg2rad(weapon_data[active_weapon].spread/2), deg2rad(weapon_data[active_weapon].spread/2))
		bullet.rotation = Vector3(bullet.rotation.x + rx, bullet.rotation.y + ry, bullet.rotation.z )
		bullet.global_transform.origin = bullet_origin.global_transform.origin
	fire_cooldown = weapon_data[active_weapon].fire_rate

	match active_weapon:
		WEAPON_LIST.SHOTGUN:
			target_camera.add_screen_shake(0.6)
			target_body.apply_central_impulse(global_transform.basis.z)
		WEAPON_LIST.SMG:
			target_body.camera_recoil(1.0)
			
