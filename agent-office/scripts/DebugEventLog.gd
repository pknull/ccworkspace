extends CanvasLayer
class_name DebugEventLog

# =============================================================================
# DEBUG EVENT LOG - Real-time event watcher for debugging
# =============================================================================
# Shows timestamped events in a scrollable list with category filters

signal close_requested()

# Singleton-style access - instance stored in script meta to avoid self-reference issues

# Container for all visual elements
var container: Control

# Visual elements
var background: ColorRect
var border: ColorRect
var panel: ColorRect
var close_button: Button
var title_label: Label
var clear_button: Button
var auto_scroll_check: CheckBox
var scroll_container: ScrollContainer
var event_container: VBoxContainer

# Filter buttons
var filter_container: HBoxContainer
var filter_all: Button
var filter_nav: Button
var filter_path: Button
var filter_stuck: Button
var filter_audio: Button

# Layout constants
const PANEL_WIDTH: float = 500
const PANEL_HEIGHT: float = 400
const ROW_HEIGHT: float = 18
const HEADER_HEIGHT: float = 70
const MAX_EVENTS: int = 200

# Font sizes
const FONT_SIZE_TITLE: int = 14
const FONT_SIZE_EVENT: int = 10
const FONT_SIZE_FILTER: int = 9

# Event storage
var events: Array[Dictionary] = []
var active_filter: String = "ALL"
var auto_scroll: bool = true

# Event categories and colors
const CATEGORY_COLORS = {
	"NAV": Color(0.514, 0.647, 0.596),    # GRUVBOX_BLUE_BRIGHT
	"PATH": Color(0.722, 0.733, 0.149),   # GRUVBOX_GREEN_BRIGHT
	"STUCK": Color(0.984, 0.286, 0.204),  # GRUVBOX_RED_BRIGHT
	"AUDIO": Color(0.827, 0.525, 0.608),  # GRUVBOX_PURPLE_BRIGHT
	"STATE": Color(0.980, 0.741, 0.184),  # GRUVBOX_YELLOW_BRIGHT
	"INFO": Color(0.659, 0.600, 0.518),   # GRUVBOX_LIGHT4
}

func _init() -> void:
	layer = OfficeConstants.Z_UI_POPUP_LAYER + 1  # Above other popups

func _ready() -> void:
	# Set static instance after tree is ready
	var script = get_script()
	if script:
		script.set_meta("instance", self)
	_create_visuals()

func _exit_tree() -> void:
	var script = get_script()
	if script and script.get_meta("instance", null) == self:
		script.remove_meta("instance")

func _create_visuals() -> void:
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	var screen_center = Vector2(OfficeConstants.SCREEN_WIDTH / 2, OfficeConstants.SCREEN_HEIGHT / 2)
	var panel_x = screen_center.x - PANEL_WIDTH / 2
	var panel_y = screen_center.y - PANEL_HEIGHT / 2

	# Background overlay (less opaque to see game behind)
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.position = Vector2.ZERO
	background.color = Color(0, 0, 0, 0.6)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(background)

	# Panel border
	border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, PANEL_HEIGHT + 4)
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.color = OfficePalette.GRUVBOX_AQUA
	container.add_child(border)

	# Main panel
	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.position = Vector2(panel_x, panel_y)
	panel.color = OfficePalette.GRUVBOX_BG_HARD
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(panel)

	# Title
	title_label = Label.new()
	title_label.text = "EVENT LOG"
	title_label.position = Vector2(panel_x + 10, panel_y + 8)
	title_label.size = Vector2(100, 20)
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_AQUA)
	container.add_child(title_label)

	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 6)
	close_button.size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

	# Clear button
	clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.position = Vector2(panel_x + PANEL_WIDTH - 80, panel_y + 6)
	clear_button.size = Vector2(45, 24)
	clear_button.add_theme_font_size_override("font_size", 10)
	clear_button.pressed.connect(_on_clear_pressed)
	container.add_child(clear_button)

	# Auto-scroll checkbox
	auto_scroll_check = CheckBox.new()
	auto_scroll_check.text = "Auto-scroll"
	auto_scroll_check.button_pressed = true
	auto_scroll_check.position = Vector2(panel_x + PANEL_WIDTH - 175, panel_y + 8)
	auto_scroll_check.size = Vector2(90, 20)
	auto_scroll_check.add_theme_font_size_override("font_size", 10)
	auto_scroll_check.toggled.connect(_on_auto_scroll_toggled)
	container.add_child(auto_scroll_check)

	# Filter buttons
	filter_container = HBoxContainer.new()
	filter_container.position = Vector2(panel_x + 10, panel_y + 32)
	filter_container.size = Vector2(PANEL_WIDTH - 20, 24)
	filter_container.add_theme_constant_override("separation", 4)
	container.add_child(filter_container)

	filter_all = _create_filter_button("ALL", true)
	filter_nav = _create_filter_button("NAV")
	filter_path = _create_filter_button("PATH")
	filter_stuck = _create_filter_button("STUCK")
	filter_audio = _create_filter_button("AUDIO")
	filter_container.add_child(filter_all)
	filter_container.add_child(filter_nav)
	filter_container.add_child(filter_path)
	filter_container.add_child(filter_stuck)
	filter_container.add_child(filter_audio)

	# Scroll container for events
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(panel_x + 5, panel_y + HEADER_HEIGHT)
	scroll_container.size = Vector2(PANEL_WIDTH - 10, PANEL_HEIGHT - HEADER_HEIGHT - 10)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(scroll_container)

	# Event container inside scroll
	event_container = VBoxContainer.new()
	event_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_container.add_theme_constant_override("separation", 1)
	event_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_container.add_child(event_container)

