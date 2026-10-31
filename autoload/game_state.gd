extends Node
## Global game state machine. Owns the single rule that the scene tree is
## paused in every state except PLAYING, so entities never need to ask
## "am I allowed to run?" themselves.
##
## MENU and MAP are hub screens (HUD panels and the campaign map), PLAYING is
## the only state where the tree runs, PAUSED freezes a live run, and GAME_OVER
## and BATTLE_WON are both frozen summaries of a finished run.

enum State { MENU, PLAYING, PAUSED, GAME_OVER, MAP, BATTLE_WON }

signal state_changed(new_state: State)

var state: State = State.MENU
## Optional hook for an open menu overlay: while set, Back closes that overlay
## instead of moving between game states. The HUD installs it (and clears it)
## so a "how to play" screen can be dismissed with Android's back button.
var back_handler: Callable = Callable()


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


## Focus loss and Android's back button. Only a live run is worth pausing;
## menus are already stopped and must not fight the player's choice.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if state == State.PLAYING:
				change_state(State.PAUSED)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back_request()


func _handle_back_request() -> void:
	if back_handler.is_valid():
		var handler: Callable = back_handler
		back_handler = Callable()
		handler.call()
		return
	match state:
		State.PLAYING:
			change_state(State.PAUSED)
		State.PAUSED, State.GAME_OVER:
			change_state(State.MENU)
		State.MAP:
			change_state(State.MENU)
		State.BATTLE_WON:
			# Continue by default; a finished campaign installs its own handler.
			change_state(State.MAP)
		State.MENU:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	# Captured first: `change_state` emits, and a listener may rebuild the tree.
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	# Only the two live states consume the key; in MENU, MAP and the summary
	# cards the screen below still gets to use pause as Back.
	if state == State.PLAYING:
		vp.set_input_as_handled()
		change_state(State.PAUSED)
	elif state == State.PAUSED:
		vp.set_input_as_handled()
		change_state(State.PLAYING)
	else:
		return
