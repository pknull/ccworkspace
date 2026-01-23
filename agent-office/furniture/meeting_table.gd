extends FurnitureBase
class_name FurnitureMeetingTable

## Office meeting/conference table - overflow location when desks are full.
## Agents stand around the table waiting for a desk.
## Traits: overflow, social

func _init() -> void:
	furniture_type = "meeting_table"
	traits = ["overflow", "social"]
	capacity = 8
	obstacle_size = Vector2(130, 70)

	# Standing positions around the table
	slots = [
		{"offset": Vector2(-60, -30), "occupied_by": ""},   # Left-top
		{"offset": Vector2(-60, 30), "occupied_by": ""},    # Left-bottom
		{"offset": Vector2(60, -30), "occupied_by": ""},    # Right-top
		{"offset": Vector2(60, 30), "occupied_by": ""},     # Right-bottom
		{"offset": Vector2(-20, -60), "occupied_by": ""},   # Top-left
		{"offset": Vector2(20, -60), "occupied_by": ""},    # Top-right
		{"offset": Vector2(-20, 60), "occupied_by": ""},    # Bottom-left
		{"offset": Vector2(20, 60), "occupied_by": ""},     # Bottom-right
	]

func _ready() -> void:
	click_area = Rect2(-65, -35, 130, 70)
	super._ready()

func _build_visuals() -> void:
	# Shadow under table
	var shadow = ColorRect.new()
	shadow.size = Vector2(130, 20)
	shadow.position = Vector2(-65, 25)
	shadow.color = OfficePalette.SHADOW
	add_child(shadow)

	# Table legs (4 corners, visible from top-down angle)
	var leg_positions = [
		Vector2(-50, -20), Vector2(50, -20),  # Back legs
		Vector2(-50, 20), Vector2(50, 20),    # Front legs
	]
	for leg_pos in leg_positions:
		var leg = ColorRect.new()
		leg.size = Vector2(8, 8)
		leg.position = leg_pos - Vector2(4, 4)
		leg.color = OfficePalette.MEETING_TABLE_LEG
		add_child(leg)

	# Table edge (front face - darker)
	var edge_front = ColorRect.new()
	edge_front.size = Vector2(120, 8)
	edge_front.position = Vector2(-60, 22)
	edge_front.color = OfficePalette.MEETING_TABLE_EDGE
	add_child(edge_front)

	# Table surface (main top - lighter wood)
	var surface = ColorRect.new()
	surface.size = Vector2(120, 50)
	surface.position = Vector2(-60, -28)
	surface.color = OfficePalette.MEETING_TABLE_SURFACE
	add_child(surface)

	# Surface edge detail (lighter strip at top for 3D effect)
	var edge_top = ColorRect.new()
	edge_top.size = Vector2(120, 4)
	edge_top.position = Vector2(-60, -28)
	edge_top.color = OfficePalette.MEETING_TABLE_SURFACE.lightened(0.1)
	add_child(edge_top)

	# Center decoration (subtle inlay pattern)
	var inlay = ColorRect.new()
	inlay.size = Vector2(80, 30)
	inlay.position = Vector2(-40, -18)
	inlay.color = OfficePalette.MEETING_TABLE_SURFACE.darkened(0.05)
	add_child(inlay)
