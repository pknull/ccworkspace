class_name OfficeVisualFactory

# Factory class for creating office furniture and decorations
# Extracts visual creation logic from OfficeManager for better separation of concerns

static func create_water_cooler(draggable_script: Script) -> Node2D:
	var cooler = draggable_script.new()
	cooler.item_name = "water_cooler"
	cooler.set_click_area(Rect2(-20, -30, 40, 70))

	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(32, 12)
	shadow.position = Vector2(-16, 32)
	shadow.color = OfficePalette.SHADOW
	cooler.add_child(shadow)

	# Base (top-down view - see the top surface)
	var base_front = ColorRect.new()
	base_front.size = Vector2(28, 12)
	base_front.position = Vector2(-14, 24)
	base_front.color = OfficePalette.COOLER_BASE_DARK
	cooler.add_child(base_front)

	var base_top = ColorRect.new()
	base_top.size = Vector2(28, 8)
	base_top.position = Vector2(-14, 16)
	base_top.color = OfficePalette.COOLER_BASE
	cooler.add_child(base_top)

	# Body (main unit - show top and front)
	var body_front = ColorRect.new()
	body_front.size = Vector2(24, 20)
	body_front.position = Vector2(-12, -4)
	body_front.color = OfficePalette.COOLER_BODY_FRONT
	cooler.add_child(body_front)

	var body_top = ColorRect.new()
	body_top.size = Vector2(24, 8)
	body_top.position = Vector2(-12, -12)
	body_top.color = OfficePalette.COOLER_BODY_TOP
	cooler.add_child(body_top)

	# Water bottle (top-down - see circular top)
	var bottle_body = ColorRect.new()
	bottle_body.size = Vector2(18, 18)
	bottle_body.position = Vector2(-9, -30)
	bottle_body.color = OfficePalette.COOLER_BOTTLE
	cooler.add_child(bottle_body)

	var bottle_top = ColorRect.new()
	bottle_top.size = Vector2(14, 6)
	bottle_top.position = Vector2(-7, -34)
	bottle_top.color = OfficePalette.COOLER_BOTTLE_TOP
	cooler.add_child(bottle_top)

	# Tap (small detail on front)
	var tap = ColorRect.new()
	tap.size = Vector2(6, 4)
	tap.position = Vector2(-3, 4)
	tap.color = OfficePalette.COOLER_TAP
	cooler.add_child(tap)

	return cooler

static func create_potted_plant(draggable_script: Script) -> Node2D:
	var plant = draggable_script.new()
	plant.item_name = "plant"
	plant.set_click_area(Rect2(-25, -25, 50, 60))

	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(36, 14)
	shadow.position = Vector2(-18, 28)
	shadow.color = OfficePalette.SHADOW
	plant.add_child(shadow)

	# Pot front face (darker)
	var pot_front = ColorRect.new()
	pot_front.size = Vector2(32, 16)
	pot_front.position = Vector2(-16, 14)
	pot_front.color = OfficePalette.POT_TERRACOTTA_DARK
	plant.add_child(pot_front)

	# Pot top rim (lighter, shows depth)
	var pot_rim = ColorRect.new()
	pot_rim.size = Vector2(34, 6)
	pot_rim.position = Vector2(-17, 8)
	pot_rim.color = OfficePalette.POT_RIM
	plant.add_child(pot_rim)

	# Soil (visible from top)
	var soil = ColorRect.new()
	soil.size = Vector2(28, 10)
	soil.position = Vector2(-14, -2)
	soil.color = OfficePalette.SOIL_DARK
	plant.add_child(soil)

	# Leaves spreading out from center (top-down view)
	var leaf1 = ColorRect.new()
	leaf1.size = Vector2(24, 10)
	leaf1.position = Vector2(-22, -12)
	leaf1.color = OfficePalette.LEAF_GREEN_DARK
	leaf1.rotation = -0.3
	plant.add_child(leaf1)

	var leaf2 = ColorRect.new()
	leaf2.size = Vector2(26, 10)
	leaf2.position = Vector2(-8, -22)
	leaf2.color = OfficePalette.LEAF_GREEN_LIGHT
	leaf2.rotation = 0.2
	plant.add_child(leaf2)

	var leaf3 = ColorRect.new()
	leaf3.size = Vector2(22, 10)
	leaf3.position = Vector2(4, -8)
	leaf3.color = OfficePalette.LEAF_GREEN
	leaf3.rotation = 0.6
	plant.add_child(leaf3)

	var leaf4 = ColorRect.new()
	leaf4.size = Vector2(20, 8)
	leaf4.position = Vector2(-4, -16)
	leaf4.color = OfficePalette.LEAF_GREEN_LIGHT
	leaf4.rotation = -0.5
	plant.add_child(leaf4)

	return plant

