extends RefCounted
class_name AgentVisuals

# =============================================================================
# AGENT VISUALS
# =============================================================================
# Handles all visual creation and appearance for agents.
# Extracted from Agent.gd for better maintainability.

# Reference to parent agent
var agent: Node2D

# Visual nodes - accessible by Agent for animations
var body: ColorRect = null
var head: ColorRect = null
var hair: ColorRect = null
var tie: ColorRect = null

# UI nodes
var type_label: Label = null
var status_label: Label = null
var tool_label: Label = null
var tool_bg: ColorRect = null
var tooltip_panel: PanelContainer = null
var tooltip_label: Label = null
var tooltip_header: Label = null
var tooltip_subtitle: Label = null

# Appearance state
var is_female: bool = false  # true = blouse, false = shirt+tie
var hair_color: Color = OfficePalette.HAIR_BROWN
var skin_color: Color = OfficePalette.SKIN_LIGHT
var hair_style_index: int = 0
var blouse_color_index: int = 0  # top color index
var bottom_type: int = 0  # 0 = pants, 1 = skirt
var bottom_color_index: int = 0
var appearance_applied: bool = false
var _visuals_created: bool = false

# Hover state
var is_hovered: bool = false

# Palettes
const HAIR_COLORS: Array[Color] = [
	OfficePalette.HAIR_BROWN,
	OfficePalette.HAIR_BLACK,
	OfficePalette.HAIR_AUBURN,
	OfficePalette.HAIR_BLONDE,
	OfficePalette.HAIR_DARK_BROWN,
	OfficePalette.HAIR_VERY_DARK,
]

const SKIN_TONES: Array[Color] = [
	OfficePalette.SKIN_LIGHT,
	OfficePalette.SKIN_MEDIUM,
	OfficePalette.SKIN_TAN,
	OfficePalette.SKIN_DARK,
	OfficePalette.SKIN_VERY_LIGHT,
]

const BLOUSE_COLORS: Array[Color] = [
	OfficePalette.AGENT_SHIRT_WHITE,
	OfficePalette.AGENT_BLOUSE_PINK,
	OfficePalette.AGENT_BLOUSE_BLUE,
	OfficePalette.AGENT_BLOUSE_LAVENDER,
]

func _init(p_agent: Node2D) -> void:
	agent = p_agent

func create_visuals() -> void:
	_ensure_ui_nodes()
	is_female = randf() < 0.5
	hair_color = HAIR_COLORS[randi() % HAIR_COLORS.size()]
	skin_color = SKIN_TONES[randi() % SKIN_TONES.size()]
	hair_style_index = randi() % 3
	blouse_color_index = randi() % 4

	if is_female:
		_create_female_visuals(skin_color)
	else:
		_create_male_visuals(skin_color)
	_visuals_created = true

func _ensure_ui_nodes() -> void:
	if type_label:
		return

	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.position = Vector2(-40, -55)
	type_label.size = Vector2(80, 16)
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_GRAY)
	type_label.visible = false
	agent.add_child(type_label)

	var status_bg = ColorRect.new()
	status_bg.name = "StatusBg"
	status_bg.size = Vector2(120, 16)
	status_bg.position = Vector2(-60, -72)
	status_bg.color = OfficePalette.UI_BG_DARK
	status_bg.visible = false
	agent.add_child(status_bg)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(-60, -73)
	status_label.size = Vector2(120, 16)
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_LIGHT)
	status_label.visible = false
	agent.add_child(status_label)

	tool_bg = ColorRect.new()
	tool_bg.size = Vector2(32, 20)
	tool_bg.position = Vector2(18, -30)
	tool_bg.color = OfficePalette.UI_BG_DARKER
	tool_bg.visible = false
	agent.add_child(tool_bg)

	tool_label = Label.new()
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tool_label.position = Vector2(18, -30)
	tool_label.size = Vector2(32, 20)
	tool_label.add_theme_font_size_override("font_size", 12)
	tool_label.visible = false
	agent.add_child(tool_label)

	_create_tooltip()

