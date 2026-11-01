extends CanvasLayer
## Global controls overlay. C opens a read-only CONTROLS card from any screen --
## menu, map, battle or pause card -- with a REMAP button that turns it into the
## editable card. In battle it pauses the run and resumes it on close.
##
## It is an autoload on a high layer, so every scene gets the same behaviour and
## the card is never hidden behind a screen's own panels. Android Back and B
## close it from any screen.

## Fired whenever the overlay takes the screen, so screens can stand their own
## transient banners down instead of drawing them on top of the card.
signal card_opened

const CARD_SCENE: PackedScene = preload("res://ui/panels/controls_card.tscn")

var _card: ControlsCard
var _paused_by_us: bool = false
var _previous_back: Callable = Callable()
## Debug-only layout audit (F4): outlines every visible card and the box its
## children actually occupy, so space a card reserves but does not use shows up
## as a gap between the two rectangles.
var _layout_overlay: Control


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = CARD_SCENE.instantiate() as ControlsCard
	add_child(_card)
	UITheme.apply(_card)
	_card.configure_read_only(true)
	_card.closed.connect(_on_closed)
	_layout_overlay = Control.new()
	_layout_overlay.name = "LayoutDebugOverlay"
	_layout_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_overlay.visible = false
	_layout_overlay.draw.connect(_draw_layout_debug)
	add_child(_layout_overlay)


func _input(event: InputEvent) -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	# F4 is a debug-only card audit; it is not an action and cannot be remapped.
	if OS.is_debug_build() and event is InputEventKey:
		var audit_key := event as InputEventKey
		if audit_key.pressed and not audit_key.echo and audit_key.physical_keycode == KEY_F4:
			vp.set_input_as_handled()
			_toggle_layout_debug()
			return
	if not event.is_action_pressed("controls"):
		return
	# While the card is capturing a key, C is a binding, not a close request.
	if _card.is_capturing():
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
	card_opened.emit()
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


# --- Debug layout audit (F4) ------------------------------------------------

func _toggle_layout_debug() -> void:
	_layout_overlay.visible = not _layout_overlay.visible
	if _layout_overlay.visible:
		_layout_overlay.queue_redraw()


## Red is the card's own rect, green is the bounding box of its children. A red
## band outside the green box is space the card reserves and does not use.
func _draw_layout_debug() -> void:
	var cards: Array[PanelContainer] = []
	_collect_cards(get_tree().root, cards)
	for card: PanelContainer in cards:
		if not card.is_visible_in_tree() or card.size.x < 1.0:
			continue
		var outer: Rect2 = card.get_global_rect()
		_layout_overlay.draw_rect(outer, Color(1.0, 0.35, 0.35, 0.9), false, 1.0)
		var inner: Rect2 = _card_content_rect(card)
		if inner.size.x >= 1.0 and inner.size.y >= 1.0:
			_layout_overlay.draw_rect(inner, Color(0.4, 1.0, 0.55, 0.85), false, 1.0)


## Cards are the only nodes the audit cares about, so it never descends into
## one: everything under a card is its content, which is measured separately.
func _collect_cards(node: Node, out: Array[PanelContainer]) -> void:
	if node is PanelContainer:
		out.append(node as PanelContainer)
		return
	for child: Node in node.get_children():
		_collect_cards(child, out)


func _card_content_rect(card: PanelContainer) -> Rect2:
	var box := Rect2()
	var first: bool = true
	for child: Node in card.get_children():
		if not child is Control:
			continue
		var control := child as Control
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		box = rect if first else box.merge(rect)
		first = false
	return box