static func create_filing_cabinet(draggable_script: Script) -> Node2D:
	var cabinet = draggable_script.new()
	cabinet.item_name = "filing_cabinet"
	cabinet.set_click_area(Rect2(-25, -30, 50, 70))

	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(44, 16)
	shadow.position = Vector2(-22, 30)
	shadow.color = OfficePalette.SHADOW
	cabinet.add_child(shadow)

	# Cabinet front face (darker - what we see from front)
	var body_front = ColorRect.new()
	body_front.size = Vector2(40, 45)
	body_front.position = Vector2(-20, -15)
	body_front.color = OfficePalette.METAL_GRAY_DARK
	cabinet.add_child(body_front)

	# Cabinet top surface (lighter - angled view shows top)
	var body_top = ColorRect.new()
	body_top.size = Vector2(40, 12)
	body_top.position = Vector2(-20, -27)
	body_top.color = OfficePalette.METAL_GRAY_LIGHT
	cabinet.add_child(body_top)

	# Drawers (2 visible from this angle)
	for i in range(2):
		var drawer = ColorRect.new()
		drawer.size = Vector2(36, 18)
		drawer.position = Vector2(-18, -12 + i * 22)
		drawer.color = OfficePalette.METAL_GRAY
		cabinet.add_child(drawer)

		# Drawer handle
		var handle = ColorRect.new()
		handle.size = Vector2(14, 3)
		handle.position = Vector2(-7, -6 + i * 22)
		handle.color = OfficePalette.METAL_HANDLE
		cabinet.add_child(handle)

	return cabinet

static func create_shredder(draggable_script: Script) -> Node2D:
	var shredder = draggable_script.new()
	shredder.item_name = "shredder"
	shredder.set_click_area(Rect2(-30, -25, 60, 60))

	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(52, 16)
	shadow.position = Vector2(-26, 28)
	shadow.color = OfficePalette.SHADOW
	shredder.add_child(shadow)

	# Shredder bin front (darker)
	var bin_front = ColorRect.new()
	bin_front.size = Vector2(48, 24)
	bin_front.position = Vector2(-24, 4)
	bin_front.color = OfficePalette.SHREDDER_BIN
	shredder.add_child(bin_front)

	# Shredder main body front
	var body_front = ColorRect.new()
	body_front.size = Vector2(48, 20)
	body_front.position = Vector2(-24, -16)
	body_front.color = OfficePalette.SHREDDER_BODY
	shredder.add_child(body_front)

	# Shredder top surface (lighter - shows the paper slot)
	var body_top = ColorRect.new()
	body_top.size = Vector2(48, 12)
	body_top.position = Vector2(-24, -28)
	body_top.color = OfficePalette.SHREDDER_TOP
	shredder.add_child(body_top)

	# Paper slot on top (dark opening)
	var slot = ColorRect.new()
	slot.size = Vector2(36, 6)
	slot.position = Vector2(-18, -26)
	slot.color = OfficePalette.SHREDDER_SLOT
	shredder.add_child(slot)

	# Shredded paper visible in bin (from angled view)
	var shreds1 = ColorRect.new()
	shreds1.size = Vector2(40, 4)
	shreds1.position = Vector2(-20, 18)
	shreds1.color = OfficePalette.SHREDDED_PAPER
	shredder.add_child(shreds1)

	var shreds2 = ColorRect.new()
	shreds2.size = Vector2(36, 3)
	shreds2.position = Vector2(-18, 14)
	shreds2.color = OfficePalette.SHREDDED_PAPER_DARK
	shredder.add_child(shreds2)

	# Power light (green LED on top)
	var led = ColorRect.new()
	led.size = Vector2(5, 5)
	led.position = Vector2(16, -24)
	led.color = OfficePalette.STATUS_LED_GREEN_BRIGHT
	shredder.add_child(led)

	return shredder

