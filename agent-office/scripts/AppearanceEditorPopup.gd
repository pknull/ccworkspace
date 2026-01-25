extends CanvasLayer
class_name AppearanceEditorPopup

# =============================================================================
# APPEARANCE EDITOR POPUP - Edit Agent Appearance
# =============================================================================
# Allows editing agent appearance: skin tone, hair, top (blouse/shirt+tie), bottom (pants/skirt)

signal close_requested()
signal appearance_changed(profile: AgentProfile)

# Container for all visual elements
var container: Control
var background: ColorRect
var panel: ColorRect
var close_button: Button
var save_button: Button

# Preview area
var preview_container: Control
var preview_layer: Control

# Option containers
var skin_container: HBoxContainer
var hair_color_container: HBoxContainer
var hair_style_container: HBoxContainer
var top_type_container: HBoxContainer
var top_color_label: Label
var top_color_container: HBoxContainer
var bottom_type_container: HBoxContainer
var bottom_color_label: Label
var bottom_color_container: HBoxContainer

# Current selections
var current_profile: AgentProfile = null
var selected_skin: int = 0
var selected_hair_color: int = 0
var selected_hair_style: int = 0
var selected_top_type: int = 0  # 0=Blouse, 1=Shirt+Tie
var selected_top_color: int = 0
var selected_bottom_type: int = 0  # 0=Pants, 1=Skirt
var selected_bottom_color: int = 0

# Layout constants
const PANEL_WIDTH: float = 480
const PANEL_HEIGHT: float = 420
const PREVIEW_SIZE: float = 80
const SWATCH_SIZE: float = 24
const SWATCH_SPACING: float = 4

# Use centralized arrays from OfficePalette
const SKIN_TONES = OfficePalette.SKIN_TONES
const HAIR_COLORS = OfficePalette.HAIR_COLORS

const BLOUSE_COLORS: Array[Color] = [
	Color(0.976, 0.961, 0.890),  # White/Cream
	Color(0.879, 0.668, 0.726),  # Pink
	Color(0.611, 0.718, 0.677),  # Blue
	Color(0.75, 0.65, 0.80),     # Lavender
]

const TIE_COLORS: Array[Color] = [
	OfficePalette.GRUVBOX_RED,
	OfficePalette.GRUVBOX_BLUE,
	OfficePalette.GRUVBOX_GREEN,
	OfficePalette.GRUVBOX_PURPLE,
]

const PANTS_COLORS: Array[Color] = [
	OfficePalette.GRUVBOX_BG,      # Dark
	OfficePalette.GRUVBOX_BG2,     # Medium dark
	Color(0.25, 0.22, 0.21),       # Charcoal
	Color(0.15, 0.20, 0.25),       # Navy
]

const SKIRT_COLORS: Array[Color] = [
	OfficePalette.GRUVBOX_BG1,     # Dark
	Color(0.25, 0.22, 0.21),       # Charcoal
	Color(0.15, 0.20, 0.25),       # Navy
	Color(0.35, 0.25, 0.30),       # Burgundy
]

const HAIR_STYLE_NAMES: Array[String] = ["Short", "Long", "Bob", "Updo"]
const TOP_TYPE_NAMES: Array[String] = ["Blouse", "Shirt+Tie"]
const BOTTOM_TYPE_NAMES: Array[String] = ["Pants", "Skirt"]

# References for button highlighting
var skin_buttons: Array[Button] = []
var hair_color_buttons: Array[Button] = []
var hair_style_buttons: Array[Button] = []
var top_type_buttons: Array[Button] = []
var top_color_buttons: Array[Button] = []
var bottom_type_buttons: Array[Button] = []
var bottom_color_buttons: Array[Button] = []

func _init() -> void:
	layer = OfficeConstants.Z_UI_POPUP_LAYER + 1  # Above ProfilePopup

func _ready() -> void:
	_create_visuals()

