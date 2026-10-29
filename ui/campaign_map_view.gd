class_name CampaignMapView
extends Control
## Draws the campaign sector graph with primitives only: planets with a little
## ring/band/moon variation, the links between them, a green glow on the sectors
## that can be attacked, a check on conquered ones and a dim look on the rest.
## It holds no campaign state; the map layer tells it what to draw and it only
## reports which node was tapped.

signal sector_tapped(sector_id: StringName)

const NODE_RADIUS: float = 24.0
const GLOW_RADIUS: float = 7.0
const TAP_PADDING: float = 12.0
const LABEL_WIDTH: float = 120.0
const PLANET_COLORS: Array[Color] = [
	Color(0.45, 0.75, 1.0),
	Color(0.55, 0.95, 0.75),
	Color(1.0, 0.72, 0.42),
	Color(0.80, 0.60, 1.0),
	Color(1.0, 0.55, 0.60),
	Color(0.60, 0.92, 1.0),
	Color(0.95, 0.85, 0.45),
	Color(0.70, 1.0, 0.60),
	Color(0.90, 0.70, 0.95),
]
const BACKGROUND: Color = Color(0.02, 0.02, 0.07)
const LOCKED_TINT: Color = Color(0.30, 0.32, 0.40)
const CONQUERED_TINT: Color = Color(0.45, 1.0, 0.65)
const CHECK_COLOR: Color = Color(0.03, 0.16, 0.07)

var _available: Array[StringName] = []
var _conquered: Array[StringName] = []
var _selected: StringName = &""
var _pulse: float = 0.0
var _stars: Array[Vector2] = []


func _ready() -> void:
	# Static star field, generated once so it never flickers between frames.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261029
	for _index: int in 34:
		_stars.append(Vector2(rng.randf_range(8.0, 392.0), rng.randf_range(70.0, 592.0)))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse += delta
	queue_redraw()


func set_sectors(available: Array[StringName], conquered: Array[StringName], selected: StringName) -> void:
	_available = available.duplicate()
	_conquered = conquered.duplicate()
	if _selected != selected:
		_selected = selected
	queue_redraw()


func set_selection(sector_id: StringName) -> void:
	if _selected == sector_id:
		return
	_selected = sector_id
	queue_redraw()


## Which node is under this point, or an empty name when none is.
func sector_at(point: Vector2) -> StringName:
	for sector_id: StringName in Tuning.CAMPAIGN_ORDER:
		if point.distance_to(Campaign.position_of(sector_id)) <= NODE_RADIUS + TAP_PADDING:
			return sector_id
	return &""


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit: StringName = sector_at(mouse.position)
	if hit == &"":
		return
	accept_event()
	sector_tapped.emit(hit)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	for star: Vector2 in _stars:
		draw_circle(star, 1.0, Color(1.0, 1.0, 1.0, 0.35))
	_draw_links()
	for sector_id: StringName in Tuning.CAMPAIGN_ORDER:
		_draw_sector(sector_id)


func _draw_links() -> void:
	for sector_id: StringName in Tuning.CAMPAIGN_ORDER:
		var from: Vector2 = Campaign.position_of(sector_id)
		for link: StringName in Campaign.links_of(sector_id):
			var to: Vector2 = Campaign.position_of(link)
			draw_line(from, to, _link_color(sector_id, link), 1.5, true)


func _link_color(from: StringName, to: StringName) -> Color:
	if _conquered.has(to):
		return Color(0.35, 0.85, 0.5, 0.75)
	if _conquered.has(from) and _available.has(to):
		return Color(0.55, 0.95, 1.0, 0.7)
	if _conquered.has(from):
		return Color(0.35, 0.45, 0.6, 0.5)
	return Color(0.30, 0.32, 0.42, 0.35)