func _create_filter_button(text: String, active: bool = false) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = active
	btn.size = Vector2(50, 22)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_FILTER)
	btn.pressed.connect(_on_filter_pressed.bind(text))
	return btn

func _on_filter_pressed(filter: String) -> void:
	active_filter = filter
	# Update button states
	filter_all.button_pressed = (filter == "ALL")
	filter_nav.button_pressed = (filter == "NAV")
	filter_path.button_pressed = (filter == "PATH")
	filter_stuck.button_pressed = (filter == "STUCK")
	filter_audio.button_pressed = (filter == "AUDIO")
	_refresh_display()

func _on_clear_pressed() -> void:
	events.clear()
	_refresh_display()

func _on_auto_scroll_toggled(pressed: bool) -> void:
	auto_scroll = pressed

func _on_close_pressed() -> void:
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			close_requested.emit()
			get_viewport().set_input_as_handled()

# Static method for easy logging from anywhere
static func log_event(category: String, message: String, agent_id: String = "") -> void:
	var script = load("res://scripts/DebugEventLog.gd")
	if script:
		var inst = script.get_meta("instance", null)
		if inst and inst.has_method("add_event"):
			inst.add_event(category, message, agent_id)

func add_event(category: String, message: String, agent_id: String = "") -> void:
	var timestamp = Time.get_time_string_from_system()
	var event = {
		"time": timestamp,
		"category": category.to_upper(),
		"message": message,
		"agent": agent_id
	}
	events.append(event)

	# Trim old events
	while events.size() > MAX_EVENTS:
		events.pop_front()

	# Add to display if matches filter
	if active_filter == "ALL" or event.category == active_filter:
		_add_event_row(event)
		if auto_scroll:
			# Defer scroll to after layout
			call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	scroll_container.scroll_vertical = int(event_container.size.y)

func _refresh_display() -> void:
	# Clear display
	for child in event_container.get_children():
		child.queue_free()

	# Re-add filtered events
	for event in events:
		if active_filter == "ALL" or event.category == active_filter:
			_add_event_row(event)

	if auto_scroll:
		call_deferred("_scroll_to_bottom")

func _add_event_row(event: Dictionary) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(PANEL_WIDTH - 30, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 6)

	# Timestamp
	var time_label = Label.new()
	time_label.text = event.time.substr(0, 8)  # HH:MM:SS
	time_label.custom_minimum_size = Vector2(55, 0)
	time_label.add_theme_font_size_override("font_size", FONT_SIZE_EVENT)
	time_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GRAY)
	row.add_child(time_label)

	# Category tag
	var cat_label = Label.new()
	cat_label.text = "[%s]" % event.category
	cat_label.custom_minimum_size = Vector2(50, 0)
	cat_label.add_theme_font_size_override("font_size", FONT_SIZE_EVENT)
	var cat_color = CATEGORY_COLORS.get(event.category, OfficePalette.GRUVBOX_LIGHT4)
	cat_label.add_theme_color_override("font_color", cat_color)
	row.add_child(cat_label)

	# Agent ID (if present)
	if not event.agent.is_empty():
		var agent_label = Label.new()
		agent_label.text = event.agent.substr(0, 8)
		agent_label.custom_minimum_size = Vector2(60, 0)
		agent_label.add_theme_font_size_override("font_size", FONT_SIZE_EVENT)
		agent_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
		row.add_child(agent_label)

	# Message
	var msg_label = Label.new()
	msg_label.text = event.message
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_label.clip_text = true
	msg_label.add_theme_font_size_override("font_size", FONT_SIZE_EVENT)
	msg_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	row.add_child(msg_label)

	event_container.add_child(row)
