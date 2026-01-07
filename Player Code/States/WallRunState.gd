# WallRunState.gd
extends State

@export var min_speed: float = 5.0  # Minimum horizontal speed to maintain wall run
@onready var ground: RayCast3D = $"../../Floor"

var has_jumped: bool = false
var jump_during_coyote: bool = false


func enter(prev_state: String = "", data: Dictionary = {}) -> void:
	if data.has("jump_during_coyote"):
		jump_during_coyote = data["jump_during_coyote"]

	if jump_during_coyote:
		_do_jump()

	# Keep vertical speed stable
	player.velocity.y = clamp(player.velocity.y, -3.0, 3.0)
	_update_camera_tilt()


func physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	player.velocity.y -= gravity * player.WALL_SLIDE_GRAVITY_MODIFIER * delta

	# --- Jumping off the wall ---
	if Input.is_action_just_pressed("jump"):
		_do_jump()
		state_machine.switch_state(state_machine.get_node("AirState"))
		return

	# --- Exit conditions ---
	if ground and ground.is_colliding():
		state_machine.switch_state(state_machine.get_node("MoveState"))
		return

	var next_to_wall: bool = _is_next_to_wall()
	var too_slow: bool = _is_too_slow()
	if not next_to_wall or too_slow:
		# Add small outward push if we lost the wall due to speed or angle
		var normal: Vector3 = _get_wall_normal()
		if normal != Vector3.ZERO:
			player.velocity += normal * 3.0
		state_machine.switch_state(state_machine.get_node("AirState"))
		return

	# --- Wall-run motion ---
	player.move_and_slide()
	player._update_camera_slide_and_fov(delta)


func _do_jump() -> void:
	has_jumped = true
	player.jump = false
	player.velocity.y = player.JUMP_VELOCITY
	var wall_normal: Vector3 = _get_wall_normal()
	player.velocity += wall_normal * player.JUMP_VELOCITY


func _get_wall_normal() -> Vector3:
	var left_colliding: bool = false
	var right_colliding: bool = false

	if player.wall_left:
		left_colliding = player.wall_left.is_colliding()
	if player.wall_right:
		right_colliding = player.wall_right.is_colliding()

	if left_colliding and right_colliding:
		var n1: Vector3 = player.wall_left.get_collision_normal()
		var n2: Vector3 = player.wall_right.get_collision_normal()
		var avg: Vector3 = (n1 + n2).normalized()
		if avg.length() < 0.1:
			return n1
		return avg
	elif left_colliding:
		return player.wall_left.get_collision_normal()
	elif right_colliding:
		return player.wall_right.get_collision_normal()

	return Vector3.ZERO


func _is_next_to_wall() -> bool:
	var left: bool = false
	var right: bool = false
	if player.wall_left:
		left = player.wall_left.is_colliding()
	if player.wall_right:
		right = player.wall_right.is_colliding()
	return left or right


func _is_too_slow() -> bool:
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	return horizontal_speed < min_speed


func _update_camera_tilt() -> void:
	if player.wall_left and player.wall_left.is_colliding():
		player.camera_tilt_target = deg_to_rad(-15)
	elif player.wall_right and player.wall_right.is_colliding():
		player.camera_tilt_target = deg_to_rad(15)
	else:
		player.camera_tilt_target = 0.0


func exit() -> void:
	player.camera_tilt_target = 0.0
