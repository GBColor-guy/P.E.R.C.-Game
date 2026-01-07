# MoveState.gd
extends State

@onready var camera_3d: Camera3D = $"../../head/Camera3D"

var bob_timer: float = 0.0
const WALK_BOB_SPEED = 10.0
const SPRINT_BOB_SPEED = 16.0
const BOB_AMOUNT = 0.1 # vertical movement in meters

func physics_process(delta):
	var player = self.player
	var input_dir: Vector2 = Input.get_vector("left", "right", "down", "up")
	var velocity = player.velocity
	var move_input = input_dir.length() > 0

	var flat_rotation = Basis(Vector3.UP, player.rotation.y)
	var move_dir = (flat_rotation * Vector3(input_dir.x, 0, -input_dir.y)).normalized()

	# Sprint check
	var is_sprinting = Input.is_action_pressed("sprint")
	var target_speed = player.MAX_SPRINT_SPEED if is_sprinting else player.MAX_WALK_SPEED

	# === Only handle grounded movement here ===
	if player.is_on_floor():
		var current_hvel = Vector3(velocity.x, 0, velocity.z)

		if move_input:
			var target = move_dir * target_speed
			current_hvel = current_hvel.move_toward(target, player.ACCEL * delta * 5.0)
		else:
			current_hvel = current_hvel.move_toward(Vector3.ZERO, player.DEACCEL * delta * 2.0)

		var max_allowed_speed = player.MAX_BHOP_SPEED
		var current_speed = current_hvel.length()
		if current_speed > max_allowed_speed:
			var new_speed = lerp(current_speed, max_allowed_speed, 3.5 * delta)
			current_hvel = current_hvel.normalized() * new_speed

		# Apply horizontal velocity
		velocity.x = current_hvel.x
		velocity.z = current_hvel.z

		# Jump
		if Input.is_action_just_pressed("jump"):
			velocity.y = player.JUMP_VELOCITY

		# Slide
		elif Input.is_action_just_pressed("slide") and move_input:
			state_machine.switch_state(state_machine.get_node("SlideState"))
			return

	else:
		# 🚀 Immediately switch to air state so it handles air movement
		state_machine.switch_state(state_machine.get_node("AirState"))
		return

	# Gravity
	velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	# Move and apply
	player.velocity = velocity
	player.move_and_slide()
	player._update_camera_slide_and_fov(delta)

	# Leaning
	if input_dir.x != 0 and player.is_on_floor():
		player.camera_tilt_target = deg_to_rad(-input_dir.x * player.lean_amount)
	else:
		player.camera_tilt_target = 0.0

	# Head bobbing
	if move_input and player.is_on_floor() and not player.is_sliding:
		var bob_speed = SPRINT_BOB_SPEED if is_sprinting else WALK_BOB_SPEED
		bob_timer += delta * bob_speed
		var bob_offset = sin(bob_timer) * BOB_AMOUNT

		var cam_pos = player.camera.transform.origin
		cam_pos.y = player.default_camera_height + bob_offset
		var cam_xform = player.camera.transform
		cam_xform.origin = cam_pos
		player.camera.transform = cam_xform
	else:
		bob_timer = 0.0
		var cam_pos = player.camera.transform.origin
		cam_pos.y = lerp(cam_pos.y, player.default_camera_height, delta * 8.0)
		var cam_xform = player.camera.transform
		cam_xform.origin = cam_pos
		player.camera.transform = cam_xform
