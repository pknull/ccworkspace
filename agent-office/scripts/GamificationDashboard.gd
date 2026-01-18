extends Control
class_name GamificationDashboard

# =============================================================================
# GAMIFICATION DASHBOARD - Statistics Overlay
# =============================================================================
# Full-screen overlay with tabs: Overview, Agent Stable, Achievements

signal close_requested()

# Data sources
var agent_stable: AgentStable
var achievement_system: AchievementSystem

# UI Elements
var background: ColorRect
var panel: ColorRect
var close_button: Button
var tab_buttons: Array[Button] = []
var tab_panels: Array[Control] = []
var current_tab: int = 0

# Agent stable specific
var agent_list: VBoxContainer
var agent_detail_panel: Control
var agent_detail_bg: ColorRect  # Background to preserve when refreshing
var selected_agent_type: String = ""

# Layout constants
const PANEL_WIDTH: float = 900
const PANEL_HEIGHT: float = 550
const PANEL_X: float = (OfficeConstants.SCREEN_WIDTH - PANEL_WIDTH) / 2
const PANEL_Y: float = (OfficeConstants.SCREEN_HEIGHT - PANEL_HEIGHT) / 2 - 20

# Display limits
const MAX_TOP_AGENTS: int = 5
const MAX_TOP_TOOLS: int = 6
const MAX_AGENT_TOOLS_SHOWN: int = 5
const MAX_RELATIONSHIPS_SHOWN: int = 3

# Font sizes
const FONT_SIZE_TITLE: int = 18
const FONT_SIZE_HEADER: int = 14
const FONT_SIZE_SUBHEADER: int = 12
const FONT_SIZE_BODY: int = 11
const FONT_SIZE_SMALL: int = 10
const FONT_SIZE_ICON: int = 16

# Colors
const COLOR_OVERLAY: Color = Color(0, 0, 0, 0.7)
const COLOR_TAB_SELECTED: Color = Color(1.2, 1.2, 0.8)
const COLOR_TAB_NORMAL: Color = Color(1, 1, 1)

func _ready() -> void:
	_create_ui()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			close_requested.emit()
			get_viewport().set_input_as_handled()

func setup(p_agent_stable: AgentStable, p_achievement_system: AchievementSystem) -> void:
	agent_stable = p_agent_stable
	achievement_system = p_achievement_system
	_refresh_content()

func _create_ui() -> void:
	# Full screen size
	size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent background overlay
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.color = COLOR_OVERLAY
	add_child(background)

	# Main panel
	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.position = Vector2(PANEL_X, PANEL_Y)
	panel.color = OfficePalette.GRUVBOX_BG1
	add_child(panel)

	# Panel border
	var border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, PANEL_HEIGHT + 4)
	border.position = Vector2(PANEL_X - 2, PANEL_Y - 2)
	border.color = OfficePalette.GRUVBOX_YELLOW
	border.z_index = -1
	add_child(border)

	# Title
	var title = Label.new()
	title.text = "Agent Office Statistics"
	title.position = Vector2(PANEL_X + 20, PANEL_Y + 15)
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW_BRIGHT)
	add_child(title)

	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(PANEL_X + PANEL_WIDTH - 40, PANEL_Y + 10)
	close_button.size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	add_child(close_button)

	# Tab buttons
	var tab_names = ["Overview", "Agent Stable", "Achievements"]
	var tab_x = PANEL_X + 20
	var tab_y = PANEL_Y + 50

	for i in range(tab_names.size()):
		var btn = Button.new()
		btn.text = tab_names[i]
		btn.position = Vector2(tab_x + i * 140, tab_y)
		btn.size = Vector2(130, 28)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		add_child(btn)
		tab_buttons.append(btn)

	# Tab content area
	var content_y = tab_y + 40

	# Overview tab
	var overview_panel = Control.new()
	overview_panel.position = Vector2(PANEL_X + 20, content_y)
	overview_panel.size = Vector2(PANEL_WIDTH - 40, PANEL_HEIGHT - content_y + PANEL_Y - 20)
	add_child(overview_panel)
	tab_panels.append(overview_panel)

	# Agent Stable tab
	var stable_panel = Control.new()
	stable_panel.position = Vector2(PANEL_X + 20, content_y)
	stable_panel.size = Vector2(PANEL_WIDTH - 40, PANEL_HEIGHT - content_y + PANEL_Y - 20)
	stable_panel.visible = false
	add_child(stable_panel)
	tab_panels.append(stable_panel)

	# Achievements tab
	var achieve_panel = Control.new()
	achieve_panel.position = Vector2(PANEL_X + 20, content_y)
	achieve_panel.size = Vector2(PANEL_WIDTH - 40, PANEL_HEIGHT - content_y + PANEL_Y - 20)
	achieve_panel.visible = false
	add_child(achieve_panel)
	tab_panels.append(achieve_panel)

	_update_tab_buttons()

