class_name OfficeVisualFactory

# Factory class for creating office furniture and decorations
# Extracts visual creation logic from OfficeManager for better separation of concerns

const WallClockScript = preload("res://scripts/WallClock.gd")
const TemperatureDisplayScript = preload("res://scripts/TemperatureDisplay.gd")

# Note: Furniture creation is now handled by FurnitureRegistry and individual furniture classes
# in the furniture/ directory. Old factory methods have been removed.

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
	body.color = OfficePalette.DOOR_HALLWAY
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

static func create_window_frame(parent: Node2D, wx: float) -> Node2D:
	# Window frame only - sky/clouds/foliage are now separate full-width layers
	var window = Node2D.new()
	window.position = Vector2(wx, 8)
	parent.add_child(window)

	var frame_thickness = OfficeConstants.WINDOW_FRAME_THICKNESS

	# Top frame
	var frame_top = ColorRect.new()
	frame_top.size = Vector2(OfficeConstants.WINDOW_WIDTH + frame_thickness, frame_thickness)
	frame_top.position = Vector2(-OfficeConstants.WINDOW_WIDTH / 2 - 2, -2)
	frame_top.color = OfficePalette.WOOD_FRAME
	frame_top.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(frame_top)

	# Bottom frame
	var frame_bottom = ColorRect.new()
	frame_bottom.size = Vector2(OfficeConstants.WINDOW_WIDTH + frame_thickness, frame_thickness)
	frame_bottom.position = Vector2(-OfficeConstants.WINDOW_WIDTH / 2 - 2, OfficeConstants.WINDOW_HEIGHT)
	frame_bottom.color = OfficePalette.WOOD_FRAME
	frame_bottom.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(frame_bottom)

	# Left frame
	var frame_left = ColorRect.new()
	frame_left.size = Vector2(frame_thickness, OfficeConstants.WINDOW_HEIGHT + 6)
	frame_left.position = Vector2(-OfficeConstants.WINDOW_WIDTH / 2 - 2, -2)
	frame_left.color = OfficePalette.WOOD_FRAME
	frame_left.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(frame_left)

	# Right frame
	var frame_right = ColorRect.new()
	frame_right.size = Vector2(frame_thickness, OfficeConstants.WINDOW_HEIGHT + 6)
	frame_right.position = Vector2(OfficeConstants.WINDOW_WIDTH / 2 - 2, -2)
	frame_right.color = OfficePalette.WOOD_FRAME
	frame_right.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(frame_right)

	# Center divider
	var divider = ColorRect.new()
	divider.size = Vector2(2, OfficeConstants.WINDOW_HEIGHT)
	divider.position = Vector2(-1, 0)
	divider.color = OfficePalette.WOOD_FRAME
	divider.z_index = OfficeConstants.Z_WINDOW_FRAME
	window.add_child(divider)

	return window

static func create_reset_button() -> Button:
	var button = Button.new()
	button.text = "Reset Layout"
	button.position = Vector2(1150, 695)
	button.size = Vector2(120, 22)
	button.add_theme_font_size_override("font_size", 11)
	return button

static func create_stats_button() -> Button:
	var button = Button.new()
	button.text = "Stats"
	button.position = Vector2(1080, 695)
	button.size = Vector2(60, 22)
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
	sign_bg.color = OfficePalette.GRUVBOX_LIGHT
	parent.add_child(sign_bg)

	var title = Label.new()
	title.text = "Inference Inc."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(560, 15)
	title.size = Vector2(160, 30)
	# Use serif font
	var serif_font = SystemFont.new()
	serif_font.font_names = ["DejaVu Serif", "Liberation Serif", "Times New Roman", "Serif"]
	title.add_theme_font_override("font", serif_font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
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

# =============================================================================
# SKY AND BACKGROUND LAYERS (behind wall, visible through window holes)
# =============================================================================

static func create_sky_layer(parent: Node2D, window_skies: Array) -> Node2D:
	var sky_layer = Node2D.new()
	sky_layer.name = "SkyLayer"
	sky_layer.z_index = OfficeConstants.Z_SKY
	parent.add_child(sky_layer)

	# Full-width sky backdrop (behind wall, visible through window holes)
	var sky = ColorRect.new()
	sky.name = "SkyBackground"
	sky.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.BACK_WALL_HEIGHT)
	sky.position = Vector2(0, 0)
	sky.color = OfficePalette.SKY_BLUE
	sky_layer.add_child(sky)

	# Track for day/night cycle
	window_skies.append(sky)

	return sky_layer

