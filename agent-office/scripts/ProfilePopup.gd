extends CanvasLayer
class_name ProfilePopup

# =============================================================================
# PROFILE POPUP - Full Agent Profile View
# =============================================================================
# Displays detailed stats, skills, tools, and relationships for an agent
# Uses CanvasLayer to render above all game content

signal close_requested()
signal profile_updated(profile: AgentProfile)

# Container for all visual elements
var container: Control

# Current profile being displayed
var current_profile: AgentProfile = null

# Edit appearance
var edit_button: Button
var appearance_editor: AppearanceEditorPopup = null

# Visual elements
var background: ColorRect
var panel: ColorRect
var close_button: Button

# Profile content
var portrait_container: Control
var portrait_layer: Control
var name_label: Label
var title_label: Label
var level_label: Label
var xp_bar_bg: ColorRect
var xp_bar_fill: ColorRect
var xp_label: Label
var hired_label: Label
var last_seen_label: Label

# Stats section
var tasks_label: Label
var failed_label: Label
var success_label: Label
var time_label: Label

# Skills section
var skills_container: Control
var skill_bars: Array[Control] = []

# Tools section
var tools_container: Control
var tool_bars: Array[Control] = []

# Badges section
var badges_container: Control
var badges_label: Label
var badges_scroll: ScrollContainer

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

# Hair colors palette (same order as AgentProfile indices)
const HAIR_COLORS: Array[Color] = [
	Color(0.45, 0.32, 0.22),  # Brown
	Color(0.15, 0.12, 0.10),  # Black
	Color(0.85, 0.75, 0.55),  # Blonde
	Color(0.55, 0.25, 0.15),  # Red
	Color(0.35, 0.35, 0.40),  # Gray
	Color(0.08, 0.06, 0.05),  # Very dark
]

# Skin tones palette (same order as AgentProfile indices)
const SKIN_TONES: Array[Color] = [
	Color(0.95, 0.82, 0.70),  # Light
	Color(0.78, 0.60, 0.45),  # Medium
	Color(0.55, 0.38, 0.28),  # Dark
	Color(0.40, 0.28, 0.20),  # Very dark
	Color(1.0, 0.90, 0.80),   # Very light
]

# Reference to badge system for badge info
var badge_system: BadgeSystem = null
var roster: AgentRoster = null

func _init() -> void:
	# Set canvas layer to render above game (layer 0)
	# Must be set in _init before node is added to tree
	layer = OfficeConstants.Z_UI_POPUP_LAYER

func _ready() -> void:
	_create_visuals()

func setup(agent_roster: AgentRoster, p_badge_system: BadgeSystem) -> void:
	roster = agent_roster
	badge_system = p_badge_system

func show_profile(profile: AgentProfile) -> void:
	if profile == null:
		push_warning("[ProfilePopup] show_profile called with null profile")
		return
	current_profile = profile
	visible = true
	_populate_profile(profile)