static func create_meeting_table() -> Node2D:
	var table = Node2D.new()
	table.name = "MeetingTable"

	# Shadow under table
	var shadow = ColorRect.new()
	shadow.size = Vector2(130, 20)
	shadow.position = Vector2(-65, 25)
	shadow.color = OfficePalette.SHADOW
	table.add_child(shadow)

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
		table.add_child(leg)

	# Table edge (front face - darker)
	var edge_front = ColorRect.new()
	edge_front.size = Vector2(120, 8)
	edge_front.position = Vector2(-60, 22)
	edge_front.color = OfficePalette.MEETING_TABLE_EDGE
	table.add_child(edge_front)

	# Table surface (main top - lighter wood)
	var surface = ColorRect.new()
	surface.size = Vector2(120, 50)
	surface.position = Vector2(-60, -28)
	surface.color = OfficePalette.MEETING_TABLE_SURFACE
	table.add_child(surface)

	# Surface edge detail (lighter strip at top for 3D effect)
	var edge_top = ColorRect.new()
	edge_top.size = Vector2(120, 4)
	edge_top.position = Vector2(-60, -28)
	edge_top.color = OfficePalette.MEETING_TABLE_SURFACE.lightened(0.1)
	table.add_child(edge_top)

	# Center decoration (subtle inlay pattern)
	var inlay = ColorRect.new()
	inlay.size = Vector2(80, 30)
	inlay.position = Vector2(-40, -18)
	inlay.color = OfficePalette.MEETING_TABLE_SURFACE.darkened(0.05)
	table.add_child(inlay)

	return table

static func create_door(parent: Node2D, pos: Vector2) -> Node2D:
	var door = Node2D.new()
	door.position = pos
	door.z_index = OfficeConstants.Z_DOOR
	parent.add_child(door)

	# Door frame - starts at seam, extends into wall
	var frame = ColorRect.new()
	frame.size = Vector2(60, 50)
	frame.position = Vector2(-30, 0)
	frame.color = OfficePalette.WOOD_FRAME
	door.add_child(frame)

	# Door body (dark opening - hallway beyond)
	var body = ColorRect.new()
	body.size = Vector2(52, 44)
	body.position = Vector2(-26, 2)
	body.color = Color(0.12, 0.10, 0.08)  # Dark hallway
	door.add_child(body)

	# Door panels (to show it's open/ajar)
	var panel_left = ColorRect.new()
	panel_left.size = Vector2(6, 42)
	panel_left.position = Vector2(-26, 3)
	panel_left.color = OfficePalette.WOOD_DOOR
	door.add_child(panel_left)

	var panel_right = ColorRect.new()
	panel_right.size = Vector2(6, 42)
	panel_right.position = Vector2(20, 3)
	panel_right.color = OfficePalette.WOOD_DOOR
	door.add_child(panel_right)

	# "EXIT" sign - in the wall below door opening, rotated 180 for top-down perspective
	var sign_container = Node2D.new()
	sign_container.position = Vector2(0, 52)
	sign_container.rotation = PI  # Rotate 180 degrees
	door.add_child(sign_container)

	var sign_bg = ColorRect.new()
	sign_bg.size = Vector2(36, 10)
	sign_bg.position = Vector2(-18, -5)
	sign_bg.color = OfficePalette.EXIT_SIGN_BG
	sign_container.add_child(sign_bg)

	var exit_label = Label.new()
	exit_label.text = "EXIT"
	exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_label.position = Vector2(-18, -6)
	exit_label.size = Vector2(36, 10)
	exit_label.add_theme_font_size_override("font_size", 8)
	exit_label.add_theme_color_override("font_color", OfficePalette.EXIT_SIGN_TEXT)
	sign_container.add_child(exit_label)

	return door