func show_editor(profile: AgentProfile) -> void:
	if profile == null:
		push_warning("[AppearanceEditor] show_editor called with null profile")
		return

	current_profile = profile
	selected_skin = profile.skin_color_index
	selected_hair_color = profile.hair_color_index
	selected_hair_style = profile.hair_style_index
	# is_female means "uses blouse" (true) vs "uses shirt+tie" (false)
	selected_top_type = 0 if profile.is_female else 1
	selected_top_color = profile.blouse_color_index
	selected_bottom_type = profile.bottom_type
	selected_bottom_color = profile.bottom_color_index

	_rebuild_top_color_buttons()
	_rebuild_bottom_color_buttons()
	_update_button_highlights()
	_update_preview()
	visible = true

func _create_visuals() -> void:
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	# Semi-transparent background
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.color = Color(0, 0, 0, 0.75)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(background)

	var panel_x = (OfficeConstants.SCREEN_WIDTH - PANEL_WIDTH) / 2
	var panel_y = (OfficeConstants.SCREEN_HEIGHT - PANEL_HEIGHT) / 2

	# Panel border
	var border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, PANEL_HEIGHT + 4)
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.color = OfficePalette.GRUVBOX_YELLOW
	container.add_child(border)

	# Main panel
	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.position = Vector2(panel_x, panel_y)
	panel.color = OfficePalette.GRUVBOX_BG
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(panel)

	# Title
	var title = Label.new()
	title.text = "EDIT APPEARANCE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(panel_x, panel_y + 12)
	title.size = Vector2(PANEL_WIDTH, 24)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(title)

	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 8)
	close_button.size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

	# Preview area (left side)
	var preview_x = panel_x + 30
	var preview_y = panel_y + 50

	var preview_bg = ColorRect.new()
	preview_bg.size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE + 20)
	preview_bg.position = Vector2(preview_x, preview_y)
	preview_bg.color = OfficePalette.GRUVBOX_BG1
	container.add_child(preview_bg)

	preview_container = Control.new()
	preview_container.position = Vector2(preview_x, preview_y)
	preview_container.size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE + 20)
	container.add_child(preview_container)

	preview_layer = Control.new()
	preview_layer.position = Vector2.ZERO
	preview_container.add_child(preview_layer)

	# Options area (right side)
	var options_x = panel_x + 140
	var options_y = panel_y + 50
	var row_height = 36

	# Skin tone row
	_create_label("Skin:", options_x, options_y)
	skin_container = _create_option_row(options_x + 80, options_y)
	_create_skin_buttons()
	options_y += row_height

	# Hair color row
	_create_label("Hair Color:", options_x, options_y)
	hair_color_container = _create_option_row(options_x + 80, options_y)
	_create_hair_color_buttons()
	options_y += row_height

	# Hair style row
	_create_label("Hair Style:", options_x, options_y)
	hair_style_container = _create_option_row(options_x + 80, options_y)
	_create_hair_style_buttons()
	options_y += row_height

	# Top type row
	_create_label("Top:", options_x, options_y)
	top_type_container = _create_option_row(options_x + 80, options_y)
	_create_top_type_buttons()
	options_y += row_height

	# Top color row
	top_color_label = _create_label("Top Color:", options_x, options_y)
	top_color_container = _create_option_row(options_x + 80, options_y)
	# Buttons created dynamically based on top type
	options_y += row_height

	# Bottom type row
	_create_label("Bottom:", options_x, options_y)
	bottom_type_container = _create_option_row(options_x + 80, options_y)
	_create_bottom_type_buttons()
	options_y += row_height

	# Bottom color row
	bottom_color_label = _create_label("Bottom Color:", options_x, options_y)
	bottom_color_container = _create_option_row(options_x + 80, options_y)
	# Buttons created dynamically based on bottom type
	options_y += row_height

	# Save button
	save_button = Button.new()
	save_button.text = "Save Changes"
	save_button.position = Vector2(panel_x + PANEL_WIDTH / 2 - 60, panel_y + PANEL_HEIGHT - 45)
	save_button.size = Vector2(120, 30)
	save_button.pressed.connect(_on_save_pressed)
	container.add_child(save_button)

func _create_label(text: String, x: float, y: float) -> Label:
	var label = Label.new()
	label.text = text
	label.position = Vector2(x, y + 4)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	container.add_child(label)
	return label

func _create_option_row(x: float, y: float) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(x, y)
	hbox.add_theme_constant_override("separation", int(SWATCH_SPACING))
	container.add_child(hbox)
	return hbox