func _on_tab_pressed(tab_index: int) -> void:
	current_tab = tab_index
	_update_tab_buttons()
	for i in range(tab_panels.size()):
		tab_panels[i].visible = (i == current_tab)
	_refresh_content()

func _update_tab_buttons() -> void:
	for i in range(tab_buttons.size()):
		if i == current_tab:
			tab_buttons[i].modulate = COLOR_TAB_SELECTED
		else:
			tab_buttons[i].modulate = COLOR_TAB_NORMAL

func _on_close_pressed() -> void:
	close_requested.emit()

func refresh() -> void:
	# Public method to refresh dashboard content
	_refresh_content()

func _refresh_content() -> void:
	match current_tab:
		0:
			_populate_overview()
		1:
			_populate_agent_stable()
		2:
			_populate_achievements()

# =============================================================================
# OVERVIEW TAB
# =============================================================================

func _populate_overview() -> void:
	var tab_content = tab_panels[0]

	# Clear existing content
	for child in tab_content.get_children():
		child.queue_free()

	if not agent_stable or not achievement_system:
		return

	var y_offset = 10

	# Global stats section
	var stats_header = _create_section_header("Global Statistics")
	stats_header.position.y = y_offset
	tab_content.add_child(stats_header)
	y_offset += 35

	var total_tasks = agent_stable.get_total_tasks_completed()
	var total_time = agent_stable.get_total_work_time()
	var total_agents = agent_stable.get_agent_count()

	var stats_text = "Total Tasks Completed: %d\n" % total_tasks
	stats_text += "Total Work Time: %s\n" % _format_time(total_time)
	stats_text += "Unique Agent Types: %d\n" % total_agents
	stats_text += "Achievements: %d / %d (%.0f%%)" % [
		achievement_system.get_unlocked_count(),
		achievement_system.get_total_count(),
		achievement_system.get_progress_percent()
	]

	var stats_label = _create_text_label(stats_text)
	stats_label.position.y = y_offset
	tab_content.add_child(stats_label)
	y_offset += 100

	# Top agents section
	var top_header = _create_section_header("Top Performers")
	top_header.position.y = y_offset
	tab_content.add_child(top_header)
	y_offset += 35

	var top_agents = agent_stable.get_top_agents_by_tasks(MAX_TOP_AGENTS)
	if top_agents.is_empty():
		var no_data = _create_text_label("No agent data yet. Start using agents to see stats!")
		no_data.position.y = y_offset
		tab_content.add_child(no_data)
	else:
		var top_text = ""
		for i in range(top_agents.size()):
			var agent = top_agents[i]
			top_text += "%d. %s - %d tasks\n" % [i + 1, agent.display_name, agent.tasks_completed]

		var top_label = _create_text_label(top_text)
		top_label.position.y = y_offset
		tab_content.add_child(top_label)
	y_offset += 130

	# Tool usage section
	var tools_header = _create_section_header("Tool Usage")
	tools_header.position.y = y_offset
	tab_content.add_child(tools_header)
	y_offset += 35

	var tool_stats = agent_stable.get_tool_usage_stats()
	if tool_stats.is_empty():
		var no_tools = _create_text_label("No tool usage recorded yet.")
		no_tools.position.y = y_offset
		tab_content.add_child(no_tools)
	else:
		# Sort by usage count
		var sorted_tools = tool_stats.keys()
		sorted_tools.sort_custom(func(a, b): return tool_stats[a] > tool_stats[b])

		var tools_text = ""
		for i in range(mini(sorted_tools.size(), MAX_TOP_TOOLS)):
			var tool_name = sorted_tools[i]
			tools_text += "%s: %d uses\n" % [tool_name, tool_stats[tool_name]]

		var tools_label = _create_text_label(tools_text)
		tools_label.position.y = y_offset
		tab_content.add_child(tools_label)

# =============================================================================
# AGENT STABLE TAB
# =============================================================================

