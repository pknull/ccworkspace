extends CanvasLayer
class_name AppearanceEditorPopup

# =============================================================================
# APPEARANCE EDITOR POPUP - Edit Agent Appearance
# =============================================================================
# Allows editing agent appearance using JSON-driven items from AppearanceRegistry.

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
var top_container: HBoxContainer
var bottom_container: HBoxContainer

# Current selections (ID-based)
var current_profile: AgentProfile = null
var selected_skin: int = 0
var selected_top_id: String = "white_shirt"
var selected_bottom_id: String = "dark_pants"
var selected_hair_color_id: String = "brown"
var selected_hair_style_id: String = "short"

# Layout constants
const PANEL_WIDTH: float = 480
const PANEL_HEIGHT: float = 380
const PREVIEW_SIZE: float = 80
const SWATCH_SIZE: float = 24
const SWATCH_SPACING: float = 4

# Skin tones (remain index-based)
const SKIN_TONES = OfficePalette.SKIN_TONES

# Registry reference (set by OfficeManager)
var appearance_registry: AppearanceRegistry = null

# References for button highlighting
var skin_buttons: Array[Button] = []
var hair_color_buttons: Array[Button] = []
var hair_style_buttons: Array[Button] = []
var top_buttons: Array[Button] = []
var bottom_buttons: Array[Button] = []

# Map button index to item ID
var _hair_color_ids: Array[String] = []
var _hair_style_ids: Array[String] = []
var _top_ids: Array[String] = []
var _bottom_ids: Array[String] = []

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
	selected_top_id = profile.top_id
	selected_bottom_id = profile.bottom_id
	selected_hair_color_id = profile.hair_color_id
	selected_hair_style_id = profile.hair_style_id

	_rebuild_all_buttons()
	_update_button_highlights()
	_update_preview()
	visible = true

func _rebuild_all_buttons() -> void:
	_rebuild_hair_color_buttons()
	_rebuild_hair_style_buttons()
	_rebuild_top_buttons()
	_rebuild_bottom_buttons()

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
	options_y += row_height

	# Hair style row
	_create_label("Hair Style:", options_x, options_y)
	hair_style_container = _create_option_row(options_x + 80, options_y)
	options_y += row_height

	# Top row
	_create_label("Top:", options_x, options_y)
	top_container = _create_option_row(options_x + 80, options_y)
	options_y += row_height

	# Bottom row
	_create_label("Bottom:", options_x, options_y)
	bottom_container = _create_option_row(options_x + 80, options_y)
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

# --- Button Creation ---

func _create_skin_buttons() -> void:
	for i in range(SKIN_TONES.size()):
		var btn = _create_color_swatch(SKIN_TONES[i])
		btn.pressed.connect(func(): _select_skin(i))
		skin_container.add_child(btn)
		skin_buttons.append(btn)

func _rebuild_hair_color_buttons() -> void:
	for btn in hair_color_buttons:
		btn.queue_free()
	hair_color_buttons.clear()
	_hair_color_ids.clear()

	if not appearance_registry:
		return

	for item in appearance_registry.get_all_hair_colors():
		var item_id: String = item.get("id", "")
		var color := appearance_registry.get_hair_color_value(item_id)
		var btn = _create_color_swatch(color)
		btn.pressed.connect(_select_hair_color.bind(item_id))
		hair_color_container.add_child(btn)
		hair_color_buttons.append(btn)
		_hair_color_ids.append(item_id)

func _rebuild_hair_style_buttons() -> void:
	for btn in hair_style_buttons:
		btn.queue_free()
	hair_style_buttons.clear()
	_hair_style_ids.clear()

	if not appearance_registry:
		return

	for item in appearance_registry.get_all_hair_styles():
		var item_id: String = item.get("id", "")
		var btn = Button.new()
		btn.text = item.get("display_name", item_id)
		btn.custom_minimum_size = Vector2(50, SWATCH_SIZE)
		btn.pressed.connect(_select_hair_style.bind(item_id))
		hair_style_container.add_child(btn)
		hair_style_buttons.append(btn)
		_hair_style_ids.append(item_id)

