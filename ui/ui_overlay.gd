extends CanvasLayer
## Global controls overlay. C opens a read-only CONTROLS card from any screen --
## menu, map, battle or pause card -- with a REMAP button that turns it into the
## editable card. In battle it pauses the run and resumes it on close.
##
## It is an autoload on a high layer, so every scene gets the same behaviour and
## the card is never hidden behind a screen's own panels. Android Back and B
## close it from any screen.

const CARD_SCENE: PackedScene = preload("res://ui/controls_card.tscn")

var _card: ControlsCard
var _paused_by_us: bool = false
var _previous_back: Callable = Callable()


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = CARD_SCENE.instantiate() as ControlsCard
	add_child(_card)
	UITheme.apply(_card)
	_card.configure_read_only(true)
	_card.closed.connect(_on_closed)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("controls"):
		return
	# While the card is capturing a key, C is a binding, not a close request.
	if _card.is_capturing():
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	# Marked before either call: both can change the game state, and a state
	# change is what the screens underneath react to.
	vp.set_input_as_handled()
	if _card.visible:
		_card.close()
	else:
		open_card()


func open_card() -> void:
	if _card.visible:
		return
	_paused_by_us = GameState.state == GameState.State.PLAYING
	_previous_back = GameState.back_handler
	GameState.back_handler = _handle_back
	if _paused_by_us:
		GameState.change_state(GameState.State.PAUSED)
	_card.configure_read_only(true)
	_card.open()


func _on_closed() -> void:
	if _paused_by_us:
		_paused_by_us = false
		GameState.change_state(GameState.State.PLAYING)
	if _previous_back.is_valid():
		GameState.back_handler = _previous_back
	_previous_back = Callable()


## Back closes the card instead of leaving the screen underneath it.
func _handle_back() -> void:
	GameState.back_handler = _handle_back
	_card.close()