static func create_window(parent: Node2D, wx: float, window_clouds: Array) -> Node2D:
	var window = Node2D.new()
	window.position = Vector2(wx, 8)
	parent.add_child(window)

	# Sky background (bright blue to be clearly visible)
	var sky = ColorRect.new()
	sky.size = Vector2(OfficeConstants.WINDOW_WIDTH, OfficeConstants.WINDOW_HEIGHT)
	sky.position = Vector2(-OfficeConstants.WINDOW_WIDTH / 2, 0)
	sky.color = OfficePalette.SKY_BLUE
	sky.z_index = OfficeConstants.Z_WINDOW_SKY
	window.add_child(sky)

	# Clouds (multiple per window, animated)
	for c in range(2):
		var cloud = ColorRect.new()
		var cloud_width = 15 + randi() % 15
		cloud.size = Vector2(cloud_width, 4 + randi() % 4)
		var start_x = -35 + randi() % 50
		cloud.position = Vector2(start_x, 4 + c * 12 + randi() % 6)
		cloud.color = OfficePalette.CLOUD_WHITE
		cloud.z_index = OfficeConstants.Z_WINDOW_CLOUD
		window.add_child(cloud)
		# Track for animation
		window_clouds.append({
			"cloud": cloud,
			"window_x": wx,
			"start_x": start_x,
			"speed": OfficeConstants.CLOUD_SPEED_MIN + randf() * (OfficeConstants.CLOUD_SPEED_MAX - OfficeConstants.CLOUD_SPEED_MIN)
		})

	# Trees/bushes at bottom
	var tree = ColorRect.new()
	tree.size = Vector2(15, 12)
	tree.position = Vector2(-25 + randi() % 30, 30)
	tree.color = OfficePalette.TREE_GREEN
	tree.z_index = OfficeConstants.Z_WINDOW_CLOUD
	window.add_child(tree)

	# Window frame (on top of everything)
	var frame_thickness = OfficeConstants.WINDOW_FRAME_THICKNESS

	var frame_top = ColorRect.new()
	frame_top.size = Vector2(OfficeConstants.WINDOW_WIDTH + frame_thickness, frame_thickness)
	frame_top.position = Vector2(-OfficeConstants.WINDOW_WIDTH / 2 - 2, -2)
	frame_top.color = OfficePalette.WOOD_FRAME
	frame_top.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(frame_top)

	var frame_bottom = ColorRect.new()
	frame_bottom.size = Vector2(OfficeConstants.WINDOW_WIDTH + frame_thickness, frame_thickness)
	frame_bottom.position = Vector2(-OfficeConstants.WINDOW_WIDTH / 2 - 2, OfficeConstants.WINDOW_HEIGHT)
	frame_bottom.color = OfficePalette.WOOD_FRAME
	frame_bottom.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(frame_bottom)

	var frame_left = ColorRect.new()
	frame_left.size = Vector2(frame_thickness, OfficeConstants.WINDOW_HEIGHT + 6)
	frame_left.position = Vector2(-OfficeConstants.WINDOW_WIDTH / 2 - 2, -2)
	frame_left.color = OfficePalette.WOOD_FRAME
	frame_left.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(frame_left)

	var frame_right = ColorRect.new()
	frame_right.size = Vector2(frame_thickness, OfficeConstants.WINDOW_HEIGHT + 6)
	frame_right.position = Vector2(OfficeConstants.WINDOW_WIDTH / 2 - 2, -2)
	frame_right.color = OfficePalette.WOOD_FRAME
	frame_right.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(frame_right)

	# Window divider
	var divider = ColorRect.new()
	divider.size = Vector2(2, OfficeConstants.WINDOW_HEIGHT)
	divider.position = Vector2(-1, 0)
	divider.color = OfficePalette.WOOD_FRAME
	divider.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(divider)

	# Wall masking pieces on each side to hide cloud overflow
	var mask_left = ColorRect.new()
	mask_left.size = Vector2(50, 70)
	mask_left.position = Vector2(-92, -10)
	mask_left.color = OfficePalette.WALL_BEIGE
	mask_left.z_index = OfficeConstants.Z_WINDOW_MASK
	window.add_child(mask_left)

	var mask_right = ColorRect.new()
	mask_right.size = Vector2(50, 70)
	mask_right.position = Vector2(42, -10)
	mask_right.color = OfficePalette.WALL_BEIGE
	mask_right.z_index = OfficeConstants.Z_WINDOW_MASK
	window.add_child(mask_right)

	return window

