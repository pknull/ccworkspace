extends Node2D
class_name RosterClipboard

# =============================================================================
# ROSTER CLIPBOARD - Wall Decoration Showing Agent Rankings
# =============================================================================
# Displays a ranking of agents on a clipboard attached to the wall.
# Clicking opens the full roster popup, clicking an agent shows their profile.

signal clicked()

# Visual elements
var clipboard_bg: ColorRect
var clipboard_clip: ColorRect
var paper: ColorRect
var title_label: Label
var rank_labels: Array[Label] = []
var rank_bars: Array[ColorRect] = []

# Data
var roster: AgentRoster = null
var displayed_agents: Array[AgentProfile] = []

# Layout - sized to fit on the wall (wall height ~68px)
const CLIPBOARD_WIDTH: float = 45
const CLIPBOARD_HEIGHT: float = 55
const MAX_DISPLAY: int = 3
const ROW_HEIGHT: int = 10

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	# Clipboard backing
	clipboard_bg = ColorRect.new()
	clipboard_bg.size = Vector2(CLIPBOARD_WIDTH, CLIPBOARD_HEIGHT)
	clipboard_bg.position = Vector2(-CLIPBOARD_WIDTH / 2, -CLIPBOARD_HEIGHT / 2)
	clipboard_bg.color = OfficePalette.WOOD_FRAME
	add_child(clipboard_bg)

	# Metal clip at top
	clipboard_clip = ColorRect.new()
	clipboard_clip.size = Vector2(16, 6)
	clipboard_clip.position = Vector2(-8, -CLIPBOARD_HEIGHT / 2 - 3)
	clipboard_clip.color = OfficePalette.METAL_GRAY
	add_child(clipboard_clip)

	# Clip highlight
	var clip_highlight = ColorRect.new()
	clip_highlight.size = Vector2(14, 2)
	clip_highlight.position = Vector2(-7, -CLIPBOARD_HEIGHT / 2 - 2)
	clip_highlight.color = OfficePalette.METAL_GRAY_LIGHT
	add_child(clip_highlight)

	# Paper
	paper = ColorRect.new()
	paper.size = Vector2(CLIPBOARD_WIDTH - 6, CLIPBOARD_HEIGHT - 8)
	paper.position = Vector2(-CLIPBOARD_WIDTH / 2 + 3, -CLIPBOARD_HEIGHT / 2 + 5)
	paper.color = OfficePalette.GRUVBOX_LIGHT
	add_child(paper)

	# Title
	title_label = Label.new()
	title_label.text = "TOP"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(-CLIPBOARD_WIDTH / 2 + 3, -CLIPBOARD_HEIGHT / 2 + 6)
	title_label.size = Vector2(CLIPBOARD_WIDTH - 6, 10)
	title_label.add_theme_font_size_override("font_size", 7)
	title_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	add_child(title_label)

	# Underline
	var underline = ColorRect.new()
	underline.size = Vector2(25, 1)
	underline.position = Vector2(-12, -CLIPBOARD_HEIGHT / 2 + 16)
	underline.color = OfficePalette.UI_TEXT_DARK
	add_child(underline)

	# Create rank display rows (simplified - just numbers)
	var start_y = -CLIPBOARD_HEIGHT / 2 + 19
	for i in range(MAX_DISPLAY):
		var y = start_y + i * ROW_HEIGHT

		# XP bar (hidden at this size)
		var bar = ColorRect.new()
		bar.size = Vector2(1, 1)
		bar.visible = false
		add_child(bar)
		rank_bars.append(bar)

		# Rank + Name label
		var label = Label.new()
		label.text = ""
		label.position = Vector2(-CLIPBOARD_WIDTH / 2 + 4, y)
		label.size = Vector2(CLIPBOARD_WIDTH - 8, ROW_HEIGHT)
		label.add_theme_font_size_override("font_size", 6)
		label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
		add_child(label)
		rank_labels.append(label)

func setup(agent_roster: AgentRoster) -> void:
	roster = agent_roster
	roster.roster_changed.connect(_on_roster_changed)
	refresh_display()

func _on_roster_changed() -> void:
	# Guard against updates during shutdown
	if not is_inside_tree():
		return
	refresh_display()

func refresh_display() -> void:
	if roster == null:
		return

	displayed_agents = roster.get_agents_sorted_by_xp()

	for i in range(MAX_DISPLAY):
		if i < displayed_agents.size():
			var agent = displayed_agents[i]
			# Truncate name to fit small space
			var short_name = agent.agent_name.substr(0, 5)
			rank_labels[i].text = "%d.%s" % [i + 1, short_name]
		else:
			rank_labels[i].text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = get_local_mouse_position()
			var click_rect = Rect2(-CLIPBOARD_WIDTH / 2, -CLIPBOARD_HEIGHT / 2, CLIPBOARD_WIDTH, CLIPBOARD_HEIGHT)
			if click_rect.has_point(local_pos):
				clicked.emit()