func _create_tooltip() -> void:
	# Use a PanelContainer for auto-sizing
	tooltip_panel = PanelContainer.new()
	tooltip_panel.position = Vector2(30, -60)
	tooltip_panel.visible = false
	tooltip_panel.z_index = OfficeConstants.Z_UI_TOOLTIP
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = OfficePalette.GRUVBOX_LIGHT
	style.border_color = OfficePalette.TOOLTIP_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(6)
	tooltip_panel.add_theme_stylebox_override("panel", style)
	agent.add_child(tooltip_panel)

	# VBox for content - auto-sizes to fit children
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	tooltip_panel.add_child(vbox)

	# Agent name (header)
	tooltip_header = Label.new()
	tooltip_header.add_theme_font_size_override("font_size", 11)
	tooltip_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_BG)
	tooltip_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tooltip_header)

	# Role/level (subtitle)
	tooltip_subtitle = Label.new()
	tooltip_subtitle.add_theme_font_size_override("font_size", 9)
	tooltip_subtitle.add_theme_color_override("font_color", OfficePalette.GRUVBOX_BG2)
	tooltip_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tooltip_subtitle)

	# Divider
	var divider = ColorRect.new()
	divider.custom_minimum_size = Vector2(60, 1)
	divider.color = OfficePalette.TOOLTIP_DIVIDER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	# Status/task text
	tooltip_label = Label.new()
	tooltip_label.add_theme_font_size_override("font_size", 9)
	tooltip_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tooltip_label)

func _create_male_visuals(p_skin_color: Color) -> void:
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	agent.add_child(shadow)

	var left_leg = ColorRect.new()
	left_leg.size = Vector2(10, 18)
	left_leg.position = Vector2(-12, 15)
	left_leg.color = OfficePalette.AGENT_TROUSERS_DARK
	agent.add_child(left_leg)

	var right_leg = ColorRect.new()
	right_leg.size = Vector2(10, 18)
	right_leg.position = Vector2(2, 15)
	right_leg.color = OfficePalette.AGENT_TROUSERS_DARK
	agent.add_child(right_leg)

	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = OfficePalette.AGENT_SHIRT_WHITE
	body.z_index = 0
	agent.add_child(body)

	var collar_left = ColorRect.new()
	collar_left.size = Vector2(8, 6)
	collar_left.position = Vector2(-11, -15)
	collar_left.color = OfficePalette.AGENT_SHIRT_WHITE
	agent.add_child(collar_left)

	var collar_right = ColorRect.new()
	collar_right.size = Vector2(8, 6)
	collar_right.position = Vector2(3, -15)
	collar_right.color = OfficePalette.AGENT_SHIRT_WHITE
	agent.add_child(collar_right)

	var tie_color = Agent.get_agent_color(agent.agent_type)
	tie = ColorRect.new()
	tie.size = Vector2(6, 22)
	tie.position = Vector2(-3, -12)
	tie.color = tie_color
	tie.z_index = 1
	agent.add_child(tie)

	var tie_knot = ColorRect.new()
	tie_knot.name = "TieKnot"
	tie_knot.size = Vector2(8, 5)
	tie_knot.position = Vector2(-4, -15)
	tie_knot.color = tie_color.darkened(0.1)
	tie_knot.z_index = 1
	agent.add_child(tie_knot)

	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = p_skin_color
	head.z_index = 2
	agent.add_child(head)

	hair = ColorRect.new()
	hair.size = Vector2(20, 8)
	hair.position = Vector2(-1, -5)
	hair.color = hair_color
	head.add_child(hair)

	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(3, 5)
	left_eye.color = OfficePalette.EYE_COLOR
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)
	right_eye.color = OfficePalette.EYE_COLOR
	head.add_child(right_eye)

func _create_female_visuals(p_skin_color: Color) -> void:
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	agent.add_child(shadow)

	var wears_skirt = randi() % 2 == 0

	if wears_skirt:
		var skirt = ColorRect.new()
		skirt.size = Vector2(28, 14)
		skirt.position = Vector2(-14, 10)
		skirt.color = OfficePalette.AGENT_SKIRT_DARK
		agent.add_child(skirt)

		var left_leg = ColorRect.new()
		left_leg.size = Vector2(8, 10)
		left_leg.position = Vector2(-10, 22)
		left_leg.color = p_skin_color.darkened(0.1)
		agent.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(8, 10)
		right_leg.position = Vector2(2, 22)
		right_leg.color = p_skin_color.darkened(0.1)
		agent.add_child(right_leg)
	else:
		var left_leg = ColorRect.new()
		left_leg.size = Vector2(10, 18)
		left_leg.position = Vector2(-12, 15)
		left_leg.color = OfficePalette.AGENT_SKIRT_DARK
		agent.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(10, 18)
		right_leg.position = Vector2(2, 15)
		right_leg.color = OfficePalette.AGENT_SKIRT_DARK
		agent.add_child(right_leg)

	var blouse_color = BLOUSE_COLORS[randi() % BLOUSE_COLORS.size()]

	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = blouse_color
	body.z_index = 0
	agent.add_child(body)

	var collar = ColorRect.new()
	collar.size = Vector2(18, 6)
	collar.position = Vector2(-9, -17)
	collar.color = blouse_color
	agent.add_child(collar)

	tie = null

	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = p_skin_color
	head.z_index = 2
	agent.add_child(head)

	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(3, 5)
	left_eye.color = OfficePalette.EYE_COLOR
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)
	right_eye.color = OfficePalette.EYE_COLOR
	head.add_child(right_eye)

	_create_female_hair(hair_style_index)

