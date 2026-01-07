extends Node
class_name Ctate
signal Transitioned(Ctate, new_state_name: String)

func enter() -> void: pass

func exit() -> void: pass

func process_physics(delta: float) -> Ctate: return null

func process_frame(delta: float) -> Ctate: return null

func process_input(event: InputEvent) -> Ctate: return null