static func create_taskboard(draggable_script: Script) -> Node2D:
	var taskboard = draggable_script.new()
	taskboard.item_name = "taskboard"
	taskboard.set_click_area(Rect2(0, 0, 170, 130))
	taskboard.z_index = OfficeConstants.Z_TASKBOARD
	# Taskboard has different drag bounds (can be placed along top wall)
	taskboard.drag_bounds_min = Vector2(30, 10)
	taskboard.drag_bounds_max = Vector2(1100, 120)

	# Whiteboard frame (silver/aluminum)
	var frame = ColorRect.new()
	frame.size = Vector2(170, 130)
	frame.position = Vector2(0, 0)
	frame.color = Color(0.75, 0.75, 0.78)
	taskboard.add_child(frame)

	# Whiteboard surface
	var surface = ColorRect.new()
	surface.size = Vector2(162, 122)
	surface.position = Vector2(4, 4)
	surface.color = OfficePalette.TASKBOARD_BG
	taskboard.add_child(surface)

	# Header text (handwritten style)
	var header = Label.new()
	header.text = "Sessions"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(4, 6)
	header.size = Vector2(162, 18)
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.2, 0.2, 0.6))  # Blue marker
	taskboard.add_child(header)

	# Underline
	var underline = ColorRect.new()
	underline.size = Vector2(80, 2)
	underline.position = Vector2(45, 22)
	underline.color = Color(0.2, 0.2, 0.6)
	taskboard.add_child(underline)

	return taskboard

static func create_reset_button() -> Button:
	var button = Button.new()
	button.text = "Reset Layout"
	button.position = Vector2(1150, 695)
	button.size = Vector2(120, 22)
	button.add_theme_font_size_override("font_size", 11)
	return button

static func create_title_sign(parent: Node2D) -> void:
	# Title sign - wooden frame style with serif font
	var sign_frame = ColorRect.new()
	sign_frame.size = Vector2(164, 34)
	sign_frame.position = Vector2(558, 13)
	sign_frame.color = OfficePalette.WOOD_FRAME
	parent.add_child(sign_frame)

	var sign_bg = ColorRect.new()
	sign_bg.size = Vector2(160, 30)
	sign_bg.position = Vector2(560, 15)
	sign_bg.color = Color(0.95, 0.92, 0.85)  # Cream background
	parent.add_child(sign_bg)

	var title = Label.new()
	title.text = "Claude Office"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(560, 15)
	title.size = Vector2(160, 30)
	# Use serif font
	var serif_font = SystemFont.new()
	serif_font.font_names = ["DejaVu Serif", "Liberation Serif", "Times New Roman", "Serif"]
	title.add_theme_font_override("font", serif_font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.35, 0.30, 0.25))
	parent.add_child(title)

