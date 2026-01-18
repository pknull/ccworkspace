extends CanvasLayer
class_name ProfilePopup

# =============================================================================
# PROFILE POPUP - Full Agent Profile View
# =============================================================================
# Displays detailed stats, skills, tools, and relationships for an agent
# Uses CanvasLayer to render above all game content

signal close_requested()

# Container for all visual elements
var container: Control

# Visual elements
var background: ColorRect
var panel: ColorRect
var close_button: Button

# Profile content
var portrait_container: Control
var name_label: Label
var title_label: Label
var level_label: Label
var xp_bar_bg: ColorRect
var xp_bar_fill: ColorRect
var xp_label: Label
var hired_label: Label
var last_seen_label: Label

# Stats section
var stats_container: Control
var tasks_label: Label
var failed_label: Label
var success_label: Label
var time_label: Label
var orchestrator_label: Label

# Skills section
var skills_container: Control
var skill_bars: Array[Control] = []

# Tools section
var tools_container: Control
var tool_bars: Array[Control] = []

# Badges section
var badges_container: Control
var badges_label: Label

# Colleagues section
var colleagues_label: Label

# Layout constants
const PANEL_WIDTH: float = 700
const PANEL_HEIGHT: float = 500
const PANEL_MARGIN: float = 20

# Font sizes
const FONT_SIZE_TITLE: int = 20
const FONT_SIZE_HEADER: int = 14
const FONT_SIZE_BODY: int = 12
const FONT_SIZE_SMALL: int = 11

# Reference to badge system for badge info
var badge_system: BadgeSystem = null
var roster: AgentRoster = null

func _init() -> void:
	# Set canvas layer to render above game (layer 0)
	# Must be set in _init before node is added to tree
	layer = 100

func _ready() -> void:
	_create_visuals()

func setup(agent_roster: AgentRoster, p_badge_system: BadgeSystem) -> void:
	roster = agent_roster
	badge_system = p_badge_system

func show_profile(profile: AgentProfile) -> void:
	visible = true
	_populate_profile(profile)

