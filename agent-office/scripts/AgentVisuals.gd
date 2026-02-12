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

# Appearance state (ID-based)
var top_id: String = "white_shirt"
var bottom_id: String = "dark_pants"
var hair_color_id: String = "brown"
var hair_style_id: String = "short"
var skin_color: Color = OfficePalette.SKIN_LIGHT
var appearance_applied: bool = false
var _visuals_created: bool = false

# Registry reference (set by OfficeManager before appearance apply)
var appearance_registry: AppearanceRegistry = null

# Hover state
var is_hovered: bool = false

# Context stress visuals (sweat drops)
const SWEAT_DROP_COLOR = Color(0.6, 0.8, 1.0, 0.9)  # Light blue
const STRESS_FLUSH_COLOR = Color(1.0, 0.8, 0.8)  # Pinkish flush
const SWEAT_DROP_SIZE = Vector2(3, 5)
const SWEAT_DROP_START_X = -12
const SWEAT_DROP_SPACING = 8
const SWEAT_DROP_BASE_Y = -8
const STRESS_FLUSH_THRESHOLD = 3  # Level at which face flushes

var sweat_drops: Array[ColorRect] = []
var current_stress_level: int = 0  # 0-4 based on context_stress thresholds

# Skin tones (remain index-based)
const SKIN_TONES: Array[Color] = [
	OfficePalette.SKIN_LIGHT,
	OfficePalette.SKIN_MEDIUM,
	OfficePalette.SKIN_TAN,
	OfficePalette.SKIN_DARK,
	OfficePalette.SKIN_VERY_LIGHT,
]

func _init(p_agent: Node2D) -> void:
	agent = p_agent

func create_visuals() -> void:
	_ensure_ui_nodes()
	# Random appearance for agents without a profile
	var tops := AppearanceRegistry.TOP_INDEX_MAP
	var bottoms := AppearanceRegistry.BOTTOM_INDEX_MAP
	var hair_colors := AppearanceRegistry.HAIR_COLOR_INDEX_MAP
	var hair_styles := AppearanceRegistry.HAIR_STYLE_INDEX_MAP
	top_id = tops[randi() % tops.size()]
	bottom_id = bottoms[randi() % bottoms.size()]
	hair_color_id = hair_colors[randi() % hair_colors.size()]
	hair_style_id = hair_styles[randi() % hair_styles.size()]
	skin_color = SKIN_TONES[randi() % SKIN_TONES.size()]

	_create_agent_body(skin_color)
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

func _create_agent_body(p_skin_color: Color) -> void:
	## Unified body rendering driven by appearance IDs.
	var top_data := {}
	var bottom_data := {}
	var hair_col := OfficePalette.HAIR_BROWN
	var top_color := OfficePalette.AGENT_SHIRT_WHITE
	var bottom_color := OfficePalette.AGENT_TROUSERS_DARK
	var tie_color_ref: String = ""
	var is_skirt := false

	if appearance_registry:
		top_data = appearance_registry.get_top(top_id)
		bottom_data = appearance_registry.get_bottom(bottom_id)
		hair_col = appearance_registry.get_hair_color_value(hair_color_id)
		top_color = appearance_registry.get_top_color(top_id)
		bottom_color = appearance_registry.get_bottom_color(bottom_id)
		tie_color_ref = top_data.get("tie_color", "")
		is_skirt = bottom_data.get("is_skirt", false)
	else:
		# Fallback when no registry (shouldn't happen in normal flow)
		if top_id == "white_shirt":
			tie_color_ref = "AGENT_TIE_RED"
		is_skirt = bottom_id.ends_with("_skirt")

	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	agent.add_child(shadow)

	# Bottom (legs)
	if is_skirt:
		var skirt = ColorRect.new()
		skirt.size = Vector2(28, 14)
		skirt.position = Vector2(-14, 10)
		skirt.color = bottom_color
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
		left_leg.color = bottom_color
		agent.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(10, 18)
		right_leg.position = Vector2(2, 15)
		right_leg.color = bottom_color
		agent.add_child(right_leg)

	# Body (top)
	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = top_color
	body.z_index = 0
	agent.add_child(body)

	# Collar + Tie (rendered when top has tie_color)
	if not tie_color_ref.is_empty():
		var resolved_tie_color := FurnitureJsonLoader.resolve_color(tie_color_ref)

		var collar_left = ColorRect.new()
		collar_left.size = Vector2(8, 6)
		collar_left.position = Vector2(-11, -15)
		collar_left.color = top_color
		agent.add_child(collar_left)

		var collar_right = ColorRect.new()
		collar_right.size = Vector2(8, 6)
		collar_right.position = Vector2(3, -15)
		collar_right.color = top_color
		agent.add_child(collar_right)

		tie = ColorRect.new()
		tie.size = Vector2(6, 22)
		tie.position = Vector2(-3, -12)
		tie.color = resolved_tie_color
		tie.z_index = 1
		agent.add_child(tie)

		var tie_knot = ColorRect.new()
		tie_knot.name = "TieKnot"
		tie_knot.size = Vector2(8, 5)
		tie_knot.position = Vector2(-4, -15)
		tie_knot.color = resolved_tie_color.darkened(0.1)
		tie_knot.z_index = 1
		agent.add_child(tie_knot)
	else:
		var collar = ColorRect.new()
		collar.size = Vector2(18, 6)
		collar.position = Vector2(-9, -17)
		collar.color = top_color
		agent.add_child(collar)
		tie = null

	# Head
	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = p_skin_color
	head.z_index = 2
	agent.add_child(head)

	# Hair (JSON-driven or fallback)
	_build_hair(hair_col)

	# Eyes
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

