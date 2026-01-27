extends FurnitureBase
class_name FurnitureDesk

## Office desk - exclusive work station with monitor.
## Traits: terminal
## Special features: monitor state, tool display, personal items

# Visual nodes
var desk_rect: ColorRect
var monitor: ColorRect
var screen: ColorRect
var screen_glow: ColorRect
var status_indicator: ColorRect
var personal_items_container: Node2D
var tool_label: Label

# Monitor states
enum MonitorState { OFF, RESERVED, ACTIVE, WAITING }
var _monitor_state: MonitorState = MonitorState.OFF

func _init() -> void:
	furniture_type = "desk"
	traits = ["terminal"]
	capacity = 1
	obstacle_size = Vector2(
		OfficeConstants.DESK_WIDTH,
		OfficeConstants.DESK_DEPTH + OfficeConstants.WORK_POSITION_OFFSET
	)

	# Single work position in front of desk
	slots = [
		{"offset": Vector2(0, OfficeConstants.WORK_POSITION_OFFSET), "occupied_by": ""},
	]

func _ready() -> void:
	click_area = Rect2(-45, -35, 90, 85)
	drag_bounds_min = Vector2(50, 100)
	drag_bounds_max = Vector2(1230, 580)
	super._ready()

func _build_visuals() -> void:
	var desk_width = OfficeConstants.DESK_WIDTH
	var desk_depth = OfficeConstants.DESK_DEPTH

	# Shadow under desk
	var shadow = ColorRect.new()
	shadow.size = Vector2(desk_width + 5, desk_depth + 5)
	shadow.position = Vector2(-desk_width/2 + 3, 3)
	shadow.color = OfficePalette.SHADOW
	shadow.z_index = -1
	add_child(shadow)

	# Desk surface
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

	# Monitor stand
	var monitor_stand = ColorRect.new()
	monitor_stand.size = Vector2(16, 6)
	monitor_stand.position = Vector2(-8, -4)
	monitor_stand.color = OfficePalette.MONITOR_STAND
	add_child(monitor_stand)

	# Monitor frame
	monitor = ColorRect.new()
	monitor.size = Vector2(40, 30)
	monitor.position = Vector2(-20, -32)
	monitor.color = OfficePalette.MONITOR_FRAME
	add_child(monitor)

	# Monitor screen
	screen = ColorRect.new()
	screen.size = Vector2(36, 24)
	screen.position = Vector2(-18, -30)
	screen.color = OfficePalette.MONITOR_SCREEN_OFF
	add_child(screen)

	# Screen glow
	screen_glow = ColorRect.new()
	screen_glow.size = Vector2(34, 22)
	screen_glow.position = Vector2(-17, -29)
	screen_glow.color = OfficePalette.MONITOR_SCREEN_OFF
	add_child(screen_glow)

	# Personal items container
	personal_items_container = Node2D.new()
	personal_items_container.name = "PersonalItems"
	personal_items_container.position = Vector2(-30, 8)
	add_child(personal_items_container)

	# Keyboard
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

	# Mouse
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

	# Status indicator (LED on monitor)
	status_indicator = ColorRect.new()
	status_indicator.size = Vector2(4, 4)
	status_indicator.position = Vector2(12, -8)
	status_indicator.color = OfficePalette.STATUS_LED_RED
	add_child(status_indicator)

	# Tool display label
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

# Override drag to prevent when occupied AND emit correct signal type
func _input(event: InputEvent) -> void:
	# Only allow dragging when desk is empty
	if not is_empty():
		return

	# Handle drag end specially to emit (self, position) instead of (item_name, position)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_dragging:
			is_dragging = false
			var snapped_pos = _snap_to_grid(position)
			var original_snapped = snapped_pos

			if navigation_grid:
				var test_rect = _get_obstacle_rect(snapped_pos)
				if not navigation_grid.can_place_obstacle(test_rect, item_name):
					snapped_pos = navigation_grid.find_nearest_valid_position(test_rect, item_name)
					if OfficeConstants.DEBUG_EVENTS:
						print("[FurnitureDesk] %s: position adjusted from %s to %s (collision detected)" % [item_name, original_snapped, snapped_pos])

			position = snapped_pos
			_cleanup_drag_visuals()
			# Emit with self (FurnitureDesk) instead of item_name (String)
			# This matches what _on_desk_position_changed expects
			position_changed.emit(self, position)
			return

	super._input(event)

