extends Ctate
class_name EnemyWander

var wander_direction: Vector3
var wander_time = 0.0

@onready var enemy : CharacterBody3D = get_parent().get_parent()
@onready var animation_tree: AnimationTree = $"../../AnimationTree"
var player: CharacterBody3D = null
var animation_playeback: AnimationNodeStateMachinePlayback

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Alayer")
	animation_playeback = animation_tree.get("parameters/playback")

func randomize_variables():
	wander_time = randf_range(1.5, 4)
	
	if randi_range(0, 3) != 1:
		wander_direction = Vector3(
			randf_range(-1.0, 1.0),
			0.0,
			randf_range(-1.0, 1.0)
		).normalized()
		animation_playeback.travel("wonder")
	else:
		wander_direction = Vector3.ZERO
		animation_playeback.travel("idle")

func enter():
	randomize_variables()

func process(delta: float) -> void:
	wander_time -= delta
	
	if wander_time <= 0.0:
		randomize_variables()
	
	if player == null:
		return
	
	if enemy.global_position.distance_to(player.global_position) < enemy.ChaseDistance:
		emit_signal("Transitioned", self, "EnemyChase")

func physics_process(delta: float) -> void:
	enemy.velocity.x = wander_direction.x * enemy.WalkSpeed
	enemy.velocity.z = wander_direction.z * enemy.WalkSpeed
	
	if not enemy.is_on_floor():
		enemy.velocity += enemy.get_gravity() * delta
	
	if wander_direction != Vector3.ZERO:
		enemy.look_at(enemy.global_position + wander_direction, Vector3.UP)
	
	enemy.move_and_slide()