func _build_hair(hair_col: Color) -> void:
	## Build hair from JSON style definition, replacing HAIR_COLOR sentinel with actual color.
	var style_data := {}
	if appearance_registry:
		style_data = appearance_registry.get_hair_style(hair_style_id)

	if style_data.has("visuals") and style_data["visuals"] is Array:
		# Build from JSON visuals, replacing HAIR_COLOR with actual color
		for entry in style_data["visuals"]:
			var rect := ColorRect.new()
			rect.name = entry.get("name", "hair")
			var sz = entry.get("size", [20, 8])
			if sz is Array and sz.size() >= 2:
				rect.size = Vector2(sz[0], sz[1])
			var pos = entry.get("position", [0, 0])
			if pos is Array and pos.size() >= 2:
				rect.position = Vector2(pos[0], pos[1])
			# Replace HAIR_COLOR sentinel with actual color
			var color_ref = entry.get("color", "HAIR_COLOR")
			if color_ref is String and color_ref == "HAIR_COLOR":
				rect.color = hair_col
			else:
				rect.color = FurnitureJsonLoader.resolve_color(color_ref)
			head.add_child(rect)
		# Track 'hair' reference for animations — prefer named, fall back to first ColorRect
		if head.get_child_count() > 0:
			var first_rect: ColorRect = null
			for child in head.get_children():
				if child is ColorRect:
					if first_rect == null:
						first_rect = child
					if child.name == "hair":
						hair = child
						break
			if hair == null:
				hair = first_rect
	else:
		# Fallback: simple short hair
		hair = ColorRect.new()
		hair.size = Vector2(20, 8)
		hair.position = Vector2(-1, -5)
		hair.color = hair_col
		head.add_child(hair)

func apply_profile_appearance(profile) -> void:
	_apply_appearance_ids(profile.top_id, profile.bottom_id, profile.hair_color_id, profile.hair_style_id, profile.skin_color_index)

func refresh_appearance(profile) -> void:
	# Force re-apply appearance (used when profile is edited)
	appearance_applied = false
	_clear_visual_nodes()
	_apply_appearance_ids(profile.top_id, profile.bottom_id, profile.hair_color_id, profile.hair_style_id, profile.skin_color_index)

func _apply_appearance_ids(p_top: String, p_bottom: String, p_hair_color: String, p_hair_style: String, p_skin_index: int) -> void:
	if appearance_applied:
		return
	appearance_applied = true
	_ensure_ui_nodes()

	if _visuals_created:
		_clear_visual_nodes()

	top_id = p_top
	bottom_id = p_bottom
	hair_color_id = p_hair_color
	hair_style_id = p_hair_style
	skin_color = SKIN_TONES[p_skin_index % SKIN_TONES.size()]

	_create_agent_body(skin_color)
	_visuals_created = true


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

# =============================================================================
# CONTEXT STRESS VISUALS
# =============================================================================

func update_context_stress(stress: float) -> void:
	# Determine stress level: 0=none, 1=light, 2=moderate, 3=high, 4=critical
	var new_level: int = 0
	if stress >= 0.95:
		new_level = 4  # Critical - panic mode
	elif stress >= 0.85:
		new_level = 3  # High stress
	elif stress >= 0.70:
		new_level = 2  # Moderate stress
	elif stress >= 0.50:
		new_level = 1  # Light stress

	if new_level != current_stress_level:
		current_stress_level = new_level
		_update_sweat_drops()

func _update_sweat_drops() -> void:
	# Clear existing drops
	for drop in sweat_drops:
		if is_instance_valid(drop):
			drop.queue_free()
	sweat_drops.clear()

	if current_stress_level == 0 or not head:
		return

	# Create sweat drops based on stress level
	var drop_count = current_stress_level
	for i in range(drop_count):
		var drop = ColorRect.new()
		drop.size = SWEAT_DROP_SIZE
		drop.color = SWEAT_DROP_COLOR

		# Position drops around the head
		var offset_x = SWEAT_DROP_START_X + (i * SWEAT_DROP_SPACING)
		var offset_y = SWEAT_DROP_BASE_Y + (i % 2) * 4  # Slight vertical variation
		drop.position = Vector2(head.position.x + offset_x, head.position.y + offset_y)
		drop.z_index = 10

		agent.add_child(drop)
		sweat_drops.append(drop)

	# At high stress, tint the face slightly red
	if current_stress_level >= STRESS_FLUSH_THRESHOLD and head:
		head.color = head.color.lerp(STRESS_FLUSH_COLOR, 0.3)