func _create_visuals() -> void:
	# Create a Control container for all UI elements
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	# Semi-transparent background overlay
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.color = Color(0, 0, 0, 0.75)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(background)

	# Main panel
	var panel_x = (OfficeConstants.SCREEN_WIDTH - PANEL_WIDTH) / 2
	var panel_y = (OfficeConstants.SCREEN_HEIGHT - PANEL_HEIGHT) / 2

	# Panel border (behind panel)
	var border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, PANEL_HEIGHT + 4)
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.color = OfficePalette.GRUVBOX_YELLOW
	container.add_child(border)

	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.position = Vector2(panel_x, panel_y)
	panel.color = OfficePalette.GRUVBOX_BG
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(panel)

	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 8)
	close_button.size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

	# Title: "AGENT PROFILE"
	var title = Label.new()
	title.text = "AGENT PROFILE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(panel_x, panel_y + 12)
	title.size = Vector2(PANEL_WIDTH, 24)
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
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

	portrait_layer = Control.new()
	portrait_layer.position = Vector2.ZERO
	portrait_layer.size = Vector2(80, 100)
	portrait_container.add_child(portrait_layer)

	# Edit button (inside portrait box at bottom)
	edit_button = Button.new()
	edit_button.text = "Edit"
	edit_button.position = Vector2(5, 75)  # Inside portrait container
	edit_button.size = Vector2(70, 20)
	edit_button.add_theme_font_size_override("font_size", 10)
	edit_button.pressed.connect(_on_edit_pressed)
	portrait_container.add_child(edit_button)

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
	badges_label.text = "Badges:"
	badges_label.position = Vector2(info_x, content_y + 100)
	badges_label.size = Vector2(60, 20)
	badges_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	badges_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(badges_label)

	badges_scroll = ScrollContainer.new()
	badges_scroll.position = Vector2(info_x + 70, content_y + 98)
	badges_scroll.size = Vector2(330, 26)
	badges_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	badges_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	badges_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(badges_scroll)

	badges_container = HBoxContainer.new()
	badges_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badges_container.add_theme_constant_override("separation", 6)
	badges_scroll.add_child(badges_container)

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

	# ACTIONS section (right column) - what they did while performing their skill
	var tools_header = Label.new()
	tools_header.text = "-- ACTIONS --"
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

	_update_portrait(profile)

	# Badges
	for child in badges_container.get_children():
		child.queue_free()
	if profile.badges.is_empty():
		var none_label = Label.new()
		none_label.text = "None yet"
		none_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
		none_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
		none_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badges_container.add_child(none_label)
	else:
		for badge_id in profile.badges:
			badges_container.add_child(_create_badge_icon(badge_id))

	# Stats
	tasks_label.text = "Tasks Done: %d" % profile.tasks_completed
	failed_label.text = "Tasks Failed: %d" % profile.tasks_failed
	success_label.text = "Success Rate: %.0f%%" % profile.get_success_rate()
	time_label.text = "Work Time: %.1f hr" % profile.get_work_time_hours()

	# Skills
	_populate_skills(profile)

	# Tools
	_populate_tools(profile)

	# Colleagues
	_populate_colleagues(profile)

func _update_portrait(profile: AgentProfile) -> void:
	if not portrait_layer:
		return
	for child in portrait_layer.get_children():
		child.queue_free()

	var skin_color = SKIN_TONES[profile.skin_color_index % SKIN_TONES.size()]
	var hair_color = HAIR_COLORS[profile.hair_color_index % HAIR_COLORS.size()]

	# Head
	var head = ColorRect.new()
	head.size = Vector2(30, 30)
	head.position = Vector2(25, 28)
	head.color = skin_color
	portrait_layer.add_child(head)

	# Eyes
	var left_eye = ColorRect.new()
	left_eye.size = Vector2(4, 4)
	left_eye.position = Vector2(33, 40)
	left_eye.color = OfficePalette.EYE_COLOR
	portrait_layer.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(4, 4)
	right_eye.position = Vector2(43, 40)
	right_eye.color = OfficePalette.EYE_COLOR
	portrait_layer.add_child(right_eye)

	# Hair (all styles available regardless of clothing)
	_create_portrait_hair(profile.hair_style_index, hair_color)

func _create_badge_icon(badge_id: String) -> Control:
	var info = badge_system.get_badge_info(badge_id) if is_instance_valid(badge_system) else {}
	var icon_text = str(info.get("icon", "*")).strip_edges()
	if icon_text.begins_with("[") and icon_text.ends_with("]") and icon_text.length() >= 3:
		icon_text = icon_text.substr(1, icon_text.length() - 2)

	var badge = Control.new()
	badge.custom_minimum_size = Vector2(22, 22)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP

	# Tooltip with badge name and description
	var badge_name = str(info.get("name", badge_id))
	var badge_desc = str(info.get("description", ""))
	badge.tooltip_text = badge_name + "\n" + badge_desc if badge_desc else badge_name

	var border = ColorRect.new()
	border.size = Vector2(22, 22)
	border.position = Vector2.ZERO
	border.color = OfficePalette.GRUVBOX_YELLOW
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(border)

	var inner = ColorRect.new()
	inner.size = Vector2(20, 20)
	inner.position = Vector2(1, 1)
	inner.color = OfficePalette.GRUVBOX_BG1
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(inner)

	var icon = Label.new()
	icon.text = icon_text
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.position = Vector2(0, 0)
	icon.size = Vector2(22, 22)
	icon.add_theme_font_size_override("font_size", 11)
	icon.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW_BRIGHT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)

	return badge

