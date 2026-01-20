extends Node2D
class_name Desk

signal position_changed(desk: Desk, new_position: Vector2)

var is_occupied: bool = false

# Visual nodes
var desk_rect: ColorRect
var monitor: ColorRect
var screen: ColorRect
var screen_glow: ColorRect
var status_indicator: ColorRect
var personal_items: Node2D  # Container for worker's personal items

# Tool display on monitor
var tool_label: Label

# Dragging support (only when empty)
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var click_area: Rect2 = Rect2(-45, -35, 90, 85)  # Area covering desk and monitor
const DRAG_BOUNDS_MIN: Vector2 = Vector2(50, 100)
const DRAG_BOUNDS_MAX: Vector2 = Vector2(1230, 580)

# For collision checking
var navigation_grid: NavigationGrid = null
var office_manager: Node = null  # Set by OfficeManager to check popup state

func _ready() -> void:
	_create_visuals()
	# Set z_index based on Y position - desks lower on screen render in front
	z_index = int(position.y)

func _create_visuals() -> void:
	# Shallower desk - layout: [Item] [Keyboard] [Mouse]
	var desk_width = OfficeConstants.DESK_WIDTH
	var desk_depth = OfficeConstants.DESK_DEPTH

	# Shadow under desk
	var shadow = ColorRect.new()
	shadow.size = Vector2(desk_width + 5, desk_depth + 5)
	shadow.position = Vector2(-desk_width/2 + 3, 3)
	shadow.color = OfficePalette.SHADOW
	shadow.z_index = -1
	add_child(shadow)

	# Desk surface - gruvbox light
	desk_rect = ColorRect.new()
	desk_rect.size = Vector2(desk_width, desk_depth)
	desk_rect.position = Vector2(-desk_width/2, 0)
	desk_rect.color = OfficePalette.DESK_SURFACE
	add_child(desk_rect)

	# Desk front edge (3D depth)
	var desk_front = ColorRect.new()
	desk_front.size = Vector2(desk_width, 5)
	desk_front.position = Vector2(-desk_width/2, desk_depth - 2)
	desk_front.color = OfficePalette.DESK_EDGE
	add_child(desk_front)

	# Monitor (smaller, at back of desk)
	var monitor_stand = ColorRect.new()
	monitor_stand.size = Vector2(16, 6)
	monitor_stand.position = Vector2(-8, -4)
	monitor_stand.color = OfficePalette.MONITOR_STAND
	add_child(monitor_stand)

	monitor = ColorRect.new()
	monitor.size = Vector2(40, 30)
	monitor.position = Vector2(-20, -32)
	monitor.color = OfficePalette.MONITOR_FRAME
	add_child(monitor)

	# Monitor screen (dark when off)
	screen = ColorRect.new()
	screen.size = Vector2(36, 24)
	screen.position = Vector2(-18, -30)
	screen.color = OfficePalette.MONITOR_SCREEN_OFF
	add_child(screen)

	# Screen glow (only visible when on)
	screen_glow = ColorRect.new()
	screen_glow.size = Vector2(34, 22)
	screen_glow.position = Vector2(-17, -29)
	screen_glow.color = OfficePalette.MONITOR_SCREEN_OFF
	add_child(screen_glow)

	# Layout on desk: [Personal Item spot] [Keyboard] [Mouse]
	# Personal items container (left side of desk)
	personal_items = Node2D.new()
	personal_items.name = "PersonalItems"
	personal_items.position = Vector2(-30, 8)  # Left side
	add_child(personal_items)

	# Keyboard (center)
	var keyboard = ColorRect.new()
	keyboard.size = Vector2(28, 10)
	keyboard.position = Vector2(-14, 10)
	keyboard.color = OfficePalette.KEYBOARD_DARK
	add_child(keyboard)

	var keys = ColorRect.new()
	keys.size = Vector2(24, 6)
	keys.position = Vector2(-12, 12)
	keys.color = OfficePalette.KEYBOARD_KEYS
	add_child(keys)

	# Mouse (right side)
	var mouse = ColorRect.new()
	mouse.size = Vector2(8, 12)
	mouse.position = Vector2(22, 9)
	mouse.color = OfficePalette.KEYBOARD_DARK
	add_child(mouse)

	var mouse_highlight = ColorRect.new()
	mouse_highlight.size = Vector2(6, 3)
	mouse_highlight.position = Vector2(23, 10)
	mouse_highlight.color = OfficePalette.MOUSE_HIGHLIGHT
	add_child(mouse_highlight)

	# Status indicator (power light on monitor - red when unoccupied)
	status_indicator = ColorRect.new()
	status_indicator.size = Vector2(4, 4)
	status_indicator.position = Vector2(12, -8)
	status_indicator.color = OfficePalette.STATUS_LED_RED
	add_child(status_indicator)

	# Tool display label (on monitor)
	tool_label = Label.new()
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tool_label.position = Vector2(-18, -30)
	tool_label.size = Vector2(36, 24)
	tool_label.add_theme_font_size_override("font_size", 14)
	tool_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GREEN_BRIGHT)
	tool_label.visible = false
	tool_label.z_index = 1
	add_child(tool_label)

