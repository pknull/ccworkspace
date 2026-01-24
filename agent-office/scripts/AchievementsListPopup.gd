extends CanvasLayer
class_name AchievementsListPopup

# =============================================================================
# ACHIEVEMENT POPUP - Shows All Achievements
# =============================================================================
# Displays unlocked and locked achievements in a scrollable list

signal close_requested()

# Container for all visual elements
var container: Control

# Visual elements
var background: ColorRect
var border: ColorRect
var panel: ColorRect
var close_button: Button
var title_label: Label
var progress_label: Label
var divider: ColorRect
var scroll_container: ScrollContainer
var achievement_container: VBoxContainer

# Layout constants
const PANEL_WIDTH: float = 450
const PANEL_MIN_HEIGHT: float = 150
const PANEL_MAX_HEIGHT: float = 500
const ROW_HEIGHT: float = 64
const HEADER_HEIGHT: float = 75  # Title + progress + divider

var panel_height: float = PANEL_MIN_HEIGHT

# Font sizes
const FONT_SIZE_TITLE: int = 16
const FONT_SIZE_NAME: int = 12
const FONT_SIZE_DESC: int = 10

# Data reference
var achievement_system: AchievementSystem = null

func _init() -> void:
	layer = OfficeConstants.Z_UI_POPUP_LAYER

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	var screen_center = Vector2(OfficeConstants.SCREEN_WIDTH / 2, OfficeConstants.SCREEN_HEIGHT / 2)
	var panel_x = screen_center.x - PANEL_WIDTH / 2
	var panel_y = screen_center.y - panel_height / 2

	# Background overlay
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.position = Vector2.ZERO
	background.color = Color(0, 0, 0, 0.75)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(background)

	# Panel border
	border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, panel_height + 4)
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.color = OfficePalette.GRUVBOX_YELLOW
	container.add_child(border)

	# Main panel
	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, panel_height)
	panel.position = Vector2(panel_x, panel_y)
	panel.color = OfficePalette.GRUVBOX_BG
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(panel)

	# Title
	title_label = Label.new()
	title_label.text = "ACHIEVEMENTS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(panel_x, panel_y + 12)
	title_label.size = Vector2(PANEL_WIDTH, 24)
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(title_label)

	# Progress label
	progress_label = Label.new()
	progress_label.text = "0 / 0 Unlocked"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.position = Vector2(panel_x, panel_y + 35)
	progress_label.size = Vector2(PANEL_WIDTH, 20)
	progress_label.add_theme_font_size_override("font_size", FONT_SIZE_DESC)
	progress_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(progress_label)

	# Divider
	divider = ColorRect.new()
	divider.size = Vector2(PANEL_WIDTH - 20, 1)
	divider.position = Vector2(panel_x + 10, panel_y + 58)
	divider.color = OfficePalette.GRUVBOX_BG3
	container.add_child(divider)

	# Scroll container for achievements
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(panel_x + 10, panel_y + 65)
	scroll_container.size = Vector2(PANEL_WIDTH - 20, panel_height - HEADER_HEIGHT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(scroll_container)

	# Achievement container inside scroll
	achievement_container = VBoxContainer.new()
	achievement_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_container.add_theme_constant_override("separation", 4)
	achievement_container.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll_container.add_child(achievement_container)

	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 8)
	close_button.size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

func show_achievements(system: AchievementSystem) -> void:
	achievement_system = system
	# Calculate panel height based on number of achievements
	var achievement_count = system.get_total_count() if system else 0
	var content_height = HEADER_HEIGHT + (achievement_count * ROW_HEIGHT) + 20
	panel_height = clamp(content_height, PANEL_MIN_HEIGHT, PANEL_MAX_HEIGHT)
	_resize_panel()
	_populate_achievements()