func _create_visuals() -> void:
	# Create a Control container for all UI elements
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	# Semi-transparent background overlay
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.color = Color(0, 0, 0, 0.85)
	container.add_child(background)

	# Main panel
	var panel_x = (OfficeConstants.SCREEN_WIDTH - PANEL_WIDTH) / 2
	var panel_y = (OfficeConstants.SCREEN_HEIGHT - PANEL_HEIGHT) / 2

	# Panel border (behind panel)
	var border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, PANEL_HEIGHT + 4)
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.color = OfficePalette.GRUVBOX_LIGHT4
	container.add_child(border)

	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.position = Vector2(panel_x, panel_y)
	panel.color = OfficePalette.GRUVBOX_BG
	container.add_child(panel)

	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 5)
	close_button.size = Vector2(25, 25)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

	# Title: "AGENT PROFILE"
	var title = Label.new()
	title.text = "AGENT PROFILE"
	title.position = Vector2(panel_x + PANEL_WIDTH / 2 - 60, panel_y + 10)
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	container.add_child(title)

	var content_y = panel_y + 45

	# Portrait area (left side)
	portrait_container = Control.new()
	portrait_container.position = Vector2(panel_x + 30, content_y + 20)
	container.add_child(portrait_container)

	var portrait_bg = ColorRect.new()
	portrait_bg.size = Vector2(80, 100)
	portrait_bg.color = OfficePalette.GRUVBOX_BG1
	portrait_container.add_child(portrait_bg)

	# Name and title (next to portrait)
	var info_x = panel_x + 130

	name_label = Label.new()
	name_label.text = "Agent Name"
	name_label.position = Vector2(info_x, content_y)
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	container.add_child(name_label)

	title_label = Label.new()
	title_label.text = "Title (Level X)"
	title_label.position = Vector2(info_x, content_y + 26)
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(title_label)

	# XP Bar
	xp_bar_bg = ColorRect.new()
	xp_bar_bg.size = Vector2(200, 16)
	xp_bar_bg.position = Vector2(info_x, content_y + 52)
	xp_bar_bg.color = OfficePalette.GRUVBOX_BG2
	container.add_child(xp_bar_bg)

	xp_bar_fill = ColorRect.new()
	xp_bar_fill.size = Vector2(100, 14)
	xp_bar_fill.position = Vector2(info_x + 1, content_y + 53)
	xp_bar_fill.color = OfficePalette.GRUVBOX_AQUA
	container.add_child(xp_bar_fill)

	xp_label = Label.new()
	xp_label.text = "0 / 500 XP"
	xp_label.position = Vector2(info_x + 210, content_y + 52)
	xp_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	xp_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(xp_label)

	# Hired / Last seen
	hired_label = Label.new()
	hired_label.text = "Hired: ---"
	hired_label.position = Vector2(info_x, content_y + 78)
	hired_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	hired_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(hired_label)

	last_seen_label = Label.new()
	last_seen_label.text = "Last seen: ---"
	last_seen_label.position = Vector2(info_x + 150, content_y + 78)
	last_seen_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	last_seen_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(last_seen_label)

	# Badges
	badges_label = Label.new()
	badges_label.text = "Badges: None"
	badges_label.position = Vector2(info_x, content_y + 100)
	badges_label.size = Vector2(400, 20)
	badges_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	badges_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(badges_label)

	# Divider line
	var divider = ColorRect.new()
	divider.size = Vector2(PANEL_WIDTH - 40, 2)
	divider.position = Vector2(panel_x + 20, content_y + 130)
	divider.color = OfficePalette.GRUVBOX_BG2
	container.add_child(divider)

	var section_y = content_y + 145

	# STATS section (left column)
	var stats_header = Label.new()
	stats_header.text = "-- STATS --"
	stats_header.position = Vector2(panel_x + 30, section_y)
	stats_header.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	stats_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(stats_header)

	var stats_y = section_y + 22

	tasks_label = _create_stat_label(panel_x + 30, stats_y, "Tasks Done: 0")
	failed_label = _create_stat_label(panel_x + 30, stats_y + 18, "Tasks Failed: 0")
	success_label = _create_stat_label(panel_x + 30, stats_y + 36, "Success Rate: 0%")
	time_label = _create_stat_label(panel_x + 30, stats_y + 54, "Work Time: 0.0 hr")
	orchestrator_label = _create_stat_label(panel_x + 30, stats_y + 72, "Orchestrator: 0x")

	# SKILLS section (middle column)
	var skills_header = Label.new()
	skills_header.text = "-- SKILLS --"
	skills_header.position = Vector2(panel_x + 200, section_y)
	skills_header.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	skills_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(skills_header)

	skills_container = Control.new()
	skills_container.position = Vector2(panel_x + 200, stats_y)
	container.add_child(skills_container)

	# TOOLS section (right column)
	var tools_header = Label.new()
	tools_header.text = "-- TOOLS --"
	tools_header.position = Vector2(panel_x + 470, section_y)
	tools_header.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	tools_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(tools_header)

	tools_container = Control.new()
	tools_container.position = Vector2(panel_x + 470, stats_y)
	container.add_child(tools_container)

	# Colleagues section (bottom)
	var colleagues_header = Label.new()
	colleagues_header.text = "-- COLLEAGUES --"
	colleagues_header.position = Vector2(panel_x + 30, section_y + 150)
	colleagues_header.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	colleagues_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(colleagues_header)

	colleagues_label = Label.new()
	colleagues_label.text = "No colleagues yet"
	colleagues_label.position = Vector2(panel_x + 30, section_y + 172)
	colleagues_label.size = Vector2(PANEL_WIDTH - 60, 60)
	colleagues_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	colleagues_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	colleagues_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(colleagues_label)

