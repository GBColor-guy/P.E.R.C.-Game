# Player.gd
extends CharacterBody3D
class_name Player

# -------------------------
# Movement Constants
# -------------------------
var controller_sens: float = 120.0  # degrees per second when axis = 1
var look_deadzone: float = 0.15     # controller stick deadzone
var invert_look_y: bool = false
const MAX_SPEED = 10000.0
const MAX_WALK_SPEED = 5.0
const MAX_SPRINT_SPEED = 15.0
const MAX_BHOP_SPEED = 30.0
const JUMP_VELOCITY = 5.0
const ACCEL = 5.0
const DEACCEL = 25.0
const AIR_ACCEL = 5.0
const AIR_CONTROL = 5.5
var mouse_sens: float = 0.002
const BASE_FOV := 75.0         # normal standing FOV
const MAX_FOV := 100.0          # maximum when moving fast
const FOV_LERP_SPEED2 := 8.0    # how quickly FOV catches up

# -------------------------
# Slide Constants
# -------------------------
const SLIDE_SPEED = 15.0
const SLIDE_FRICTION = 5.0
const SLIDE_DURATION = 0.6
const SLIDE_CAMERA_HEIGHT = -0.5
const CAMERA_LERP_SPEED = 8.0
const SLIDE_FOV = 100.0
const FOV_LERP_SPEED = 6.0

# -------------------------
# Wall-run Constants
# -------------------------
const WALL_RUN_MIN_SPEED = 10.0
const WALL_JUMP_FORCE = Vector3(0, 6.0, 0)
const WALL_JUMP_PUSH = 10.0
const WALL_SLIDE_GRAVITY_MODIFIER: float = 0.3

# -------------------------
# State Variables
# -------------------------
var is_paused = false
var is_sliding = false
var is_wallrunning = false
var jump := false
var pitch = 0.0
var camera_tilt_target: float = 0.0
var camera_tilt_speed: float = 10.0
var paused = false

# -------------------------
# Slide Collision Defaults
# -------------------------
var default_camera_height: float = 0.0
var default_fov: float = 75.0
var default_capsule_height: float
var default_capsule_pos_y: float
const SLIDE_COLLISION_HEIGHT = 1.0
const SLIDE_COLLISION_OFFSET = -0.5

# -------------------------
# Node References
# -------------------------
@onready var heath: Label = $Control/CanvasLayer/Node2D/Heath
@onready var heath_component: Node = $HealthComponent
@onready var camera: Camera3D = $head/Camera3D
@onready var wall_left = $WallLeft
@onready var wall_right = $WallRight
@onready var ground = $Floor
@onready var legs = $LEGS
@onready var leg_mesh = $LEGS/Armature_001
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@export var lean_amount: float = 5.0
@onready var speed_label: Label = $Control/CanvasLayer2/Node2D/SpeedometerLabel
@onready var grapple_weapon: Node3D = $head/Camera3D/OffhandManager/GrappleHook
# 🔫 Weapon Manager
@onready var weapon_manager: Node = $head/Camera3D/WeaponManager
@onready var pause_menu = $"Pause Menu"

# -------------------------
# Ready
# -------------------------
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	default_camera_height = camera.transform.origin.y
	default_fov = camera.fov

	# Store collision shape defaults
	var capsule: CapsuleShape3D = collision_shape.shape
	default_capsule_height = capsule.height
	default_capsule_pos_y = collision_shape.position.y
	grapple_weapon.player = self

# -------------------------
# Input Handling
# -------------------------
func _input(event: InputEvent):
	# Mouse look
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return

		rotation_degrees.y -= event.relative.x * mouse_sens * 5.0
		pitch = clamp(pitch - event.relative.y * mouse_sens * 5.0, -90.0, 90.0)
		camera.rotation_degrees.x = pitch

# Pass weapon input to WeaponManager
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("shoot"):
			weapon_manager.shoot_current()
		if event.is_action_pressed("next_weapon"):
			weapon_manager.equip_weapon((weapon_manager.current_weapon_index + 1) % weapon_manager.weapons.size())
		if event.is_action_pressed("last_weapon"):
			weapon_manager.equip_weapon((weapon_manager.current_weapon_index - 1 + weapon_manager.weapons.size()) % weapon_manager.weapons.size())
		if event.is_action_pressed("weapon_1"):
			weapon_manager.equip_weapon(0)
		if event.is_action_pressed("weapon_2"):
			weapon_manager.equip_weapon(1)
		if event.is_action_pressed("weapon_3"):
			weapon_manager.equip_weapon(2)

