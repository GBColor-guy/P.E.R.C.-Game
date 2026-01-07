extends Node
class_name Ctate_machine

@export var InitalState: Ctate

var current_state: Ctate = null
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is Ctate:
			states[child.name.to_lower()] = child
			child.Transitioned.connect(on_child_transitioned)
			
			# Optional but very useful for AI states
			#if child.has_variable("state_machine"):
				#child.state_machine = self
	
	if InitalState:
		if not states.has(InitalState.name.to_lower()):
			push_warning("InitalState is not a child of Ctate_machine")
			return
		
		current_state = InitalState
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.process(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

func on_child_transitioned(state, new_state_name):
	if state != current_state:
		return
	
	var key: String = new_state_name.to_lower()
	
	if not states.has(key):
		push_warning("Attempted transition to unknown state: " + new_state_name)
		return
	
	var new_state: Ctate = states[key]
	
	if new_state == current_state:
		return
	
	current_state.exit()
	current_state = new_state
	current_state.enter()