func _create_skin_buttons() -> void:
	for i in range(SKIN_TONES.size()):
		var btn = _create_color_swatch(SKIN_TONES[i])
		btn.pressed.connect(func(): _select_skin(i))
		skin_container.add_child(btn)
		skin_buttons.append(btn)

func _create_hair_color_buttons() -> void:
	for i in range(HAIR_COLORS.size()):
		var btn = _create_color_swatch(HAIR_COLORS[i])
		btn.pressed.connect(func(): _select_hair_color(i))
		hair_color_container.add_child(btn)
		hair_color_buttons.append(btn)

func _create_hair_style_buttons() -> void:
	for i in range(HAIR_STYLE_NAMES.size()):
		var btn = Button.new()
		btn.text = HAIR_STYLE_NAMES[i]
		btn.custom_minimum_size = Vector2(50, SWATCH_SIZE)
		btn.pressed.connect(func(): _select_hair_style(i))
		hair_style_container.add_child(btn)
		hair_style_buttons.append(btn)

func _create_top_type_buttons() -> void:
	for i in range(TOP_TYPE_NAMES.size()):
		var btn = Button.new()
		btn.text = TOP_TYPE_NAMES[i]
		btn.custom_minimum_size = Vector2(70, SWATCH_SIZE)
		btn.pressed.connect(func(): _select_top_type(i))
		top_type_container.add_child(btn)
		top_type_buttons.append(btn)

func _create_bottom_type_buttons() -> void:
	for i in range(BOTTOM_TYPE_NAMES.size()):
		var btn = Button.new()
		btn.text = BOTTOM_TYPE_NAMES[i]
		btn.custom_minimum_size = Vector2(60, SWATCH_SIZE)
		btn.pressed.connect(func(): _select_bottom_type(i))
		bottom_type_container.add_child(btn)
		bottom_type_buttons.append(btn)

func _rebuild_top_color_buttons() -> void:
	# Clear existing buttons
	for btn in top_color_buttons:
		btn.queue_free()
	top_color_buttons.clear()

	# Create new buttons based on top type
	var colors = BLOUSE_COLORS if selected_top_type == 0 else TIE_COLORS
	for i in range(colors.size()):
		var btn = _create_color_swatch(colors[i])
		btn.pressed.connect(func(): _select_top_color(i))
		top_color_container.add_child(btn)
		top_color_buttons.append(btn)

func _rebuild_bottom_color_buttons() -> void:
	# Clear existing buttons
	for btn in bottom_color_buttons:
		btn.queue_free()
	bottom_color_buttons.clear()

	# Create new buttons based on bottom type
	var colors = PANTS_COLORS if selected_bottom_type == 0 else SKIRT_COLORS
	for i in range(colors.size()):
		var btn = _create_color_swatch(colors[i])
		btn.pressed.connect(func(): _select_bottom_color(i))
		bottom_color_container.add_child(btn)
		bottom_color_buttons.append(btn)

func _create_color_swatch(color: Color) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)

	# Add color indicator as child
	var swatch = ColorRect.new()
	swatch.size = Vector2(SWATCH_SIZE - 4, SWATCH_SIZE - 4)
	swatch.position = Vector2(2, 2)
	swatch.color = color
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(swatch)

	return btn

func _select_skin(index: int) -> void:
	selected_skin = index
	_update_button_highlights()
	_update_preview()

func _select_hair_color(index: int) -> void:
	selected_hair_color = index
	_update_button_highlights()
	_update_preview()

func _select_hair_style(index: int) -> void:
	selected_hair_style = index
	_update_button_highlights()
	_update_preview()

func _select_top_type(index: int) -> void:
	selected_top_type = index
	selected_top_color = 0  # Reset color when type changes
	_rebuild_top_color_buttons()
	_update_button_highlights()
	_update_preview()

func _select_top_color(index: int) -> void:
	selected_top_color = index
	_update_button_highlights()
	_update_preview()

func _select_bottom_type(index: int) -> void:
	selected_bottom_type = index
	selected_bottom_color = 0  # Reset color when type changes
	_rebuild_bottom_color_buttons()
	_update_button_highlights()
	_update_preview()

func _select_bottom_color(index: int) -> void:
	selected_bottom_color = index
	_update_button_highlights()
	_update_preview()