func _create_stat_label(x: float, y: float, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	container.add_child(label)
	return label

func _populate_profile(profile: AgentProfile) -> void:
	# Name and title
	name_label.text = profile.agent_name
	title_label.text = "%s (Level %d)" % [profile.get_title(), profile.level]

	# XP bar
	var progress = profile.get_xp_progress()
	xp_bar_fill.size.x = max(1, 198 * progress)

	var next_xp = profile.get_xp_for_next_level()
	if next_xp > 0:
		xp_label.text = "%d / %d XP" % [profile.xp, next_xp]
	else:
		xp_label.text = "%d XP (MAX)" % profile.xp

	# Dates
	hired_label.text = "Hired: %s" % _format_date(profile.hired_at)
	last_seen_label.text = "Last: %s" % _format_date(profile.last_seen)

	# Badges
	if profile.badges.is_empty():
		badges_label.text = "Badges: None yet"
	else:
		var badge_texts: Array[String] = []
		for badge_id in profile.badges:
			if badge_system:
				var info = badge_system.get_badge_info(badge_id)
				badge_texts.append("%s %s" % [info.get("icon", ""), info.get("name", badge_id)])
			else:
				badge_texts.append(badge_id)
		badges_label.text = "Badges: " + ", ".join(badge_texts)

	# Stats
	tasks_label.text = "Tasks Done: %d" % profile.tasks_completed
	failed_label.text = "Tasks Failed: %d" % profile.tasks_failed
	success_label.text = "Success Rate: %.0f%%" % profile.get_success_rate()
	time_label.text = "Work Time: %.1f hr" % profile.get_work_time_hours()
	orchestrator_label.text = "Orchestrator: %dx" % profile.orchestrator_sessions

	# Skills
	_populate_skills(profile)

	# Tools
	_populate_tools(profile)

	# Colleagues
	_populate_colleagues(profile)

func _populate_skills(profile: AgentProfile) -> void:
	# Clear existing
	for child in skills_container.get_children():
		child.queue_free()
	skill_bars.clear()

	# Sort skills by task count
	var sorted_skills: Array = []
	for skill_name in profile.skills.keys():
		sorted_skills.append({"name": skill_name, "data": profile.skills[skill_name]})
	sorted_skills.sort_custom(func(a, b): return a.data.tasks > b.data.tasks)

	var max_tasks = 1
	if not sorted_skills.is_empty():
		max_tasks = max(1, sorted_skills[0].data.tasks)

	var y = 0
	for i in range(min(6, sorted_skills.size())):
		var skill = sorted_skills[i]
		var bar = _create_bar(skill.name, skill.data.tasks, max_tasks, OfficePalette.GRUVBOX_GREEN)
		bar.position.y = y
		skills_container.add_child(bar)
		skill_bars.append(bar)
		y += 18

	if sorted_skills.is_empty():
		var empty = Label.new()
		empty.text = "No skills yet"
		empty.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
		empty.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
		skills_container.add_child(empty)

func _populate_tools(profile: AgentProfile) -> void:
	# Clear existing
	for child in tools_container.get_children():
		child.queue_free()
	tool_bars.clear()

	# Sort tools by count
	var sorted_tools: Array = []
	for tool_name in profile.tools.keys():
		sorted_tools.append({"name": tool_name, "count": profile.tools[tool_name]})
	sorted_tools.sort_custom(func(a, b): return a.count > b.count)

	var max_count = 1
	if not sorted_tools.is_empty():
		max_count = max(1, sorted_tools[0].count)

	var y = 0
	for i in range(min(6, sorted_tools.size())):
		var tool = sorted_tools[i]
		var bar = _create_bar(tool.name, tool.count, max_count, OfficePalette.GRUVBOX_BLUE)
		bar.position.y = y
		tools_container.add_child(bar)
		tool_bars.append(bar)
		y += 18

	if sorted_tools.is_empty():
		var empty = Label.new()
		empty.text = "No tools yet"
		empty.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
		empty.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
		tools_container.add_child(empty)

func _create_bar(label_text: String, value: int, max_value: int, color: Color) -> Control:
	var bar_container = Control.new()

	# Truncate long names
	var display_name = label_text
	if display_name.length() > 12:
		display_name = display_name.substr(0, 10) + ".."

	var label = Label.new()
	label.text = display_name
	label.size = Vector2(80, 16)
	label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	bar_container.add_child(label)

	var bar_width = 80.0 * (float(value) / float(max_value))
	var bar = ColorRect.new()
	bar.size = Vector2(max(2, bar_width), 12)
	bar.position = Vector2(85, 2)
	bar.color = color
	bar_container.add_child(bar)

	var count = Label.new()
	count.text = str(value)
	count.position = Vector2(170, 0)
	count.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	count.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	bar_container.add_child(count)

	return bar_container

func _populate_colleagues(profile: AgentProfile) -> void:
	var lines: Array[String] = []

	# Worked with
	if not profile.worked_with.is_empty():
		var worked: Array[String] = []
		for agent_id_str in profile.worked_with.keys():
			var count = profile.worked_with[agent_id_str]
			if roster:
				var other = roster.get_agent(int(agent_id_str))
				if other:
					worked.append("%s (%dx)" % [other.agent_name, count])
		if not worked.is_empty():
			lines.append("Worked with: " + ", ".join(worked))

	# Chatted with
	if not profile.chatted_with.is_empty():
		var chatted: Array[String] = []
		for agent_id_str in profile.chatted_with.keys():
			var count = profile.chatted_with[agent_id_str]
			if roster:
				var other = roster.get_agent(int(agent_id_str))
				if other:
					chatted.append("%s (%dx)" % [other.agent_name, count])
		if not chatted.is_empty():
			lines.append("Chatted with: " + ", ".join(chatted))

	if lines.is_empty():
		colleagues_label.text = "No colleagues yet"
	else:
		colleagues_label.text = "\n".join(lines)

func _format_date(iso_date: String) -> String:
	if iso_date.is_empty():
		return "---"
	# Extract just the date part: "2026-01-17T14:30:00" -> "Jan 17"
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
	visible = false
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
