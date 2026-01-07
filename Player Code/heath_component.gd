extends Node
class_name Player_heath

@export var MaxHeath: float = 100.0

var heath: float = MaxHeath

# Called every frame. 'delta' is the elapsed time since the previous frame.
func damage(attack: Attack) -> void:
	heath -= attack.damage
	
	var parent: Node3D = get_parent()
	if parent.has_method("on_damage"):
		parent.on_damage(attack)
	
	if heath <= 0:
		get_parent().on_death()