func _update_button_highlights() -> void:
	# Skin buttons
	for i in range(skin_buttons.size()):
		_set_button_highlight(skin_buttons[i], i == selected_skin)

	# Hair color buttons
	for i in range(hair_color_buttons.size()):
		_set_button_highlight(hair_color_buttons[i], i == selected_hair_color)

	# Hair style buttons
	for i in range(hair_style_buttons.size()):
		_set_button_highlight(hair_style_buttons[i], i == selected_hair_style)

	# Top type buttons
	for i in range(top_type_buttons.size()):
		_set_button_highlight(top_type_buttons[i], i == selected_top_type)

	# Top color buttons
	for i in range(top_color_buttons.size()):
		_set_button_highlight(top_color_buttons[i], i == selected_top_color)

	# Bottom type buttons
	for i in range(bottom_type_buttons.size()):
		_set_button_highlight(bottom_type_buttons[i], i == selected_bottom_type)

	# Bottom color buttons
	for i in range(bottom_color_buttons.size()):
		_set_button_highlight(bottom_color_buttons[i], i == selected_bottom_color)

func _set_button_highlight(btn: Button, selected: bool) -> void:
	if selected:
		btn.add_theme_stylebox_override("normal", _create_selected_style())
	else:
		btn.remove_theme_stylebox_override("normal")

func _create_selected_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = OfficePalette.GRUVBOX_AQUA
	style.set_corner_radius_all(3)
	return style

func _update_preview() -> void:
	# Clear existing preview
	for child in preview_layer.get_children():
		child.queue_free()

	var skin_color = SKIN_TONES[selected_skin % SKIN_TONES.size()]
	var hair_color = HAIR_COLORS[selected_hair_color % HAIR_COLORS.size()]
	var top_color = BLOUSE_COLORS[selected_top_color % BLOUSE_COLORS.size()] if selected_top_type == 0 else TIE_COLORS[selected_top_color % TIE_COLORS.size()]
	var bottom_color = PANTS_COLORS[selected_bottom_color % PANTS_COLORS.size()] if selected_bottom_type == 0 else SKIRT_COLORS[selected_bottom_color % SKIRT_COLORS.size()]

	# Scale factor for preview (agent is normally ~50px tall)
	var scale = 1.5
	var center_x = PREVIEW_SIZE / 2
	var center_y = PREVIEW_SIZE / 2 + 10

	_create_agent_preview(center_x, center_y, scale, skin_color, hair_color, top_color, bottom_color)

func _create_agent_preview(cx: float, cy: float, scale: float, skin: Color, hair: Color, top_color: Color, bottom_color: Color) -> void:
	var show_skirt = (selected_bottom_type == 1)
	var show_tie = (selected_top_type == 1)

	# Bottom (trousers or skirt) - always with legs
	if show_skirt:
		var skirt = ColorRect.new()
		skirt.size = Vector2(20 * scale, 10 * scale)
		skirt.position = Vector2(cx - 10 * scale, cy + 6 * scale)
		skirt.color = bottom_color
		preview_layer.add_child(skirt)

		# Legs below skirt (skin-toned)
		var left_leg = ColorRect.new()
		left_leg.size = Vector2(6 * scale, 8 * scale)
		left_leg.position = Vector2(cx - 7 * scale, cy + 14 * scale)
		left_leg.color = skin.darkened(0.1)
		preview_layer.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(6 * scale, 8 * scale)
		right_leg.position = Vector2(cx + 1 * scale, cy + 14 * scale)
		right_leg.color = skin.darkened(0.1)
		preview_layer.add_child(right_leg)
	else:
		# Pants
		var left_leg = ColorRect.new()
		left_leg.size = Vector2(7 * scale, 12 * scale)
		left_leg.position = Vector2(cx - 8 * scale, cy + 8 * scale)
		left_leg.color = bottom_color
		preview_layer.add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(7 * scale, 12 * scale)
		right_leg.position = Vector2(cx + 1 * scale, cy + 8 * scale)
		right_leg.color = bottom_color
		preview_layer.add_child(right_leg)

	# Top (white shirt for tie outfit, colored for blouse)
	var body = ColorRect.new()
	body.size = Vector2(17 * scale, 15 * scale)
	body.position = Vector2(cx - 8.5 * scale, cy - 7 * scale)
	body.color = OfficePalette.AGENT_SHIRT_WHITE if show_tie else top_color
	preview_layer.add_child(body)

	# Tie (only for Shirt+Tie outfit)
	if show_tie:
		var tie = ColorRect.new()
		tie.size = Vector2(4 * scale, 14 * scale)
		tie.position = Vector2(cx - 2 * scale, cy - 5 * scale)
		tie.color = top_color
		preview_layer.add_child(tie)

	# Head
	var head = ColorRect.new()
	head.size = Vector2(13 * scale, 13 * scale)
	head.position = Vector2(cx - 6.5 * scale, cy - 20 * scale)
	head.color = skin
	preview_layer.add_child(head)

	# Hair (uses selected style)
	_create_hair_preview(cx, cy, scale, hair, selected_hair_style)

	# Eyes
	_add_eyes(cx, cy - 2 * scale, scale * 0.95)

