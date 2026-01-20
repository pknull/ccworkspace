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
var tooltip_panel: ColorRect = null
var tooltip_label: Label = null

# Appearance state
var is_female: bool = false
var hair_color: Color = OfficePalette.HAIR_BROWN
var skin_color: Color = OfficePalette.SKIN_LIGHT
var hair_style_index: int = 0
var blouse_color_index: int = 0
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
	tooltip_panel = ColorRect.new()
	tooltip_panel.size = Vector2(280, 220)
	tooltip_panel.position = Vector2(30, -100)
	tooltip_panel.color = OfficePalette.TOOLTIP_BG
	tooltip_panel.visible = false
	tooltip_panel.z_index = OfficeConstants.Z_UI_TOOLTIP
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	agent.add_child(tooltip_panel)

	var border = ColorRect.new()
	border.size = Vector2(280, 220)
	border.position = Vector2(0, 0)
	border.color = OfficePalette.TOOLTIP_BORDER
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(border)

	var inner = ColorRect.new()
	inner.size = Vector2(276, 216)
	inner.position = Vector2(2, 2)
	inner.color = OfficePalette.GRUVBOX_LIGHT
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(inner)

	var header = Label.new()
	header.name = "Header"
	header.position = Vector2(6, 4)
	header.size = Vector2(268, 16)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_BG2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(header)

	var divider = ColorRect.new()
	divider.size = Vector2(268, 1)
	divider.position = Vector2(6, 20)
	divider.color = OfficePalette.TOOLTIP_DIVIDER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(divider)

	tooltip_label = Label.new()
	tooltip_label.position = Vector2(6, 23)
	tooltip_label.size = Vector2(268, 190)
	tooltip_label.add_theme_font_size_override("font_size", 9)
	tooltip_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(tooltip_label)

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
	_apply_appearance_values(profile.is_female, profile.hair_color_index, profile.skin_color_index, profile.hair_style_index, profile.blouse_color_index)

func _apply_appearance_values(p_is_female: bool, p_hair_index: int, p_skin_index: int, p_hair_style: int, p_blouse_color: int) -> void:
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

	if is_female:
		_create_female_visuals_persistent(skin_color, hair_color, hair_style_index, blouse_color_index)
	else:
		_create_male_visuals_persistent(skin_color, hair_color)
	_visuals_created = true

func _create_male_visuals_persistent(p_skin_color: Color, p_hair_color: Color) -> void:
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
	hair.color = p_hair_color
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

func _create_female_visuals_persistent(p_skin_color: Color, p_hair_color: Color, p_hair_style: int, p_blouse_index: int) -> void:
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	agent.add_child(shadow)

	var wears_skirt = p_blouse_index % 2 == 0

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

	match p_hair_style % 3:
		0:
			hair = ColorRect.new()
			hair.size = Vector2(24, 12)
			hair.position = Vector2(-3, -7)
			hair.color = p_hair_color
			head.add_child(hair)

			var hair_left = ColorRect.new()
			hair_left.size = Vector2(6, 18)
			hair_left.position = Vector2(-5, -1)
			hair_left.color = p_hair_color
			head.add_child(hair_left)

			var hair_right = ColorRect.new()
			hair_right.size = Vector2(6, 18)
			hair_right.position = Vector2(17, -1)
			hair_right.color = p_hair_color
			head.add_child(hair_right)
		1:
			hair = ColorRect.new()
			hair.size = Vector2(26, 14)
			hair.position = Vector2(-4, -9)
			hair.color = p_hair_color
			head.add_child(hair)

			var hair_sides = ColorRect.new()
			hair_sides.size = Vector2(28, 8)
			hair_sides.position = Vector2(-5, 1)
			hair_sides.color = p_hair_color
			head.add_child(hair_sides)
		2:
			hair = ColorRect.new()
			hair.size = Vector2(22, 10)
			hair.position = Vector2(-2, -8)
			hair.color = p_hair_color
			head.add_child(hair)

			var bun = ColorRect.new()
			bun.size = Vector2(10, 10)
			bun.position = Vector2(4, -15)
			bun.color = p_hair_color
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

	var tooltip_width = tooltip_panel.size.x
	var tooltip_height = tooltip_panel.size.y

	var tooltip_x: float = 30.0
	if agent.global_position.x + 30 + tooltip_width > OfficeConstants.SCREEN_WIDTH:
		tooltip_x = -tooltip_width - 10

	var tooltip_y: float = -100.0
	if agent.global_position.y + tooltip_y < 0:
		tooltip_y = -agent.global_position.y + 10
	elif agent.global_position.y + tooltip_y + tooltip_height > OfficeConstants.SCREEN_HEIGHT - 30:
		tooltip_y = OfficeConstants.SCREEN_HEIGHT - 30 - tooltip_height - agent.global_position.y

	tooltip_panel.position = Vector2(tooltip_x, tooltip_y)

	var header = tooltip_panel.get_node_or_null("Header")
	if header:
		var profile_name = agent_data.get("profile_name", "")
		var profile_level = agent_data.get("profile_level", 0)
		var agent_type = agent_data.get("agent_type", "default")
		var agent_id = agent_data.get("agent_id", "")
		if profile_name:
			header.text = profile_name + " (Lv." + str(profile_level) + " " + Agent.get_agent_label(agent_type) + ")"
		else:
			header.text = Agent.get_agent_label(agent_type) + " (" + agent_id.substr(0, 8) + ")"

	if tooltip_label:
		tooltip_label.text = agent_data.get("tooltip_text", "")

	tooltip_panel.visible = true

func hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func set_facing_direction(face_left: bool) -> void:
	if head:
		if face_left:
			head.position.x = -4
		else:
			head.position.x = 4
