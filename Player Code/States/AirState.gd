extends State

# --- Slide & Jump Buffers ---
const SLIDE_BUFFER_TIME := 0.5

@onready var legs_anim: AnimationPlayer = $"../../LEGS/AnimationPlayer"
@onready var jump: AudioStreamPlayer = $"../../Soundefx/jump"

var buffered_slide: bool = false
var slide_buffer_timer: float = 0.0
var jump_buffered: bool = false
var sound_play
var sound_jump = []

func enter():
	var jump1 = preload("res://SoundEFX/Player/Jump1.mp3")
	var jump2 = preload("res://SoundEFX/Player/Jump2.mp3")
	var jump3 = preload("res://SoundEFX/Player/Jump3.mp3")
	var jump4 = preload("res://SoundEFX/Player/Jump4.mp3")
	var jump5 = preload("res://SoundEFX/Player/Jump5.mp3")
	var jump6 = preload("res://SoundEFX/Player/Jump6.mp3")
	var jump7 = preload("res://SoundEFX/Player/Jump7.mp3")
	var jump8 = preload("res://SoundEFX/Player/Jump8.mp3")
	sound_jump = [jump1, jump2, jump3, jump4, jump5, jump6, jump7, jump8]
	randomize()
	play_random_jump()

func play_random_jump():
	if sound_jump.size() > 0:
		var random_index = randi() % sound_jump.size()
		jump.stream = sound_jump[random_index]
		jump.play()

func physics_process(delta: float) -> void:
	var player = self.player

	# --- Jump Input Buffer ---
	if Input.is_action_just_pressed("jump"):
		# Optional: check RayCast (player.ground) to see if jump should trigger instantly
		if player.ground and player.ground.is_colliding():
			jump_buffered = true

	if Input.is_action_just_pressed("dropkick") and not player.is_on_floor():
		state_machine.switch_state(state_machine.get_node("DropKickState"))
		

	# --- Slide Input Buffer ---
	if Input.is_action_just_pressed("slide"):
		buffered_slide = true
		slide_buffer_timer = SLIDE_BUFFER_TIME

	if buffered_slide:
		slide_buffer_timer -= delta
		if slide_buffer_timer <= 0.0:
			buffered_slide = false

	# --- Landing Transition ---
	if player.is_on_floor():
		if jump_buffered:
			player.velocity.y = player.JUMP_VELOCITY
			jump_buffered = false
			return

		if buffered_slide:
			buffered_slide = false
			state_machine.switch_state(state_machine.get_node("SlideState"))
			return

		state_machine.switch_state(state_machine.get_node("MoveState"))
		return

	# --- Wall Run Transition ---
	if is_next_to_wall() and player.velocity.y < 0.0:
		state_machine.switch_state(state_machine.get_node("WallRunState"))
		return

	# --- Air Movement ---
	var input_dir: Vector2 = Input.get_vector("left", "right", "down", "up")
	if input_dir != Vector2.ZERO:
		var desired: Vector3 = (player.transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
		var accel: Vector3 = desired * player.AIR_ACCEL * delta * player.AIR_CONTROL

		# Apply acceleration only horizontally
		player.velocity.x += accel.x
		player.velocity.z += accel.z

		# Limit horizontal speed to maintain control
		var horizontal_vel := Vector2(player.velocity.x, player.velocity.z)
		if horizontal_vel.length() > player.MAX_BHOP_SPEED:
			horizontal_vel = horizontal_vel.normalized() * player.MAX_BHOP_SPEED
			player.velocity.x = horizontal_vel.x
			player.velocity.z = horizontal_vel.y

	# --- Gravity ---
	player.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	# --- Apply Movement ---
	player.apply_slope_surf(delta)
	player.move_and_slide()
	player._update_camera_slide_and_fov(delta)

func is_next_to_wall() -> bool:
	if not player:
		return false
	return player.wall_left.is_colliding() or player.wall_right.is_colliding()
