extends CanvasLayer
class_name RosterPopup

# =============================================================================
# ROSTER POPUP - Full Agent Roster View
# =============================================================================
# Displays all agents in a scrollable list with basic stats
# Uses CanvasLayer to render above all game content

signal close_requested()
signal agent_selected(agent_id: int)

# Container for all visual elements
var container: Control

# Visual elements
var background: ColorRect
var border: ColorRect
var panel: ColorRect
var close_button: Button
var title_label: Label
var scroll_container: ScrollContainer
var agent_container: VBoxContainer

# Header labels (need repositioning on resize)
var header_rank: Label
var header_name: Label
var header_level: Label
var header_xp: Label
var header_tasks: Label
var header_title: Label
var header_divider: ColorRect

# Layout constants
const PANEL_WIDTH: float = 500
const PANEL_MIN_HEIGHT: float = 150
const PANEL_MAX_HEIGHT: float = 500
const ROW_HEIGHT: float = 36
const HEADER_HEIGHT: float = 85  # Title + header row + divider

var panel_height: float = PANEL_MIN_HEIGHT

# Font sizes
const FONT_SIZE_TITLE: int = 16
const FONT_SIZE_ROW: int = 11
const FONT_SIZE_SMALL: int = 9

# Data reference
var roster: AgentRoster = null

func _init() -> void:
	# Set canvas layer to render above game (layer 0)
	# Must be set in _init before node is added to tree
	layer = 100

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	# Create a Control container for all UI elements
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	var screen_center = Vector2(OfficeConstants.SCREEN_WIDTH / 2, OfficeConstants.SCREEN_HEIGHT / 2)
	var panel_x = screen_center.x - PANEL_WIDTH / 2
	var panel_y = screen_center.y - panel_height / 2

	# Semi-transparent background overlay (darker to better obscure office)
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.position = Vector2.ZERO
	background.color = Color(0, 0, 0, 0.85)
	container.add_child(background)

	# Panel border (behind panel)
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
	container.add_child(panel)

	# Title
	title_label = Label.new()
	title_label.text = "AGENT ROSTER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(panel_x, panel_y + 12)
	title_label.size = Vector2(PANEL_WIDTH, 24)
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(title_label)

	# Header row
	var header_y = panel_y + 45
	_create_header_row(panel_x, header_y)

	# Divider
	header_divider = ColorRect.new()
	header_divider.size = Vector2(PANEL_WIDTH - 20, 1)
	header_divider.position = Vector2(panel_x + 10, header_y + 20)
	header_divider.color = OfficePalette.GRUVBOX_BG3
	container.add_child(header_divider)

	# Scroll container for agent rows
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(panel_x + 10, header_y + 25)
	scroll_container.size = Vector2(PANEL_WIDTH - 20, panel_height - HEADER_HEIGHT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll_container)

	# Agent container inside scroll
	agent_container = VBoxContainer.new()
	agent_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(agent_container)

	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 8)
	close_button.size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

func _create_header_row(panel_x: float, y: float) -> void:
	header_rank = Label.new()
	header_rank.text = "#"
	header_rank.position = Vector2(panel_x + 15, y)
	header_rank.size = Vector2(25, 20)
	header_rank.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	header_rank.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(header_rank)

	header_name = Label.new()
	header_name.text = "Name"
	header_name.position = Vector2(panel_x + 40, y)
	header_name.size = Vector2(100, 20)
	header_name.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	header_name.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(header_name)

	header_level = Label.new()
	header_level.text = "Level"
	header_level.position = Vector2(panel_x + 145, y)
	header_level.size = Vector2(60, 20)
	header_level.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	header_level.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(header_level)

	header_xp = Label.new()
	header_xp.text = "XP"
	header_xp.position = Vector2(panel_x + 210, y)
	header_xp.size = Vector2(60, 20)
	header_xp.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	header_xp.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(header_xp)

	header_tasks = Label.new()
	header_tasks.text = "Tasks"
	header_tasks.position = Vector2(panel_x + 275, y)
	header_tasks.size = Vector2(50, 20)
	header_tasks.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	header_tasks.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(header_tasks)

	header_title = Label.new()
	header_title.text = "Title"
	header_title.position = Vector2(panel_x + 360, y)
	header_title.size = Vector2(80, 20)
	header_title.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	header_title.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(header_title)