func _create_hair_preview(cx: float, cy: float, scale: float, hair: Color, style: int) -> void:
	match style % 4:
		0:  # Short
			var top = ColorRect.new()
			top.size = Vector2(14 * scale, 5 * scale)
			top.position = Vector2(cx - 7 * scale, cy - 23 * scale)
			top.color = hair
			preview_layer.add_child(top)
		1:  # Long
			var top = ColorRect.new()
			top.size = Vector2(14 * scale, 6 * scale)
			top.position = Vector2(cx - 7 * scale, cy - 22 * scale)
			top.color = hair
			preview_layer.add_child(top)

			var left = ColorRect.new()
			left.size = Vector2(4 * scale, 14 * scale)
			left.position = Vector2(cx - 8 * scale, cy - 18 * scale)
			left.color = hair
			preview_layer.add_child(left)

			var right = ColorRect.new()
			right.size = Vector2(4 * scale, 14 * scale)
			right.position = Vector2(cx + 4 * scale, cy - 18 * scale)
			right.color = hair
			preview_layer.add_child(right)
		2:  # Bob
			var top = ColorRect.new()
			top.size = Vector2(16 * scale, 8 * scale)
			top.position = Vector2(cx - 8 * scale, cy - 22 * scale)
			top.color = hair
			preview_layer.add_child(top)

			var sides = ColorRect.new()
			sides.size = Vector2(18 * scale, 6 * scale)
			sides.position = Vector2(cx - 9 * scale, cy - 16 * scale)
			sides.color = hair
			preview_layer.add_child(sides)
		3:  # Updo
			var top = ColorRect.new()
			top.size = Vector2(14 * scale, 6 * scale)
			top.position = Vector2(cx - 7 * scale, cy - 22 * scale)
			top.color = hair
			preview_layer.add_child(top)

			var bun = ColorRect.new()
			bun.size = Vector2(8 * scale, 8 * scale)
			bun.position = Vector2(cx - 4 * scale, cy - 28 * scale)
			bun.color = hair
			preview_layer.add_child(bun)

func _add_eyes(cx: float, cy: float, scale: float) -> void:
	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3 * scale, 3 * scale)
	left_eye.position = Vector2(cx - 5 * scale, cy - 17 * scale)
	left_eye.color = OfficePalette.EYE_COLOR
	preview_layer.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3 * scale, 3 * scale)
	right_eye.position = Vector2(cx + 2 * scale, cy - 17 * scale)
	right_eye.color = OfficePalette.EYE_COLOR
	preview_layer.add_child(right_eye)

func _on_save_pressed() -> void:
	if current_profile == null:
		return

	# Update profile
	current_profile.skin_color_index = selected_skin
	current_profile.hair_color_index = selected_hair_color
	current_profile.hair_style_index = selected_hair_style
	# is_female now means "uses blouse" (true) vs "uses shirt+tie" (false)
	current_profile.is_female = (selected_top_type == 0)
	current_profile.blouse_color_index = selected_top_color
	current_profile.bottom_type = selected_bottom_type
	current_profile.bottom_color_index = selected_bottom_color

	appearance_changed.emit(current_profile)
	visible = false
	close_requested.emit()

func _on_close_pressed() -> void:
	visible = false
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