func _populate_achievements() -> void:
	# Clear existing
	for child in achievement_container.get_children():
		child.queue_free()

	if achievement_system == null:
		return

	var unlocked = achievement_system.get_unlocked_count()
	var total = achievement_system.get_total_count()
	progress_label.text = "%d / %d Unlocked (%.0f%%)" % [unlocked, total, achievement_system.get_progress_percent()]

	# Get all achievements, unlocked first
	var achievements = achievement_system.get_all_achievements()
	achievements.sort_custom(func(a, b):
		if a.is_unlocked and not b.is_unlocked:
			return true
		if not a.is_unlocked and b.is_unlocked:
			return false
		return a.id < b.id
	)

	for achievement in achievements:
		var row = _create_achievement_row(achievement)
		achievement_container.add_child(row)

func _resize_panel() -> void:
	if not panel:
		return
	var screen_center = Vector2(OfficeConstants.SCREEN_WIDTH / 2, OfficeConstants.SCREEN_HEIGHT / 2)
	var panel_x = screen_center.x - PANEL_WIDTH / 2
	var panel_y = screen_center.y - panel_height / 2

	border.size = Vector2(PANEL_WIDTH + 4, panel_height + 4)
	border.position = Vector2(panel_x - 2, panel_y - 2)
	panel.size = Vector2(PANEL_WIDTH, panel_height)
	panel.position = Vector2(panel_x, panel_y)
	title_label.position = Vector2(panel_x, panel_y + 12)
	progress_label.position = Vector2(panel_x, panel_y + 35)
	divider.position = Vector2(panel_x + 10, panel_y + 58)
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 8)
	scroll_container.position = Vector2(panel_x + 10, panel_y + 65)
	scroll_container.size = Vector2(PANEL_WIDTH - 20, panel_height - HEADER_HEIGHT)

func _create_achievement_row(achievement) -> Control:
	var row = Control.new()
	row.custom_minimum_size = Vector2(PANEL_WIDTH - 20, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	# Row background
	var row_bg = ColorRect.new()
	row_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	row_bg.color = OfficePalette.GRUVBOX_BG1 if achievement.is_unlocked else OfficePalette.GRUVBOX_BG
	row_bg.z_index = -1
	row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(row_bg)

	var content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 8)
	content.add_theme_constant_override("margin_right", 8)
	content.add_theme_constant_override("margin_top", 6)
	content.add_theme_constant_override("margin_bottom", 6)
	row.add_child(content)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	content.add_child(hbox)

	# Icon/status
	var icon = Label.new()
	icon.custom_minimum_size = Vector2(24, 20)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 12)
	if achievement.is_unlocked:
		icon.text = "[x]"
		icon.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GREEN)
	else:
		icon.text = "[ ]"
		icon.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	hbox.add_child(icon)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	hbox.add_child(text_box)

	# Name
	var name_label = Label.new()
	name_label.text = achievement.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_NAME)
	if achievement.is_unlocked:
		name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	else:
		name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	text_box.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = achievement.description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.clip_text = true
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE_DESC)
	desc_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	text_box.add_child(desc_label)

	# Unlock date (if unlocked)
	if achievement.is_unlocked and achievement.unlocked_at:
		var date_label = Label.new()
		date_label.text = _format_date(achievement.unlocked_at)
		date_label.custom_minimum_size = Vector2(70, 0)
		date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		date_label.add_theme_font_size_override("font_size", 9)
		date_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_AQUA)
		hbox.add_child(date_label)

	return row

func _format_date(iso_date: String) -> String:
	if iso_date.is_empty():
		return ""
	var parts = iso_date.split("T")
	if parts.size() > 0:
		var date_parts = parts[0].split("-")
		if date_parts.size() == 3:
			var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
						  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
			var month_idx = int(date_parts[1]) - 1
			if month_idx >= 0 and month_idx < 12:
				return "%s %d" % [months[month_idx], int(date_parts[2])]
	return iso_date.substr(0, 10)

func _on_close_pressed() -> void:
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			close_requested.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Close if clicked outside panel
			var panel_rect = Rect2(panel.position.x, panel.position.y, PANEL_WIDTH, panel_height)
			if not panel_rect.has_point(event.position):
				close_requested.emit()
				get_viewport().set_input_as_handled()
			else:
				get_viewport().set_input_as_handled()