func _rebuild_top_buttons() -> void:
	for btn in top_buttons:
		btn.queue_free()
	top_buttons.clear()
	_top_ids.clear()

	if not appearance_registry:
		return

	for item in appearance_registry.get_all_tops():
		var item_id: String = item.get("id", "")
		var color := appearance_registry.get_top_color(item_id)
		var btn = _create_color_swatch(color)
		btn.tooltip_text = item.get("display_name", item_id)
		btn.pressed.connect(_select_top.bind(item_id))
		top_container.add_child(btn)
		top_buttons.append(btn)
		_top_ids.append(item_id)

func _rebuild_bottom_buttons() -> void:
	for btn in bottom_buttons:
		btn.queue_free()
	bottom_buttons.clear()
	_bottom_ids.clear()

	if not appearance_registry:
		return

	for item in appearance_registry.get_all_bottoms():
		var item_id: String = item.get("id", "")
		var color := appearance_registry.get_bottom_color(item_id)
		var btn = _create_color_swatch(color)
		btn.tooltip_text = item.get("display_name", item_id)
		btn.pressed.connect(_select_bottom.bind(item_id))
		bottom_container.add_child(btn)
		bottom_buttons.append(btn)
		_bottom_ids.append(item_id)

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

# --- Selection Handlers ---

func _select_skin(index: int) -> void:
	selected_skin = index
	_update_button_highlights()
	_update_preview()

func _select_hair_color(item_id: String) -> void:
	selected_hair_color_id = item_id
	_update_button_highlights()
	_update_preview()

func _select_hair_style(item_id: String) -> void:
	selected_hair_style_id = item_id
	_update_button_highlights()
	_update_preview()

func _select_top(item_id: String) -> void:
	selected_top_id = item_id
	_update_button_highlights()
	_update_preview()

func _select_bottom(item_id: String) -> void:
	selected_bottom_id = item_id
	_update_button_highlights()
	_update_preview()

# --- Button Highlighting ---

func _update_button_highlights() -> void:
	for i in range(skin_buttons.size()):
		_set_button_highlight(skin_buttons[i], i == selected_skin)

	for i in range(hair_color_buttons.size()):
		_set_button_highlight(hair_color_buttons[i], _hair_color_ids[i] == selected_hair_color_id)

	for i in range(hair_style_buttons.size()):
		_set_button_highlight(hair_style_buttons[i], _hair_style_ids[i] == selected_hair_style_id)

	for i in range(top_buttons.size()):
		_set_button_highlight(top_buttons[i], _top_ids[i] == selected_top_id)

	for i in range(bottom_buttons.size()):
		_set_button_highlight(bottom_buttons[i], _bottom_ids[i] == selected_bottom_id)

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

# --- Preview ---

func _update_preview() -> void:
	for child in preview_layer.get_children():
		child.queue_free()

	var skin_color = SKIN_TONES[selected_skin % SKIN_TONES.size()]
	var hair_color := OfficePalette.HAIR_BROWN
	var top_color := OfficePalette.AGENT_SHIRT_WHITE
	var bottom_color := OfficePalette.AGENT_TROUSERS_DARK
	var tie_color_ref: String = ""
	var is_skirt := false

	if appearance_registry:
		hair_color = appearance_registry.get_hair_color_value(selected_hair_color_id)
		top_color = appearance_registry.get_top_color(selected_top_id)
		bottom_color = appearance_registry.get_bottom_color(selected_bottom_id)
		var top_data := appearance_registry.get_top(selected_top_id)
		var bottom_data := appearance_registry.get_bottom(selected_bottom_id)
		tie_color_ref = top_data.get("tie_color", "")
		is_skirt = bottom_data.get("is_skirt", false)

	var scale = 1.5
	var center_x = PREVIEW_SIZE / 2
	var center_y = PREVIEW_SIZE / 2 + 10

	_create_agent_preview(center_x, center_y, scale, skin_color, hair_color, top_color, bottom_color, tie_color_ref, is_skirt)