# Override obstacle rect calculation for desk+work area
func _get_obstacle_rect(pos: Vector2) -> Rect2:
	return Rect2(
		pos.x - OfficeConstants.DESK_WIDTH / 2,
		pos.y,
		OfficeConstants.DESK_WIDTH,
		OfficeConstants.DESK_DEPTH + OfficeConstants.WORK_POSITION_OFFSET
	)

# --- Hooks ---

func on_reserved(agent_id: String, slot_index: int) -> void:
	_set_monitor_state(MonitorState.RESERVED)

func on_agent_arrived(agent: Node, slot_index: int) -> void:
	_set_monitor_state(MonitorState.ACTIVE)

func on_agent_left(agent: Node, slot_index: int) -> void:
	_set_monitor_state(MonitorState.OFF)
	hide_tool()
	clear_personal_items()

func on_released(agent_id: String, slot_index: int) -> void:
	_set_monitor_state(MonitorState.OFF)
	hide_tool()
	clear_personal_items()

# --- Monitor State ---

func _set_monitor_state(state: MonitorState) -> void:
	_monitor_state = state
	match state:
		MonitorState.OFF:
			if status_indicator:
				status_indicator.color = OfficePalette.STATUS_LED_RED
			if screen:
				screen.color = OfficePalette.MONITOR_SCREEN_OFF
			if screen_glow:
				screen_glow.color = OfficePalette.MONITOR_SCREEN_OFF

		MonitorState.RESERVED:
			if status_indicator:
				status_indicator.color = OfficePalette.GRUVBOX_YELLOW

		MonitorState.ACTIVE:
			if status_indicator:
				status_indicator.color = OfficePalette.STATUS_LED_GREEN
			if screen:
				screen.color = OfficePalette.MONITOR_SCREEN_ON
			if screen_glow:
				screen_glow.color = OfficePalette.MONITOR_SCREEN_GLOW

		MonitorState.WAITING:
			if status_indicator:
				status_indicator.color = OfficePalette.STATUS_LED_RED
			if screen:
				screen.color = OfficePalette.MONITOR_SCREEN_WAITING
			if screen_glow:
				screen_glow.color = OfficePalette.MONITOR_SCREEN_WAITING_GLOW

func set_monitor_active(active: bool) -> void:
	_set_monitor_state(MonitorState.ACTIVE if active else MonitorState.OFF)

func set_monitor_waiting(waiting: bool) -> void:
	if waiting:
		_set_monitor_state(MonitorState.WAITING)
	else:
		_set_monitor_state(MonitorState.ACTIVE)

# --- Tool Display ---

func show_tool(tool_text: String, tool_color: Color) -> void:
	if tool_label:
		tool_label.text = tool_text
		tool_label.add_theme_color_override("font_color", tool_color)
		tool_label.visible = true
		tool_label.modulate.a = 1.0

func hide_tool() -> void:
	if tool_label:
		tool_label.visible = false

# --- Personal Items ---

func add_personal_item(item: Node2D) -> void:
	if personal_items_container:
		personal_items_container.add_child(item)

func clear_personal_items() -> void:
	if personal_items_container:
		for child in personal_items_container.get_children():
			child.queue_free()

# --- Compatibility ---

func get_work_position() -> Vector2:
	## Returns world position where agent should stand
	return get_slot_position(0)

func is_available() -> bool:
	## Compatibility with old Desk.is_available()
	return is_empty()

func set_occupied(occupied: bool, agent_id: String = "") -> void:
	## Compatibility with old Desk.set_occupied()
	if occupied:
		if agent_id != "":
			reserve(agent_id, 0)
	else:
		if agent_id != "":
			release(agent_id)
		else:
			release_slot(0)

var is_occupied: bool:
	get:
		return not is_empty()

var occupied_by: String:
	get:
		return get_occupant(0)