func _create_female_hair(style: int) -> void:
	match style % 3:
		0:
			hair = ColorRect.new()
			hair.size = Vector2(24, 12)
			hair.position = Vector2(-3, -7)
			hair.color = hair_color
			head.add_child(hair)

			var hair_left = ColorRect.new()
			hair_left.size = Vector2(6, 18)
			hair_left.position = Vector2(-5, -1)
			hair_left.color = hair_color
			head.add_child(hair_left)

			var hair_right = ColorRect.new()
			hair_right.size = Vector2(6, 18)
			hair_right.position = Vector2(17, -1)
			hair_right.color = hair_color
			head.add_child(hair_right)
		1:
			hair = ColorRect.new()
			hair.size = Vector2(26, 14)
			hair.position = Vector2(-4, -9)
			hair.color = hair_color
			head.add_child(hair)

			var hair_sides = ColorRect.new()
			hair_sides.size = Vector2(28, 8)
			hair_sides.position = Vector2(-5, 1)
			hair_sides.color = hair_color
			head.add_child(hair_sides)
		2:
			hair = ColorRect.new()
			hair.size = Vector2(22, 10)
			hair.position = Vector2(-2, -8)
			hair.color = hair_color
			head.add_child(hair)

			var bun = ColorRect.new()
			bun.size = Vector2(10, 10)
			bun.position = Vector2(4, -15)
			bun.color = hair_color
			head.add_child(bun)

func apply_profile_appearance(profile) -> void:
	_apply_appearance_values(profile.is_female, profile.hair_color_index, profile.skin_color_index, profile.hair_style_index, profile.blouse_color_index, profile.bottom_type, profile.bottom_color_index)

func refresh_appearance(profile) -> void:
	# Force re-apply appearance (used when profile is edited)
	appearance_applied = false
	_clear_visual_nodes()
	_apply_appearance_values(profile.is_female, profile.hair_color_index, profile.skin_color_index, profile.hair_style_index, profile.blouse_color_index, profile.bottom_type, profile.bottom_color_index)

func _apply_appearance_values(p_is_female: bool, p_hair_index: int, p_skin_index: int, p_hair_style: int, p_blouse_color: int, p_bottom_type: int = 0, p_bottom_color: int = 0) -> void:
	if appearance_applied:
		return
	appearance_applied = true
	_ensure_ui_nodes()

	if _visuals_created:
		_clear_visual_nodes()

	is_female = p_is_female
	hair_color = HAIR_COLORS[p_hair_index % HAIR_COLORS.size()]
	skin_color = SKIN_TONES[p_skin_index % SKIN_TONES.size()]
	hair_style_index = p_hair_style
	blouse_color_index = p_blouse_color
	bottom_type = p_bottom_type
	bottom_color_index = p_bottom_color

	if is_female:
		_create_female_visuals_persistent(skin_color, hair_color, hair_style_index, blouse_color_index, bottom_type)
	else:
		_create_male_visuals_persistent(skin_color, hair_color, hair_style_index, bottom_type)
	_visuals_created = true

