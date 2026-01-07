extends Ctate
class_name EnemyChase

@onready var enemy: CharacterBody3D = get_parent().get_parent()
@onready var animation_tree: AnimationTree = $"../../AnimationTree"

var player: CharacterBody3D
var animation_playeback: AnimationNodeStateMachinePlayback

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	animation_playeback = animation_tree.get("parameters/playback")

func enter():
	animation_playeback.travel("chase")

func process(delta: float):
	if not player or not enemy.nav_agent:
		return

	var distance := enemy.global_position.distance_to(player.global_position)

	enemy.nav_agent.set_target_position(player.global_position)

	if distance > enemy.ChaseDistance:
		emit_signal("Transitioned", self, "EnemyWander")
		return
	
	if distance < enemy.AttackReach:
		emit_signal("Transitioned", self, "EnemyAttack")
		return

func physics_process(delta: float) -> void:
	if not enemy.nav_agent:
		return

	if enemy.nav_agent.is_navigation_finished():
		enemy.velocity.x = 0
		enemy.velocity.z = 0
		enemy.move_and_slide()
		return

	var next_position = enemy.nav_agent.get_next_path_position()
	var direction = next_position - enemy.global_position
	direction.y = 0
	direction = direction.normalized()

	enemy.velocity.x = direction.x * enemy.RunSpeed
	enemy.velocity.z = direction.z * enemy.RunSpeed

	if enemy.is_on_floor():
		enemy.velocity.y = 0
	else:
		enemy.velocity.y += enemy.get_gravity().y * delta

	if direction != Vector3.ZERO:
		enemy.look_at(enemy.global_position + direction, Vector3.UP)

	enemy.move_and_slide()