# StateMachine.gd
extends Node

var current_state: State

func _ready():
	for child in get_children():
		if child is State:
			child.player = get_parent()
			child.state_machine = self
	switch_state($MoveState)  # Start with MoveState

func switch_state(new_state: State):
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()

func _input(event):
	if current_state:
		current_state.handle_input(event)

func _physics_process(delta):
	if current_state:
		current_state.physics_process(delta)