func _populate_agent_stable() -> void:
	var tab_content = tab_panels[1]

	# Clear existing content
	for child in tab_content.get_children():
		child.queue_free()

	if not agent_stable:
		return

	# Left side: agent list (scrollable)
	var list_bg = ColorRect.new()
	list_bg.size = Vector2(260, 400)
	list_bg.color = OfficePalette.GRUVBOX_BG2
	tab_content.add_child(list_bg)

	var list_header = Label.new()
	list_header.text = "Agent Roster"
	list_header.position = Vector2(10, 5)
	list_header.add_theme_font_size_override("font_size", FONT_SIZE_SUBHEADER)
	list_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW_BRIGHT)
	tab_content.add_child(list_header)

	# ScrollContainer for agent list
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 30)
	scroll.size = Vector2(260, 370)
	tab_content.add_child(scroll)

	agent_list = VBoxContainer.new()
	agent_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(agent_list)

	var agents = agent_stable.get_all_agents()
	agents.sort_custom(func(a, b): return a.tasks_completed > b.tasks_completed)

	for agent in agents:
		var btn = Button.new()
		btn.text = "%s (%d)" % [agent.display_name, agent.tasks_completed]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 28
		btn.pressed.connect(_on_agent_selected.bind(agent.agent_type))
		agent_list.add_child(btn)

	if agents.is_empty():
		var no_agents = Label.new()
		no_agents.text = "No agents yet!\nStart working to build\nyour roster."
		no_agents.position = Vector2(20, 60)
		no_agents.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
		no_agents.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
		tab_content.add_child(no_agents)

	# Right side: agent detail panel
	agent_detail_panel = Control.new()
	agent_detail_panel.position = Vector2(280, 0)
	agent_detail_panel.size = Vector2(580, 400)
	tab_content.add_child(agent_detail_panel)

	agent_detail_bg = ColorRect.new()
	agent_detail_bg.size = Vector2(580, 400)
	agent_detail_bg.color = OfficePalette.GRUVBOX_BG
	agent_detail_panel.add_child(agent_detail_bg)

	# Show first agent by default if we have one
	if not agents.is_empty():
		_show_agent_detail(agents[0].agent_type)
	else:
		var placeholder = Label.new()
		placeholder.text = "Select an agent to view details"
		placeholder.position = Vector2(180, 180)
		placeholder.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
		placeholder.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
		agent_detail_panel.add_child(placeholder)

func _on_agent_selected(agent_type: String) -> void:
	_show_agent_detail(agent_type)

func _show_agent_detail(agent_type: String) -> void:
	if not agent_detail_panel:
		return

	# Clear existing detail content (keep background)
	for child in agent_detail_panel.get_children():
		if child != agent_detail_bg:
			child.queue_free()

	var record = agent_stable.get_agent(agent_type)
	if not record:
		return

	selected_agent_type = agent_type

	var y = 15

	# Agent name header
	var name_label = Label.new()
	name_label.text = record.display_name
	name_label.position = Vector2(20, y)
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_ICON)
	name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW_BRIGHT)
	agent_detail_panel.add_child(name_label)
	y += 35

	# Type (grayed)
	var type_label = Label.new()
	type_label.text = "Type: %s" % agent_type
	type_label.position = Vector2(20, y)
	type_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	type_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	agent_detail_panel.add_child(type_label)
	y += 25

	# Stats
	var stats_text = ""
	stats_text += "Tasks Completed: %d\n" % record.tasks_completed
	stats_text += "Tasks Failed: %d\n" % record.tasks_failed
	stats_text += "Total Work Time: %s\n" % _format_time(record.total_work_time_seconds)
	stats_text += "Sessions: %d\n" % record.session_count
	stats_text += "First Seen: %s\n" % _format_date(record.first_seen)
	stats_text += "Last Seen: %s" % _format_date(record.last_seen)

	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(20, y)
	stats_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	stats_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	agent_detail_panel.add_child(stats_label)
	y += 130

	# Tools used
	if not record.tools_used.is_empty():
		var tools_header = Label.new()
		tools_header.text = "Tools Used:"
		tools_header.position = Vector2(20, y)
		tools_header.add_theme_font_size_override("font_size", FONT_SIZE_SUBHEADER)
		tools_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_AQUA_BRIGHT)
		agent_detail_panel.add_child(tools_header)
		y += 22

		var sorted_tools = record.tools_used.keys()
		sorted_tools.sort_custom(func(a, b): return record.tools_used[a] > record.tools_used[b])

		var displayed_tools_count = mini(sorted_tools.size(), MAX_AGENT_TOOLS_SHOWN)
		var tools_text = ""
		for tool_name in sorted_tools.slice(0, MAX_AGENT_TOOLS_SHOWN):
			tools_text += "  %s: %d\n" % [tool_name, record.tools_used[tool_name]]

		var tools_label = Label.new()
		tools_label.text = tools_text
		tools_label.position = Vector2(20, y)
		tools_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
		tools_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT2)
		agent_detail_panel.add_child(tools_label)
		y += displayed_tools_count * 16 + 15

	# Relationships
	if not record.worked_with.is_empty() or not record.chatted_with.is_empty():
		var rel_header = Label.new()
		rel_header.text = "Relationships:"
		rel_header.position = Vector2(20, y)
		rel_header.add_theme_font_size_override("font_size", FONT_SIZE_SUBHEADER)
		rel_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_PURPLE_BRIGHT)
		agent_detail_panel.add_child(rel_header)
		y += 22

		# Combine worked with and chatted with
		var rel_text = ""
		var worked_count = 0
		for other_type in record.worked_with.keys():
			if worked_count >= MAX_RELATIONSHIPS_SHOWN:
				break
			var other_name = _get_agent_display_name(other_type)
			rel_text += "  Worked with %s (%d times)\n" % [other_name, record.worked_with[other_type]]
			worked_count += 1

		var chat_count = 0
		for other_type in record.chatted_with.keys():
			if chat_count >= MAX_RELATIONSHIPS_SHOWN:
				break
			var other_name = _get_agent_display_name(other_type)
			rel_text += "  Chatted with %s (%d times)\n" % [other_name, record.chatted_with[other_type]]
			chat_count += 1

		if rel_text:
			var rel_label = Label.new()
			rel_label.text = rel_text
			rel_label.position = Vector2(20, y)
			rel_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
			rel_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT2)
			agent_detail_panel.add_child(rel_label)