static func create_floor(parent: Node2D) -> void:
	# Office floor (carpet tiles)
	var floor_bg = ColorRect.new()
	floor_bg.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	floor_bg.position = Vector2(0, 0)
	floor_bg.color = OfficePalette.FLOOR_CARPET
	floor_bg.z_index = OfficeConstants.Z_FLOOR
	parent.add_child(floor_bg)

	# Add some carpet tile lines for texture
	for i in range(0, int(OfficeConstants.SCREEN_WIDTH), 80):
		var vline = ColorRect.new()
		vline.size = Vector2(1, OfficeConstants.SCREEN_HEIGHT)
		vline.position = Vector2(i, 0)
		vline.color = Color(OfficePalette.FLOOR_LINE_DARK.r, OfficePalette.FLOOR_LINE_DARK.g, OfficePalette.FLOOR_LINE_DARK.b, 0.3)
		vline.z_index = OfficeConstants.Z_FLOOR_DETAIL
		parent.add_child(vline)
	for i in range(0, int(OfficeConstants.SCREEN_HEIGHT), 80):
		var hline = ColorRect.new()
		hline.size = Vector2(OfficeConstants.SCREEN_WIDTH, 1)
		hline.position = Vector2(0, i)
		hline.color = Color(OfficePalette.FLOOR_LINE_DARK.r, OfficePalette.FLOOR_LINE_DARK.g, OfficePalette.FLOOR_LINE_DARK.b, 0.3)
		hline.z_index = OfficeConstants.Z_FLOOR_DETAIL
		parent.add_child(hline)

static func create_walls(parent: Node2D) -> void:
	# Back wall (top) - extends off sides, meets seam at y=68
	var wall = ColorRect.new()
	wall.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.BACK_WALL_HEIGHT)
	wall.position = Vector2(0, 0)
	wall.color = OfficePalette.WALL_BEIGE
	wall.z_index = OfficeConstants.Z_WALL
	parent.add_child(wall)

	# Back wall-to-floor seam - dark border at bottom of back wall
	var back_wall_seam = ColorRect.new()
	back_wall_seam.size = Vector2(OfficeConstants.SCREEN_WIDTH, 8)
	back_wall_seam.position = Vector2(0, OfficeConstants.BACK_WALL_SEAM_Y)
	back_wall_seam.color = OfficePalette.WALL_SEAM_DARK
	back_wall_seam.z_index = OfficeConstants.Z_SEAM
	parent.add_child(back_wall_seam)

	# Wall-to-floor seam - dark border showing the edge where wall meets floor
	var wall_floor_seam = ColorRect.new()
	wall_floor_seam.size = Vector2(OfficeConstants.SCREEN_WIDTH, 8)
	wall_floor_seam.position = Vector2(0, OfficeConstants.BOTTOM_WALL_Y)
	wall_floor_seam.color = OfficePalette.WALL_SEAM_DARK
	wall_floor_seam.z_index = OfficeConstants.Z_SEAM
	parent.add_child(wall_floor_seam)

	# Bottom wall - same color as back wall
	var bottom_wall = ColorRect.new()
	bottom_wall.size = Vector2(OfficeConstants.SCREEN_WIDTH, 50)
	bottom_wall.position = Vector2(0, 640)
	bottom_wall.color = OfficePalette.WALL_BEIGE
	bottom_wall.z_index = OfficeConstants.Z_FURNITURE
	parent.add_child(bottom_wall)

static func create_status_bar(parent: Node2D) -> Label:
	var status_bg = ColorRect.new()
	status_bg.size = Vector2(OfficeConstants.SCREEN_WIDTH, 30)
	status_bg.position = Vector2(0, 690)
	status_bg.color = Color(0.25, 0.25, 0.28)
	parent.add_child(status_bg)

	var status_label = Label.new()
	status_label.text = "Waiting for events..."
	status_label.position = Vector2(20, 695)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_MUTED)
	parent.add_child(status_label)

	return status_label