func _create_male_visuals_persistent(p_skin_color: Color, p_hair_color: Color, p_hair_style: int = 0, p_bottom_type: int = 0) -> void:
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	agent.add_child(shadow)

	var wears_skirt = (p_bottom_type == 1)

	if wears_skirt:
		var skirt = ColorRect.new()
		skirt.size = Vector2(28, 14)
		skirt.position = Vector2(-14, 10)
		skirt.color = OfficePalette.AGENT_SKIRT_DARK
		agent.add_child(skirt)

		var left_leg = ColorRect.new()
		left_leg.size = Vector2(8, 10)
		left_leg.position = Vector2(-10, 22)
		left_leg.color = p_skin_color.darkened(0.1)
		agent.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(8, 10)
		right_leg.position = Vector2(2, 22)
		right_leg.color = p_skin_color.darkened(0.1)
		agent.add_child(right_leg)
	else:
		var left_leg = ColorRect.new()
		left_leg.size = Vector2(10, 18)
		left_leg.position = Vector2(-12, 15)
		left_leg.color = OfficePalette.AGENT_TROUSERS_DARK
		agent.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(10, 18)
		right_leg.position = Vector2(2, 15)
		right_leg.color = OfficePalette.AGENT_TROUSERS_DARK
		agent.add_child(right_leg)

	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = OfficePalette.AGENT_SHIRT_WHITE
	body.z_index = 0
	agent.add_child(body)

	var collar_left = ColorRect.new()
	collar_left.size = Vector2(8, 6)
	collar_left.position = Vector2(-11, -15)
	collar_left.color = OfficePalette.AGENT_SHIRT_WHITE
	agent.add_child(collar_left)

	var collar_right = ColorRect.new()
	collar_right.size = Vector2(8, 6)
	collar_right.position = Vector2(3, -15)
	collar_right.color = OfficePalette.AGENT_SHIRT_WHITE
	agent.add_child(collar_right)

	var tie_color = Agent.get_agent_color(agent.agent_type)
	tie = ColorRect.new()
	tie.size = Vector2(6, 22)
	tie.position = Vector2(-3, -12)
	tie.color = tie_color
	tie.z_index = 1
	agent.add_child(tie)

	var tie_knot = ColorRect.new()
	tie_knot.name = "TieKnot"
	tie_knot.size = Vector2(8, 5)
	tie_knot.position = Vector2(-4, -15)
	tie_knot.color = tie_color.darkened(0.1)
	tie_knot.z_index = 1
	agent.add_child(tie_knot)

	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = p_skin_color
	head.z_index = 2
	agent.add_child(head)

	# Hair (all 4 styles available)
	_create_agent_hair(p_hair_style, p_hair_color)

	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(3, 5)
	left_eye.color = OfficePalette.EYE_COLOR
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)
	right_eye.color = OfficePalette.EYE_COLOR
	head.add_child(right_eye)

func _create_female_visuals_persistent(p_skin_color: Color, p_hair_color: Color, p_hair_style: int, p_blouse_index: int, p_bottom_type: int = 0) -> void:
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	agent.add_child(shadow)

	var wears_skirt = (p_bottom_type == 1)

	if wears_skirt:
		var skirt = ColorRect.new()
		skirt.size = Vector2(28, 14)
		skirt.position = Vector2(-14, 10)
		skirt.color = OfficePalette.AGENT_SKIRT_DARK
		agent.add_child(skirt)

		var left_leg = ColorRect.new()
		left_leg.size = Vector2(8, 10)
		left_leg.position = Vector2(-10, 22)
		left_leg.color = p_skin_color.darkened(0.1)
		agent.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(8, 10)
		right_leg.position = Vector2(2, 22)
		right_leg.color = p_skin_color.darkened(0.1)
		agent.add_child(right_leg)
	else:
		var left_leg = ColorRect.new()
		left_leg.size = Vector2(10, 18)
		left_leg.position = Vector2(-12, 15)
		left_leg.color = OfficePalette.AGENT_SKIRT_DARK
		agent.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(10, 18)
		right_leg.position = Vector2(2, 15)
		right_leg.color = OfficePalette.AGENT_SKIRT_DARK
		agent.add_child(right_leg)

	var blouse_color = BLOUSE_COLORS[p_blouse_index % BLOUSE_COLORS.size()]

	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = blouse_color
	body.z_index = 0
	agent.add_child(body)

	var collar = ColorRect.new()
	collar.size = Vector2(18, 6)
	collar.position = Vector2(-9, -17)
	collar.color = blouse_color
	agent.add_child(collar)

	tie = null

	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = p_skin_color
	head.z_index = 2
	agent.add_child(head)

	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(3, 5)
	left_eye.color = OfficePalette.EYE_COLOR
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)
	right_eye.color = OfficePalette.EYE_COLOR
	head.add_child(right_eye)

	# Hair (all 4 styles available)
	_create_agent_hair(p_hair_style, p_hair_color)