# =============================================================================
# ACHIEVEMENTS TAB
# =============================================================================

func _populate_achievements() -> void:
	var tab_content = tab_panels[2]

	# Clear existing content
	for child in tab_content.get_children():
		child.queue_free()

	if not achievement_system:
		return

	var y_offset = 10

	# Progress header
	var progress_text = "Progress: %d / %d (%.0f%%)" % [
		achievement_system.get_unlocked_count(),
		achievement_system.get_total_count(),
		achievement_system.get_progress_percent()
	]

	var progress_label = Label.new()
	progress_label.text = progress_text
	progress_label.position = Vector2(0, y_offset)
	progress_label.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	progress_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW_BRIGHT)
	tab_content.add_child(progress_label)
	y_offset += 35

	# ScrollContainer for achievements
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(0, y_offset)
	scroll.size = Vector2(860, 360)
	tab_content.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Group by category (using centralized definitions from AchievementSystem)
	for category in AchievementSystem.CATEGORY_ORDER:
		var cat_achievements = achievement_system.get_achievements_by_category(category)
		if cat_achievements.is_empty():
			continue

		# Category header
		var cat_header = Label.new()
		cat_header.text = "-- %s --" % AchievementSystem.CATEGORY_NAMES.get(category, category)
		cat_header.add_theme_font_size_override("font_size", FONT_SIZE_SUBHEADER)
		cat_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_AQUA_BRIGHT)
		vbox.add_child(cat_header)

		# Achievement items
		for achievement in cat_achievements:
			var item = _create_achievement_item(achievement)
			vbox.add_child(item)

		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size.y = 15
		vbox.add_child(spacer)

func _create_achievement_item(achievement: AchievementSystem.Achievement) -> Control:
	var item = HBoxContainer.new()
	item.custom_minimum_size.y = 36

	# Icon
	var icon = Label.new()
	icon.text = achievement.icon
	icon.custom_minimum_size.x = 40
	icon.add_theme_font_size_override("font_size", FONT_SIZE_ICON)
	if achievement.is_unlocked:
		icon.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW_BRIGHT)
	else:
		icon.add_theme_color_override("font_color", OfficePalette.GRUVBOX_BG4)
	item.add_child(icon)

	# Text container
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = achievement.name
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_SUBHEADER)
	if achievement.is_unlocked:
		name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	else:
		name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	text_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = achievement.description
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	desc_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GRAY)
	text_vbox.add_child(desc_label)

	item.add_child(text_vbox)

	# Status
	var status = Label.new()
	if achievement.is_unlocked:
		status.text = "Unlocked"
		status.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GREEN_BRIGHT)
	else:
		status.text = "Locked"
		status.add_theme_color_override("font_color", OfficePalette.GRUVBOX_RED)
	status.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	status.custom_minimum_size.x = 70
	item.add_child(status)

	return item

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _create_section_header(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_AQUA_BRIGHT)
	return label

func _create_text_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	return label

func _format_time(seconds: float) -> String:
	var hours = int(seconds / 3600)
	var minutes = int(fmod(seconds, 3600) / 60)
	var secs = int(fmod(seconds, 60))

	if hours > 0:
		return "%dh %dm %ds" % [hours, minutes, secs]
	elif minutes > 0:
		return "%dm %ds" % [minutes, secs]
	else:
		return "%ds" % secs

func _format_date(iso_string: String) -> String:
	if iso_string.is_empty():
		return "Unknown"
	# Just return the date part
	if "T" in iso_string:
		return iso_string.split("T")[0]
	return iso_string

func _get_agent_display_name(agent_type: String) -> String:
	if agent_stable:
		var other_record = agent_stable.get_agent(agent_type)
		if other_record:
			return other_record.display_name
	# Fallback: use the shared display name generator
	return AgentStable.AgentRecord._generate_display_name(agent_type)