static func create_celestial_layer(parent: Node2D) -> Node2D:
	var celestial = Node2D.new()
	celestial.name = "CelestialLayer"
	celestial.z_index = OfficeConstants.Z_CELESTIAL
	parent.add_child(celestial)

	# Sun (shown during day, positioned based on time)
	var sun = ColorRect.new()
	sun.name = "Sun"
	sun.size = Vector2(20, 20)
	sun.position = Vector2(200, 15)  # Default position
	sun.color = OfficePalette.SUN_YELLOW
	celestial.add_child(sun)

	# Moon (hidden during day)
	var moon = ColorRect.new()
	moon.name = "Moon"
	moon.size = Vector2(16, 16)
	moon.position = Vector2(1000, 20)
	moon.color = OfficePalette.MOON_SILVER
	moon.visible = false  # Hidden by default (day)
	celestial.add_child(moon)

	return celestial

static func create_cloud_layer(parent: Node2D, window_clouds: Array) -> Node2D:
	var cloud_layer = Node2D.new()
	cloud_layer.name = "CloudLayer"
	cloud_layer.z_index = OfficeConstants.Z_CLOUDS
	parent.add_child(cloud_layer)

	# Full-width clouds (8 clouds spanning the entire sky width)
	for i in range(8):
		var cloud = ColorRect.new()
		var cloud_width = 20 + randi() % 30
		var cloud_height = 5 + randi() % 6
		cloud.size = Vector2(cloud_width, cloud_height)
		cloud.position = Vector2(randi() % 1280, 8 + randi() % 40)
		cloud.color = OfficePalette.CLOUD_WHITE
		cloud_layer.add_child(cloud)

		# Track for animation (now wraps at screen edges, not window edges)
		window_clouds.append({
			"cloud": cloud,
			"speed": OfficeConstants.CLOUD_SPEED_MIN + randf() * (OfficeConstants.CLOUD_SPEED_MAX - OfficeConstants.CLOUD_SPEED_MIN)
		})

	return cloud_layer

static func create_foliage_layer(parent: Node2D) -> Node2D:
	var foliage = Node2D.new()
	foliage.name = "FoliageLayer"
	foliage.z_index = OfficeConstants.Z_FOLIAGE
	parent.add_child(foliage)

	# Static tree silhouettes at bottom of sky area (visible through windows)
	# Create a row of trees across the full width
	var tree_positions = [50, 150, 280, 420, 550, 700, 850, 980, 1100, 1200]
	for tx in tree_positions:
		var tree = ColorRect.new()
		var tree_width = 20 + randi() % 25
		var tree_height = 15 + randi() % 10
		tree.size = Vector2(tree_width, tree_height)
		tree.position = Vector2(tx, 55 - tree_height)  # Bottom of sky area
		tree.color = OfficePalette.TREE_GREEN
		foliage.add_child(tree)

	return foliage

# =============================================================================
# WALLS (with transparent holes for windows)
# =============================================================================