func _create_portrait_hair(style_index: int, hair_color: Color) -> void:
	match style_index % 4:
		0:  # Short
			var hair = ColorRect.new()
			hair.size = Vector2(34, 10)
			hair.position = Vector2(23, 20)
			hair.color = hair_color
			portrait_layer.add_child(hair)
		1:  # Long
			var hair_top = ColorRect.new()
			hair_top.size = Vector2(36, 12)
			hair_top.position = Vector2(22, 18)
			hair_top.color = hair_color
			portrait_layer.add_child(hair_top)

			var hair_left = ColorRect.new()
			hair_left.size = Vector2(6, 26)
			hair_left.position = Vector2(20, 28)
			hair_left.color = hair_color
			portrait_layer.add_child(hair_left)

			var hair_right = ColorRect.new()
			hair_right.size = Vector2(6, 26)
			hair_right.position = Vector2(54, 28)
			hair_right.color = hair_color
			portrait_layer.add_child(hair_right)
		2:  # Bob
			var hair = ColorRect.new()
			hair.size = Vector2(38, 16)
			hair.position = Vector2(21, 20)
			hair.color = hair_color
			portrait_layer.add_child(hair)

			var hair_sides = ColorRect.new()
			hair_sides.size = Vector2(40, 10)
			hair_sides.position = Vector2(20, 32)
			hair_sides.color = hair_color
			portrait_layer.add_child(hair_sides)
		3:  # Updo
			var hair = ColorRect.new()
			hair.size = Vector2(34, 12)
			hair.position = Vector2(23, 20)
			hair.color = hair_color
			portrait_layer.add_child(hair)

			var bun = ColorRect.new()
			bun.size = Vector2(14, 14)
			bun.position = Vector2(38, 10)
			bun.color = hair_color
			portrait_layer.add_child(bun)

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
		var time_hrs = skill.data.time / 3600.0
		var tooltip = "%s\n%d tasks completed\n%.1f hours worked" % [skill.name, skill.data.tasks, time_hrs]
		var bar = _create_bar(skill.name, skill.data.tasks, max_tasks, OfficePalette.GRUVBOX_GREEN, tooltip)
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
		var tooltip = "%s\nUsed %d times" % [tool.name, tool.count]
		var bar = _create_bar(tool.name, tool.count, max_count, OfficePalette.GRUVBOX_BLUE, tooltip)
		bar.position.y = y
		tools_container.add_child(bar)
		tool_bars.append(bar)
		y += 18

	if sorted_tools.is_empty():
		var empty = Label.new()
		empty.text = "No actions yet"
		empty.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
		empty.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
		tools_container.add_child(empty)

func _create_bar(label_text: String, value: int, max_value: int, color: Color, tooltip: String = "") -> Control:
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(190, 16)
	bar_container.mouse_filter = Control.MOUSE_FILTER_STOP
	if tooltip:
		bar_container.tooltip_text = tooltip

	# Truncate long names
	var display_name = label_text
	if display_name.length() > 12:
		display_name = display_name.substr(0, 10) + ".."

	var label = Label.new()
	label.text = display_name
	label.size = Vector2(80, 16)
	label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(label)

	var bar_width = 80.0 * (float(value) / float(max(1, max_value)))
	var bar = ColorRect.new()
	bar.size = Vector2(max(2, bar_width), 12)
	bar.position = Vector2(85, 2)
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar)

	var count = Label.new()
	count.text = str(value)
	count.position = Vector2(170, 0)
	count.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	count.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(count)

	return bar_container

func _populate_colleagues(profile: AgentProfile) -> void:
	var lines: Array[String] = []

	# Worked with
	if not profile.worked_with.is_empty():
		var worked: Array[String] = []
		for agent_id_str in profile.worked_with.keys():
			var count = profile.worked_with[agent_id_str]
			if is_instance_valid(roster):
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
			if is_instance_valid(roster):
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
	current_profile = null
	close_requested.emit()

func _on_edit_pressed() -> void:
	if current_profile == null:
		return

	# Create appearance editor if needed
	if appearance_editor == null:
		appearance_editor = AppearanceEditorPopup.new()
		appearance_editor.close_requested.connect(_on_appearance_editor_closed)
		appearance_editor.appearance_changed.connect(_on_appearance_changed)
		get_tree().root.add_child(appearance_editor)
		appearance_editor.visible = false

	appearance_editor.show_editor(current_profile)

func _on_appearance_editor_closed() -> void:
	# Appearance editor closed without saving - nothing to do
	pass

func _on_appearance_changed(profile: AgentProfile) -> void:
	# Update the portrait to reflect changes
	_update_portrait(profile)
	# Emit signal so the caller can update the agent visuals and save
	profile_updated.emit(profile)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