func show_roster(agent_roster: AgentRoster) -> void:
	roster = agent_roster
	# Calculate panel height based on number of agents
	var agent_count = roster.get_agent_count() if roster else 0
	var content_height = HEADER_HEIGHT + (agent_count * ROW_HEIGHT) + 20
	panel_height = clamp(content_height, PANEL_MIN_HEIGHT, PANEL_MAX_HEIGHT)
	_resize_panel()
	_populate_rows()

func _populate_rows() -> void:
	# Clear existing rows
	for child in agent_container.get_children():
		child.queue_free()

	if roster == null:
		return

	var agents = roster.get_agents_sorted_by_xp()

	for i in range(agents.size()):
		var agent = agents[i]
		var row = _create_agent_row(agent, i + 1)
		agent_container.add_child(row)

	# Update title with count
	title_label.text = "AGENT ROSTER (%d)" % agents.size()

func _create_agent_row(profile: AgentProfile, rank: int) -> Control:
	var row = Control.new()
	row.custom_minimum_size = Vector2(PANEL_WIDTH - 20, ROW_HEIGHT)

	# Row background (alternating)
	var row_bg = ColorRect.new()
	row_bg.size = Vector2(PANEL_WIDTH - 20, ROW_HEIGHT - 2)
	row_bg.position = Vector2(0, 0)
	row_bg.color = OfficePalette.GRUVBOX_BG1 if rank % 2 == 0 else OfficePalette.GRUVBOX_BG
	row.add_child(row_bg)

	# Make row clickable
	var click_button = Button.new()
	click_button.flat = true
	click_button.size = Vector2(PANEL_WIDTH - 20, ROW_HEIGHT - 2)
	click_button.position = Vector2(0, 0)
	click_button.pressed.connect(func(): agent_selected.emit(profile.id))
	row.add_child(click_button)

	# Rank
	var rank_label = Label.new()
	rank_label.text = "%d" % rank
	rank_label.position = Vector2(5, 8)
	rank_label.size = Vector2(25, 20)
	rank_label.add_theme_font_size_override("font_size", FONT_SIZE_ROW)
	rank_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rank_label)

	# Name
	var name_label = Label.new()
	name_label.text = profile.agent_name
	name_label.position = Vector2(30, 8)
	name_label.size = Vector2(100, 20)
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_ROW)
	name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	# Level
	var level_label = Label.new()
	level_label.text = "%d" % profile.level
	level_label.position = Vector2(135, 8)
	level_label.size = Vector2(60, 20)
	level_label.add_theme_font_size_override("font_size", FONT_SIZE_ROW)
	level_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_AQUA)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(level_label)

	# XP
	var xp_label = Label.new()
	xp_label.text = "%d" % profile.xp
	xp_label.position = Vector2(200, 8)
	xp_label.size = Vector2(60, 20)
	xp_label.add_theme_font_size_override("font_size", FONT_SIZE_ROW)
	xp_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(xp_label)

	# Tasks
	var tasks_label = Label.new()
	tasks_label.text = "%d" % profile.tasks_completed
	tasks_label.position = Vector2(265, 8)
	tasks_label.size = Vector2(50, 20)
	tasks_label.add_theme_font_size_override("font_size", FONT_SIZE_ROW)
	tasks_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GREEN)
	tasks_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tasks_label)

	# Title (agent title like "Junior", "Senior", etc.)
	var agent_title_label = Label.new()
	agent_title_label.text = profile.get_title()
	agent_title_label.position = Vector2(350, 8)
	agent_title_label.size = Vector2(100, 20)
	agent_title_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	agent_title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_PURPLE)
	agent_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(agent_title_label)

	return row

func _on_close_pressed() -> void:
	close_requested.emit()

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
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 8)

	# Reposition header row
	var header_y = panel_y + 45
	header_rank.position = Vector2(panel_x + 15, header_y)
	header_name.position = Vector2(panel_x + 40, header_y)
	header_level.position = Vector2(panel_x + 145, header_y)
	header_xp.position = Vector2(panel_x + 210, header_y)
	header_tasks.position = Vector2(panel_x + 275, header_y)
	header_title.position = Vector2(panel_x + 360, header_y)
	header_divider.position = Vector2(panel_x + 10, header_y + 20)

	scroll_container.position = Vector2(panel_x + 10, header_y + 25)
	scroll_container.size = Vector2(PANEL_WIDTH - 20, panel_height - HEADER_HEIGHT)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			close_requested.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Close if clicked outside panel
			var panel_rect = Rect2(
				panel.position.x, panel.position.y,
				PANEL_WIDTH, panel_height
			)
			if not panel_rect.has_point(event.position):
				close_requested.emit()
				get_viewport().set_input_as_handled()
