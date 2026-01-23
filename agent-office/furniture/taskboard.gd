extends FurnitureBase
class_name FurnitureTaskboard

## Office taskboard/whiteboard - displays watcher information.
## Wall-mounted on easel, agents can view it.
## Traits: viewable, social

func _init() -> void:
	furniture_type = "taskboard"
	traits = ["viewable", "social"]
	capacity = 3
	wall_mounted = true
	obstacle_size = Vector2(170, 130)

	# Viewing positions (below the board)
	slots = [
		{"offset": Vector2(25, 200), "occupied_by": ""},   # Left viewer
		{"offset": Vector2(85, 200), "occupied_by": ""},   # Center viewer
		{"offset": Vector2(145, 200), "occupied_by": ""},  # Right viewer
	]

func _ready() -> void:
	click_area = Rect2(0, 0, 170, 130)
	use_dynamic_z_index = false
	z_index = OfficeConstants.Z_TASKBOARD

	# Taskboard has custom drag bounds (can go on floor with easel)
	drag_bounds_min = Vector2(30, 100)
	drag_bounds_max = Vector2(1100, 520)

	super._ready()

func _build_visuals() -> void:
	var leg_color = OfficePalette.TASKBOARD_EASEL_LEG
	var leg_z = OfficeConstants.Z_TASKBOARD_LEGS

	# Left leg
	var left_leg = ColorRect.new()
	left_leg.size = Vector2(6, 70)
	left_leg.position = Vector2(25, 125)
	left_leg.color = leg_color
	left_leg.z_as_relative = false
	left_leg.z_index = leg_z
	add_child(left_leg)

	# Right leg
	var right_leg = ColorRect.new()
	right_leg.size = Vector2(6, 70)
	right_leg.position = Vector2(139, 125)
	right_leg.color = leg_color
	right_leg.z_as_relative = false
	right_leg.z_index = leg_z
	add_child(right_leg)

	# Cross brace between legs
	var brace = ColorRect.new()
	brace.size = Vector2(100, 4)
	brace.position = Vector2(38, 165)
	brace.color = leg_color
	brace.z_as_relative = false
	brace.z_index = leg_z
	add_child(brace)

	# Whiteboard frame (silver/aluminum)
	var frame = ColorRect.new()
	frame.size = Vector2(170, 130)
	frame.position = Vector2(0, 0)
	frame.color = OfficePalette.TASKBOARD_FRAME
	add_child(frame)

	# Whiteboard surface
	var surface = ColorRect.new()
	surface.size = Vector2(162, 122)
	surface.position = Vector2(4, 4)
	surface.color = OfficePalette.TASKBOARD_BG
	add_child(surface)

	# Header text (handwritten style)
	var header = Label.new()
	header.text = "Watchers"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(4, 6)
	header.size = Vector2(162, 18)
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", OfficePalette.TASKBOARD_HEADER_TEXT)
	add_child(header)

	# Underline
	var underline = ColorRect.new()
	underline.size = Vector2(80, 2)
	underline.position = Vector2(45, 22)
	underline.color = OfficePalette.TASKBOARD_HEADER_TEXT
	add_child(underline)