static func create_walls(parent: Node2D, window_positions: Array = [140, 380, 900, 1140]) -> void:
	# Back wall segments (with gaps for windows)
	# Windows are 80px wide, positioned by center X
	var wall_y = 0
	var wall_height = OfficeConstants.BACK_WALL_HEIGHT
	var window_width = OfficeConstants.WINDOW_WIDTH
	var half_window = window_width / 2

	# Calculate wall segments between windows
	var segments: Array = []
	var prev_end = 0

	for wx in window_positions:
		var window_start = wx - half_window
		var window_end = wx + half_window
		if window_start > prev_end:
			segments.append({"x": prev_end, "width": window_start - prev_end})
		prev_end = window_end

	# Final segment after last window
	if prev_end < OfficeConstants.SCREEN_WIDTH:
		segments.append({"x": prev_end, "width": OfficeConstants.SCREEN_WIDTH - prev_end})

	# Create wall pieces (horizontal segments between windows)
	for seg in segments:
		var wall_piece = ColorRect.new()
		wall_piece.size = Vector2(seg.width, wall_height)
		wall_piece.position = Vector2(seg.x, wall_y)
		wall_piece.color = OfficePalette.WALL_BEIGE
		wall_piece.z_index = OfficeConstants.Z_WALL
		parent.add_child(wall_piece)

	# Add wall strips above and below each window
	# Window frames start at Y=8 and are WINDOW_HEIGHT tall (44px)
	# Wall is 76px tall, so we need strips at top (0-6) and bottom (54-76)
	var window_top_y = 6  # Where window frame starts
	var window_bottom_y = window_top_y + OfficeConstants.WINDOW_HEIGHT + 4  # Where window frame ends

	for wx in window_positions:
		# Wall strip above window
		var top_strip = ColorRect.new()
		top_strip.size = Vector2(window_width + 8, window_top_y)
		top_strip.position = Vector2(wx - half_window - 4, 0)
		top_strip.color = OfficePalette.WALL_BEIGE
		top_strip.z_index = OfficeConstants.Z_WALL
		parent.add_child(top_strip)

		# Wall strip below window
		var bottom_strip = ColorRect.new()
		bottom_strip.size = Vector2(window_width + 8, wall_height - window_bottom_y)
		bottom_strip.position = Vector2(wx - half_window - 4, window_bottom_y)
		bottom_strip.color = OfficePalette.WALL_BEIGE
		bottom_strip.z_index = OfficeConstants.Z_WALL
		parent.add_child(bottom_strip)

	# Back wall-to-floor seam - dark border at bottom of back wall
	var back_wall_seam = ColorRect.new()
	back_wall_seam.size = Vector2(OfficeConstants.SCREEN_WIDTH, 8)
	back_wall_seam.position = Vector2(0, OfficeConstants.BACK_WALL_SEAM_Y)
	back_wall_seam.color = OfficePalette.WALL_SEAM_DARK
	back_wall_seam.z_index = OfficeConstants.Z_WALL_SEAM
	parent.add_child(back_wall_seam)

	# Wall-to-floor seam - dark border showing the edge where wall meets floor
	var wall_floor_seam = ColorRect.new()
	wall_floor_seam.size = Vector2(OfficeConstants.SCREEN_WIDTH, 8)
	wall_floor_seam.position = Vector2(0, OfficeConstants.BOTTOM_WALL_Y)
	wall_floor_seam.color = OfficePalette.WALL_SEAM_DARK
	wall_floor_seam.z_index = OfficeConstants.Z_WALL_SEAM
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
	status_bg.color = OfficePalette.STATUS_BAR_BG
	parent.add_child(status_bg)

	var status_label = Label.new()
	status_label.text = "Waiting for events..."
	status_label.position = Vector2(20, 695)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_MUTED)
	parent.add_child(status_label)

	return status_label

static func create_vip_photo() -> VIPPhoto:
	var photo = VIPPhoto.new()
	photo.position = OfficeConstants.VIP_PHOTO_POSITION
	photo.z_index = OfficeConstants.Z_WALL_DECORATION
	return photo

static func create_roster_clipboard() -> RosterClipboard:
	var clipboard = RosterClipboard.new()
	clipboard.position = OfficeConstants.ROSTER_CLIPBOARD_POSITION
	clipboard.z_index = OfficeConstants.Z_WALL_DECORATION
	return clipboard

static func create_achievement_board() -> AchievementBoard:
	var board = AchievementBoard.new()
	board.position = OfficeConstants.ACHIEVEMENT_BOARD_POSITION
	board.z_index = OfficeConstants.Z_WALL_DECORATION
	return board

static func create_wall_clock() -> Node2D:
	var clock = WallClockScript.new()
	clock.z_index = OfficeConstants.Z_WALL_DECORATION
	return clock

static func create_temperature_display() -> Node2D:
	var display = TemperatureDisplayScript.new()
	display.z_index = OfficeConstants.Z_WALL_DECORATION
	return display

static func create_weather_system() -> WeatherSystem:
	var weather = WeatherSystem.new()
	weather.name = "WeatherSystem"
	return weather
