extends State

const SLIDE_MIN_SPEED = 1.0
const SLIDE_INITIAL_BOOST = 1.25   # smaller, since we now preserve incoming speed
const SLIDE_JUMP_BOOST = 1.1

@onready var animation: AnimationPlayer = $"../../LEGS/AnimationPlayer"
var is_sliding = false

func enter():
	var player = self.player
	player.is_sliding = true
	is_sliding = true

	# Shrink collision for sliding
	player.set_slide_collision(true)

	# Play legs animation
	if animation:
		animation.play("Slide")

	# Optional: Play sound
	var audio = player.legs.get_node("AudioStreamPlayer")
	if audio:
		audio.play()

	# === Preserve existing momentum ===
	var horizontal_vel = Vector3(player.velocity.x, 0, player.velocity.z)
	var current_speed = horizontal_vel.length()

	# Use player's current facing as fallback if almost stationary
	var look_dir = -player.transform.basis.z
	look_dir.y = 0
	look_dir = look_dir.normalized()

	if current_speed < 1.0:
		horizontal_vel = look_dir * player.SLIDE_SPEED

	# Normalize and apply slight initial boost *based on existing momentum*
	var slide_dir = horizontal_vel.normalized()
	var boost_factor = 1.0

	# Only give extra boost if entering slide while sprinting or moving fast
	if current_speed > player.MAX_WALK_SPEED:
		boost_factor = SLIDE_INITIAL_BOOST

	var final_speed = max(current_speed * boost_factor, player.SLIDE_SPEED)
	player.velocity.x = slide_dir.x * final_speed
	player.velocity.z = slide_dir.z * final_speed

func physics_process(delta):
	var player = self.player

	# === Jump cancels slide ===
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.velocity.y = player.JUMP_VELOCITY
		var flat_vel = Vector3(player.velocity.x, 0, player.velocity.z)
		if flat_vel.length() > 0.0:
			var boosted = flat_vel.normalized() * flat_vel.length() * SLIDE_JUMP_BOOST
			player.velocity.x = boosted.x
			player.velocity.z = boosted.z
		end_slide()
		state_machine.switch_state(state_machine.get_node("AirState"))
		return

	# === Cancel if too slow or not holding ===
	if not Input.is_action_pressed("slide") or Vector2(player.velocity.x, player.velocity.z).length() < SLIDE_MIN_SPEED:
		end_slide()
		state_machine.switch_state(state_machine.get_node("MoveState"))
		return

	# === Directional steering ===
	var look_dir = -player.transform.basis.z
	look_dir.y = 0
	look_dir = look_dir.normalized()

	var current_hvel = Vector3(player.velocity.x, 0, player.velocity.z)
	var speed = current_hvel.length()

	# Smoothly steer toward where you're looking while keeping most of your velocity
	var target_vel = look_dir * speed
	var steer_strength = 6.0  # smaller = smoother steering
	current_hvel = current_hvel.lerp(target_vel, steer_strength * delta)

	# === Apply slide friction ===
	var friction = player.SLIDE_FRICTION
	var new_speed = move_toward(current_hvel.length(), 0.0, friction * delta)
	if new_speed > 0.0:
		current_hvel = current_hvel.normalized() * new_speed
	else:
		current_hvel = Vector3.ZERO

	player.velocity.x = current_hvel.x
	player.velocity.z = current_hvel.z

	# === Gravity ===
	player.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	# === Slope surfing ===
	if player.is_on_floor():
		var floor_normal = player.get_floor_normal()
		if floor_normal.y < 0.99: # on slope
			var slide_dir = player.velocity.slide(floor_normal).normalized()
			var slope_factor = 1.0 - floor_normal.y
			var accel = 100.0
			player.velocity += slide_dir * slope_factor * accel * delta

	player.apply_slope_surf(delta)

	# === Movement & camera updates ===
	player.move_and_slide()
	player._update_camera_slide_and_fov(delta)

func end_slide():
	var player = self.player
	player.is_sliding = false
	is_sliding = false

	# Reset collision height
	player.set_slide_collision(false)

	if animation:
		animation.play("GetUp")