func _create_agent_hair(style: int, hair_color: Color) -> void:
	# Shared hair creation for all agents - 4 styles: Short, Long, Bob, Updo
	match style % 4:
		0:  # Short
			hair = ColorRect.new()
			hair.size = Vector2(20, 8)
			hair.position = Vector2(-1, -5)
			hair.color = hair_color
			head.add_child(hair)
		1:  # Long
			hair = ColorRect.new()
			hair.size = Vector2(24, 12)
			hair.position = Vector2(-3, -7)
			hair.color = hair_color
			head.add_child(hair)

			var hair_left = ColorRect.new()
			hair_left.size = Vector2(6, 18)
			hair_left.position = Vector2(-5, -1)
			hair_left.color = hair_color
			head.add_child(hair_left)

			var hair_right = ColorRect.new()
			hair_right.size = Vector2(6, 18)
			hair_right.position = Vector2(17, -1)
			hair_right.color = hair_color
			head.add_child(hair_right)
		2:  # Bob
			hair = ColorRect.new()
			hair.size = Vector2(26, 14)
			hair.position = Vector2(-4, -9)
			hair.color = hair_color
			head.add_child(hair)

			var hair_sides = ColorRect.new()
			hair_sides.size = Vector2(28, 8)
			hair_sides.position = Vector2(-5, 1)
			hair_sides.color = hair_color
			head.add_child(hair_sides)
		3:  # Updo
			hair = ColorRect.new()
			hair.size = Vector2(22, 10)
			hair.position = Vector2(-2, -8)
			hair.color = hair_color
			head.add_child(hair)

			var bun = ColorRect.new()
			bun.size = Vector2(10, 10)
			bun.position = Vector2(4, -15)
			bun.color = hair_color
			head.add_child(bun)

func _clear_visual_nodes() -> void:
	var preserve_nodes: Array[Node] = []
	if status_label and is_instance_valid(status_label):
		preserve_nodes.append(status_label)
	if type_label and is_instance_valid(type_label):
		preserve_nodes.append(type_label)
	if tool_label and is_instance_valid(tool_label):
		preserve_nodes.append(tool_label)
	if tool_bg and is_instance_valid(tool_bg):
		preserve_nodes.append(tool_bg)
	if tooltip_panel and is_instance_valid(tooltip_panel):
		preserve_nodes.append(tooltip_panel)

	var status_bg = agent.get_node_or_null("StatusBg")
	if status_bg:
		preserve_nodes.append(status_bg)

	for child in agent.get_children():
		if child not in preserve_nodes:
			child.queue_free()

	body = null
	head = null
	hair = null
	tie = null

func update_appearance(agent_type: String) -> void:
	var color = Agent.get_agent_color(agent_type)
	if tie:
		tie.color = color
	var tie_knot_node = agent.get_node_or_null("TieKnot")
	if tie_knot_node:
		tie_knot_node.color = color.darkened(0.1)
	if type_label:
		type_label.text = Agent.get_agent_label(agent_type)

func check_mouse_hover() -> void:
	var mouse_pos = agent.get_local_mouse_position()
	var in_bounds = mouse_pos.x > -20 and mouse_pos.x < 20 and mouse_pos.y > -50 and mouse_pos.y < 35

	if in_bounds and not is_hovered:
		is_hovered = true
	elif not in_bounds and is_hovered:
		is_hovered = false
		hide_tooltip()

func show_tooltip(agent_data: Dictionary) -> void:
	if not tooltip_panel:
		return

	var profile_name = agent_data.get("profile_name", "")
	var profile_level = agent_data.get("profile_level", 0)
	var agent_type = agent_data.get("agent_type", "default")
	var agent_id = agent_data.get("agent_id", "")
	var tooltip_text = agent_data.get("tooltip_text", "")

	# Set header (agent name)
	if tooltip_header:
		tooltip_header.text = profile_name if profile_name else agent_id.substr(0, 8)

	# Set subtitle (level + role)
	if tooltip_subtitle:
		var role_label = Agent.get_agent_label(agent_type)
		tooltip_subtitle.text = "Lv." + str(profile_level) + " " + role_label

	# Set body text
	if tooltip_label:
		tooltip_label.text = tooltip_text

	# Force panel to recalculate size based on content
	tooltip_panel.reset_size()
	tooltip_panel.visible = true

	# Use call_deferred to position after layout is calculated
	_position_tooltip.call_deferred()

func _position_tooltip() -> void:
	if not tooltip_panel or not tooltip_panel.visible:
		return

	var panel_size = tooltip_panel.size

	# Position tooltip - flip if near screen edge
	var tooltip_x: float = 30.0
	if agent.global_position.x + 30 + panel_size.x > OfficeConstants.SCREEN_WIDTH:
		tooltip_x = -panel_size.x - 10

	var tooltip_y: float = -panel_size.y - 10
	if agent.global_position.y + tooltip_y < 0:
		tooltip_y = 40

	tooltip_panel.position = Vector2(tooltip_x, tooltip_y)

func hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func set_facing_direction(face_left: bool) -> void:
	if head:
		if face_left:
			head.position.x = -4
		else:
			head.position.x = 4