# -------------------------
# Camera & Slide
# -------------------------
func _update_camera_slide_and_fov(delta: float):
	# -------------------------
	# Handle camera height (slide)
	# -------------------------
	var cam_pos = camera.transform.origin
	var target_y: float = default_camera_height if not is_sliding else SLIDE_CAMERA_HEIGHT
	cam_pos.y = lerp(cam_pos.y, target_y, CAMERA_LERP_SPEED * delta)

	var cam_xform = camera.transform
	cam_xform.origin = cam_pos
	camera.transform = cam_xform

	# -------------------------
	# Handle FOV
	# -------------------------
	if is_sliding:
		# Slide FOV override
		var target_fov: float = SLIDE_FOV
		camera.fov = lerp(camera.fov, target_fov, FOV_LERP_SPEED * delta)
	else:
		# Speed-based FOV scaling
		var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
		var speed = horizontal_vel.length()

		# Map speed -> [BASE_FOV, MAX_FOV]
		var t = clamp(speed / MAX_SPEED, 0.0, 1.0)
		var target_fov: float = lerp(BASE_FOV, MAX_FOV, t)

		# Smooth it out
		camera.fov = lerp(camera.fov, target_fov, FOV_LERP_SPEED2 * delta)

# -------------------------
# Process
# -------------------------
func _process(delta):
	mouse_sens = Settings.mouse_sensitivity * 0.001
	controller_sens = Settings.controller_sensitivity * 5.0
	if Input.is_action_just_pressed("Pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pauseMenu()

	var peed = velocity.length()
	speed_label.text=str(round(peed))
	
	# Camera tilt
	var tilt_diff = camera_tilt_target - camera.rotation.z
	camera.rotation.z += tilt_diff * camera_tilt_speed * delta

# Controller right-stick look (polling)
	var look_x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	if abs(look_x) > look_deadzone or abs(look_y) > look_deadzone:
	# Horizontal: rotate player
		rotation_degrees.y -= look_x * controller_sens * delta
	# Vertical: adjust pitch
		var y_dir = -1.0 if invert_look_y else 1.0
		pitch = clamp(pitch - look_y * controller_sens * delta * y_dir, -90.0, 90.0)
		camera.rotation_degrees.x = pitch

	# Update UI
	heath.text = str(heath_component.heath)

	# Update leg animation
	if is_sliding:
		var target_leg_y = -0.3
		leg_mesh.position.y = lerp(leg_mesh.position.y, target_leg_y, delta * 10.0)
		var leg_tilt = deg_to_rad(pitch * 0.2)
		leg_mesh.rotation.x = lerp(leg_mesh.rotation.x, leg_tilt, delta * 10.0)
	else:
		leg_mesh.position.y = lerp(leg_mesh.position.y, 0.0, delta * 10.0)
		leg_mesh.rotation.x = lerp(leg_mesh.rotation.x, 0.0, delta * 10.0)

func pauseMenu():
	if paused:
		pause_menu.hide()
		Engine.time_scale = 1
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		pause_menu.show()
		Engine.time_scale = 0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	paused = !paused

func _physics_process(_delta: float) -> void:
	var density = velocity.length() * 0.025 
	$"Speed Lines".material.set_shader_parameter("line_density", density)

# -------------------------
# Slide Collision Adjust
# -------------------------
func set_slide_collision(sliding: bool):
	var capsule: CapsuleShape3D = collision_shape.shape
	if sliding:
		capsule.height = SLIDE_COLLISION_HEIGHT
		collision_shape.position.y = default_capsule_pos_y + SLIDE_COLLISION_OFFSET
	else:
		capsule.height = default_capsule_height
		collision_shape.position.y = default_capsule_pos_y

func apply_slope_surf(delta: float) -> void:
	if is_on_floor():
		var floor_normal = get_floor_normal()
		# If floor is NOT flat (0.99 = "almost flat ground")
		if floor_normal.y < 0.99:
			# Find the direction along the slope (ignores upward push)
			var slope_direction = Vector3(floor_normal.x, 0, floor_normal.z).normalized()
			# Steeper slope = stronger effect
			var slope_factor = 1.0 - floor_normal.y
			# How much extra push you get (tune this)
			var accel = 150.0
			# Add the push into velocity
			velocity += slope_direction * slope_factor * accel * delta
			# Optional: stop it from getting insane fast
			velocity = velocity.limit_length(100.0)  # change 50 to your max

# -------------------------
# Death Handling
# -------------------------
func on_death() -> void:
	get_tree().quit()
