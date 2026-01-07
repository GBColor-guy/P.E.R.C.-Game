extends Ctate
class_name EnemyAttack

@onready var enemy: CharacterBody3D = get_parent().get_parent()
@onready var animation_tree: AnimationTree = $"../../AnimationTree"

var player: CharacterBody3D = null
var animation_playeback: AnimationNodeStateMachinePlayback
var anim_names = ["attack", "attack2", "attack3"]

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Alayer")
	animation_playeback = animation_tree.get("parameters/playback")
	animation_tree.animation_finished.connect(_on_animation_finished)

func enter():
	enemy.velocity = Vector3.ZERO
	randomize()
	var random_anim = anim_names.pick_random()
	animation_playeback.travel(random_anim)

func process(delta: float) -> void:
	if player == null:
		return
	
	if enemy.global_position.distance_to(player.global_position) > enemy.AttackReach:
		emit_signal("Transitioned", self, "EnemyChase")

func physics_process(delta: float) -> void:
	# lock movement during attack
	enemy.velocity.x = 0
	enemy.velocity.z = 0
	
	if not enemy.is_on_floor():
		enemy.velocity += enemy.get_gravity() * delta
	
	enemy.move_and_slide()

func _on_animation_finished(anim_name):
	if player == null:
		return
	
	# continue attacking if still in range
	if enemy.global_position.distance_to(player.global_position) <= enemy.AttackReach:
		enter()
	else:
		emit_signal("Transitioned", self, "EnemyChase")

func _attack_player():
	if player == null:
		return
	
	var enemy_attack = Attack.new(5.0, enemy)
	player.heath_component.damage(enemy_attack)