func _draw_sector(sector_id: StringName) -> void:
	var pos: Vector2 = Campaign.position_of(sector_id)
	var index: int = Tuning.CAMPAIGN_ORDER.find(sector_id)
	var base: Color = PLANET_COLORS[clampi(index, 0, PLANET_COLORS.size() - 1)]
	var conquered: bool = _conquered.has(sector_id)
	var available: bool = _available.has(sector_id)

	if conquered:
		_draw_planet(pos, base.lerp(CONQUERED_TINT, 0.45), index, 1.0)
		_draw_check(pos)
	elif available:
		var pulse: float = 0.5 + 0.5 * sin(_pulse * 3.0)
		draw_circle(pos, NODE_RADIUS + GLOW_RADIUS + 3.0 * pulse,
			Color(base.r, base.g, base.b, 0.14 + 0.10 * pulse))
		draw_arc(pos, NODE_RADIUS + 5.0, 0.0, TAU, 32, Color(base.r, base.g, base.b, 0.75), 2.0, true)
		_draw_planet(pos, base, index, 1.0)
	else:
		_draw_planet(pos, LOCKED_TINT, index, 0.55)

	if available and _selected == sector_id:
		draw_arc(pos, NODE_RADIUS + 10.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9), 2.0, true)

	if Campaign.has_boss(sector_id):
		_draw_boss_marker(pos, base if (conquered or available) else LOCKED_TINT)

	var label_color: Color = Color(0.92, 0.96, 1.0, 0.92) if (conquered or available) else Color(0.55, 0.58, 0.68, 0.75)
	draw_string(
		ThemeDB.fallback_font,
		pos + Vector2(-LABEL_WIDTH * 0.5, NODE_RADIUS + 16.0),
		Campaign.title(sector_id),
		HORIZONTAL_ALIGNMENT_CENTER,
		LABEL_WIDTH,
		9,
		label_color
	)


## Three flavours so the nine planets do not read as nine identical dots.
func _draw_planet(pos: Vector2, color: Color, index: int, alpha: float) -> void:
	var shade := Color(color.r * 0.45, color.g * 0.45, color.b * 0.55, alpha)
	draw_circle(pos, NODE_RADIUS, shade)
	draw_circle(
		pos - Vector2(NODE_RADIUS * 0.22, NODE_RADIUS * 0.22),
		NODE_RADIUS * 0.72,
		Color(color.r, color.g, color.b, alpha)
	)
	match index % 3:
		0:
			draw_line(
				pos + Vector2(-NODE_RADIUS * 0.7, NODE_RADIUS * 0.15),
				pos + Vector2(NODE_RADIUS * 0.7, NODE_RADIUS * 0.15),
				Color(0.0, 0.0, 0.0, 0.18 * alpha),
				3.0
			)
		1:
			draw_set_transform(pos, 0.0, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, NODE_RADIUS * 1.55, 0.0, TAU, 40,
				Color(color.r, color.g, color.b, 0.9 * alpha), 2.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			draw_circle(
				pos + Vector2(NODE_RADIUS * 1.15, -NODE_RADIUS * 0.95),
				5.0,
				Color(0.78, 0.82, 0.95, alpha)
			)


func _draw_check(pos: Vector2) -> void:
	draw_line(pos + Vector2(-8.0, 1.0), pos + Vector2(-2.0, 8.0), CHECK_COLOR, 3.0, true)
	draw_line(pos + Vector2(-2.0, 8.0), pos + Vector2(9.0, -7.0), CHECK_COLOR, 3.0, true)


func _draw_boss_marker(pos: Vector2, color: Color) -> void:
	var tip: Vector2 = pos + Vector2(NODE_RADIUS * 0.78, -NODE_RADIUS * 0.78)
	var diamond := PackedVector2Array([
		tip + Vector2(0.0, -6.0),
		tip + Vector2(6.0, 0.0),
		tip + Vector2(0.0, 6.0),
		tip + Vector2(-6.0, 0.0),
	])
	draw_colored_polygon(diamond, color)
