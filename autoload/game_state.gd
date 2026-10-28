extends Node
## Global game state machine. Owns the single rule that the scene tree is
## paused in every state except PLAYING, so entities never need to ask
## "am I allowed to run?" themselves.

signal state_changed(new_state: State)

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

var state: State = State.MENU


func _ready() -> void:
	# Must keep working while the tree is paused (pause toggle, UI).
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = state != State.PLAYING


## The only way to move between states, so pause always matches the state.
func change_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	get_tree().paused = state != State.PLAYING
	state_changed.emit(state)


func is_playing() -> bool:
	return state == State.PLAYING


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if state == State.PLAYING:
		change_state(State.PAUSED)
	elif state == State.PAUSED:
		change_state(State.PLAYING)
	else:
		return
	get_viewport().set_input_as_handled()