func _create_agent_preview(cx: float, cy: float, scale: float, skin: Color, hair: Color, top_color: Color, bottom_color: Color, tie_color_ref: String, show_skirt: bool) -> void:
	# Bottom (trousers or skirt)
	if show_skirt:
		var skirt = ColorRect.new()
		skirt.size = Vector2(20 * scale, 10 * scale)
		skirt.position = Vector2(cx - 10 * scale, cy + 6 * scale)
		skirt.color = bottom_color
		preview_layer.add_child(skirt)

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

	# Top (shirt body uses top color; tie tops show white shirt + tie)
	var body = ColorRect.new()
	body.size = Vector2(17 * scale, 15 * scale)
	body.position = Vector2(cx - 8.5 * scale, cy - 7 * scale)
	body.color = top_color
	preview_layer.add_child(body)

	if not tie_color_ref.is_empty():
		var tie = ColorRect.new()
		tie.size = Vector2(4 * scale, 14 * scale)
		tie.position = Vector2(cx - 2 * scale, cy - 5 * scale)
		tie.color = FurnitureJsonLoader.resolve_color(tie_color_ref)
		preview_layer.add_child(tie)

	# Head
	var head = ColorRect.new()
	head.size = Vector2(13 * scale, 13 * scale)
	head.position = Vector2(cx - 6.5 * scale, cy - 20 * scale)
	head.color = skin
	preview_layer.add_child(head)

	# Hair (JSON-driven via registry)
	_create_hair_preview(cx, cy, scale, hair)

	# Eyes
	_add_eyes(cx, cy - 2 * scale, scale * 0.95)

func _create_hair_preview(cx: float, cy: float, scale: float, hair: Color) -> void:
	if not appearance_registry:
		# Fallback: simple short hair
		var top = ColorRect.new()
		top.size = Vector2(14 * scale, 5 * scale)
		top.position = Vector2(cx - 7 * scale, cy - 23 * scale)
		top.color = hair
		preview_layer.add_child(top)
		return

	var style_data := appearance_registry.get_hair_style(selected_hair_style_id)
	if not style_data.has("visuals") or not (style_data["visuals"] is Array):
		return

	# Render scaled visuals from JSON
	for entry in style_data["visuals"]:
		var rect := ColorRect.new()
		var sz = entry.get("size", [20, 8])
		var pos = entry.get("position", [0, 0])
		if sz is Array and sz.size() >= 2 and pos is Array and pos.size() >= 2:
			# Scale and center the hair relative to head position
			# Original hair is relative to head (18x18 at head pos)
			# Preview head center: cx, cy - 20*scale, size 13*scale
			var head_cx = cx
			var head_top = cy - 20 * scale
			var head_w = 13.0 * scale
			# Map from original 18px head to preview head
			var ratio = head_w / 18.0
			rect.size = Vector2(sz[0] * ratio, sz[1] * ratio)
			# Position relative to head top-left in original: head is at (-9,-35), hair pos is relative to head
			rect.position = Vector2(head_cx - 6.5 * scale + pos[0] * ratio, head_top + pos[1] * ratio + 5 * ratio)
		rect.color = hair
		preview_layer.add_child(rect)

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

# --- Save / Close ---

func _on_save_pressed() -> void:
	if current_profile == null:
		return

	current_profile.skin_color_index = selected_skin
	current_profile.top_id = selected_top_id
	current_profile.bottom_id = selected_bottom_id
	current_profile.hair_color_id = selected_hair_color_id
	current_profile.hair_style_id = selected_hair_style_id

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