func _process(_delta: float) -> void:
	# Update z_index while dragging
	if is_dragging:
		z_index = int(position.y)

func _input(event: InputEvent) -> void:
	# Only allow dragging when desk is empty (not occupied)
	if is_occupied:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Don't start dragging if a popup is open
				if office_manager and office_manager.has_method("is_any_popup_open") and office_manager.is_any_popup_open():
					return
				var local_pos = get_local_mouse_position()
				if click_area.has_point(local_pos):
					is_dragging = true
					drag_offset = position - get_global_mouse_position()
			else:
				if is_dragging:
					is_dragging = false
					# Snap to grid
					var snapped_pos = _snap_to_grid(position)

					# Check for valid placement (no overlap with other objects)
					if navigation_grid:
						var desk_id = "desk_%d" % get_instance_id()
						var test_rect = _get_obstacle_rect(snapped_pos)
						if not navigation_grid.can_place_obstacle(test_rect, desk_id):
							# Find nearest valid position
							snapped_pos = navigation_grid.find_nearest_valid_position(test_rect, desk_id)

					position = snapped_pos
					z_index = int(position.y)
					position_changed.emit(self, position)

	elif event is InputEventMouseMotion and is_dragging:
		var new_pos = get_global_mouse_position() + drag_offset
		new_pos.x = clamp(new_pos.x, DRAG_BOUNDS_MIN.x, DRAG_BOUNDS_MAX.x)
		new_pos.y = clamp(new_pos.y, DRAG_BOUNDS_MIN.y, DRAG_BOUNDS_MAX.y)
		position = new_pos

func _get_obstacle_rect(pos: Vector2) -> Rect2:
	# Desk obstacle includes the desk surface and work area in front
	return Rect2(
		pos.x - OfficeConstants.DESK_WIDTH / 2,
		pos.y,
		OfficeConstants.DESK_WIDTH,
		OfficeConstants.DESK_DEPTH + OfficeConstants.WORK_POSITION_OFFSET
	)

func _snap_to_grid(pos: Vector2) -> Vector2:
	return OfficeConstants.snap_to_grid(pos)

func show_tool(tool_text: String, tool_color: Color) -> void:
	if tool_label:
		tool_label.text = tool_text
		tool_label.add_theme_color_override("font_color", tool_color)
		tool_label.visible = true
		tool_label.modulate.a = 1.0
		# No timer - persists until changed

func hide_tool() -> void:
	if tool_label:
		tool_label.visible = false

func get_work_position() -> Vector2:
	# Position where agent should stand (in front of desk)
	return global_position + Vector2(0, OfficeConstants.WORK_POSITION_OFFSET)

func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	# Only update indicator, not monitor - monitor is controlled by set_monitor_active
	if occupied:
		if status_indicator:
			status_indicator.color = OfficePalette.GRUVBOX_YELLOW  # Yellow/amber when reserved but worker not yet arrived
	else:
		if status_indicator:
			status_indicator.color = OfficePalette.STATUS_LED_RED  # Red when unoccupied
		# Turn off monitor and clear items when desk is vacated
		set_monitor_active(false)
		clear_personal_items()

func set_monitor_active(active: bool) -> void:
	if active:
		# Worker arrived: green indicator, lit screen
		if status_indicator:
			status_indicator.color = OfficePalette.STATUS_LED_GREEN  # Green
		if screen:
			screen.color = OfficePalette.MONITOR_SCREEN_ON
		if screen_glow:
			screen_glow.color = OfficePalette.MONITOR_SCREEN_GLOW
	else:
		# Dark screen
		if screen:
			screen.color = OfficePalette.MONITOR_SCREEN_OFF
		if screen_glow:
			screen_glow.color = OfficePalette.MONITOR_SCREEN_OFF
		if tool_label:
			tool_label.visible = false

func set_monitor_waiting(waiting: bool) -> void:
	if waiting:
		# Red screen - waiting for user input
		if status_indicator:
			status_indicator.color = OfficePalette.STATUS_LED_RED
		if screen:
			screen.color = OfficePalette.MONITOR_SCREEN_WAITING
		if screen_glow:
			screen_glow.color = OfficePalette.MONITOR_SCREEN_WAITING_GLOW
	else:
		# Return to normal green
		if status_indicator:
			status_indicator.color = OfficePalette.STATUS_LED_GREEN
		if screen:
			screen.color = OfficePalette.MONITOR_SCREEN_ON
		if screen_glow:
			screen_glow.color = OfficePalette.MONITOR_SCREEN_GLOW

func is_available() -> bool:
	return not is_occupied

func add_personal_item(item: Node2D) -> void:
	if personal_items:
		personal_items.add_child(item)

func clear_personal_items() -> void:
	if personal_items:
		for child in personal_items.get_children():
			child.queue_free()
