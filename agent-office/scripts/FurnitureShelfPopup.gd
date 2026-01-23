extends CanvasLayer
class_name FurnitureShelfPopup

# =============================================================================
# FURNITURE SHELF POPUP - Add/Remove furniture from the office
# =============================================================================
# Provides an infinite inventory of furniture types that can be placed
# and allows removing existing furniture.

signal close_requested()
signal furniture_add_requested(furniture_type: String)
signal furniture_remove_requested(furniture_id: String)

# Available furniture types with display info
const FURNITURE_TYPES: Array[Dictionary] = [
	{"type": "desk", "name": "Desk", "color": Color(0.55, 0.4, 0.25), "size": Vector2(50, 30)},
	{"type": "meeting_table", "name": "Meeting Table", "color": Color(0.45, 0.35, 0.25), "size": Vector2(65, 35)},
	{"type": "water_cooler", "name": "Water Cooler", "color": Color(0.7, 0.85, 0.95), "size": Vector2(30, 40)},
	{"type": "potted_plant", "name": "Plant", "color": Color(0.4, 0.7, 0.3), "size": Vector2(25, 35)},
	{"type": "filing_cabinet", "name": "Filing Cabinet", "color": Color(0.6, 0.6, 0.65), "size": Vector2(30, 35)},
	{"type": "shredder", "name": "Shredder", "color": Color(0.3, 0.3, 0.35), "size": Vector2(25, 30)},
	{"type": "cat_bed", "name": "Cat Bed", "color": Color(0.9, 0.75, 0.6), "size": Vector2(35, 20)},
	{"type": "taskboard", "name": "Taskboard", "color": Color(0.95, 0.95, 0.9), "size": Vector2(40, 50)},
]

# Layout constants
const PANEL_WIDTH: float = 500
const PANEL_HEIGHT: float = 400
const ITEM_SIZE: float = 70
const ITEMS_PER_ROW: int = 5
const FONT_SIZE_TITLE: int = 16
const FONT_SIZE_BODY: int = 11
const FONT_SIZE_SMALL: int = 10

# Visual elements
var container: Control
var background: ColorRect
var panel: ColorRect
var title_label: Label
var close_button: Button
var add_section: Control
var placed_section: Control
var placed_scroll: ScrollContainer
var placed_container: VBoxContainer

# Data
var placed_furniture: Array = []  # [{id, type, position}, ...]

func _init() -> void:
	layer = OfficeConstants.Z_UI_POPUP_LAYER

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	var screen_center = Vector2(OfficeConstants.SCREEN_WIDTH / 2, OfficeConstants.SCREEN_HEIGHT / 2)
	var panel_x = screen_center.x - PANEL_WIDTH / 2
	var panel_y = screen_center.y - PANEL_HEIGHT / 2

	# Semi-transparent background
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.color = Color(0, 0, 0, 0.75)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(background)

	# Border
	var border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, PANEL_HEIGHT + 4)
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.color = OfficePalette.GRUVBOX_YELLOW
	container.add_child(border)

	# Panel
	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.position = Vector2(panel_x, panel_y)
	panel.color = OfficePalette.GRUVBOX_BG
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(panel)

	# Title
	title_label = Label.new()
	title_label.text = "FURNITURE SHELF"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(panel_x, panel_y + 12)
	title_label.size = Vector2(PANEL_WIDTH, 24)
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(title_label)

	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 8)
	close_button.size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

	# Add section header
	var add_header = Label.new()
	add_header.text = "Add Furniture (click to place)"
	add_header.position = Vector2(panel_x + 20, panel_y + 45)
	add_header.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	add_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(add_header)

	# Add section - grid of furniture thumbnails
	add_section = Control.new()
	add_section.position = Vector2(panel_x + 20, panel_y + 65)
	add_section.size = Vector2(PANEL_WIDTH - 40, 160)
	container.add_child(add_section)

	_create_furniture_grid()

	# Divider
	var divider = ColorRect.new()
	divider.size = Vector2(PANEL_WIDTH - 40, 1)
	divider.position = Vector2(panel_x + 20, panel_y + 230)
	divider.color = OfficePalette.GRUVBOX_LIGHT4
	divider.color.a = 0.3
	container.add_child(divider)

	# Placed section header
	var placed_header = Label.new()
	placed_header.text = "Placed Furniture (click to remove)"
	placed_header.position = Vector2(panel_x + 20, panel_y + 240)
	placed_header.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	placed_header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(placed_header)

	# Placed section - scrollable list
	placed_scroll = ScrollContainer.new()
	placed_scroll.position = Vector2(panel_x + 20, panel_y + 260)
	placed_scroll.size = Vector2(PANEL_WIDTH - 40, PANEL_HEIGHT - 280)
	placed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	placed_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(placed_scroll)

	placed_container = VBoxContainer.new()
	placed_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placed_container.add_theme_constant_override("separation", 4)
	placed_scroll.add_child(placed_container)

func _create_furniture_grid() -> void:
	var x = 0
	var y = 0
	for i in range(FURNITURE_TYPES.size()):
		var ftype = FURNITURE_TYPES[i]
		var item = _create_furniture_item(ftype, true)
		item.position = Vector2(x * (ITEM_SIZE + 10), y * (ITEM_SIZE + 25))
		add_section.add_child(item)
		x += 1
		if x >= ITEMS_PER_ROW:
			x = 0
			y += 1

func _create_furniture_item(ftype: Dictionary, is_add: bool) -> Control:
	var item = Control.new()
	item.custom_minimum_size = Vector2(ITEM_SIZE, ITEM_SIZE + 20)
	item.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	bg.color = OfficePalette.GRUVBOX_BG1
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(bg)

	# Border (hover highlight)
	var border = ColorRect.new()
	border.name = "Border"
	border.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	border.color = OfficePalette.GRUVBOX_BG2
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(border)

	# Inner
	var inner = ColorRect.new()
	inner.size = Vector2(ITEM_SIZE - 4, ITEM_SIZE - 4)
	inner.position = Vector2(2, 2)
	inner.color = OfficePalette.GRUVBOX_BG1
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(inner)

	# Thumbnail representation
	var thumb = ColorRect.new()
	var thumb_size = ftype.get("size", Vector2(30, 30)) * 0.8
	thumb.size = thumb_size
	thumb.position = Vector2((ITEM_SIZE - thumb_size.x) / 2, (ITEM_SIZE - thumb_size.y) / 2)
	thumb.color = ftype.get("color", OfficePalette.GRUVBOX_LIGHT4)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(thumb)

	# Label
	var label = Label.new()
	label.text = ftype.get("name", "Unknown")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, ITEM_SIZE + 2)
	label.size = Vector2(ITEM_SIZE, 16)
	label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(label)

	# Click handler
	var furniture_type = ftype.get("type", "")
	item.gui_input.connect(_on_add_item_clicked.bind(furniture_type))

	# Hover effect
	item.mouse_entered.connect(_on_item_hover.bind(item, true))
	item.mouse_exited.connect(_on_item_hover.bind(item, false))

	return item

func _on_item_hover(item: Control, hovered: bool) -> void:
	var border = item.get_node_or_null("Border") as ColorRect
	if border:
		border.color = OfficePalette.GRUVBOX_YELLOW if hovered else OfficePalette.GRUVBOX_BG2

func _on_add_item_clicked(event: InputEvent, furniture_type: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		furniture_add_requested.emit(furniture_type)

func show_shelf(current_furniture: Array) -> void:
	placed_furniture = current_furniture
	visible = true
	_update_placed_list()

func _update_placed_list() -> void:
	# Clear existing
	for child in placed_container.get_children():
		child.queue_free()

	if placed_furniture.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No furniture placed yet"
		empty_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
		empty_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
		placed_container.add_child(empty_label)
		return

	# Group by type
	var by_type: Dictionary = {}
	for f in placed_furniture:
		var ftype = f.get("type", "unknown")
		if not by_type.has(ftype):
			by_type[ftype] = []
		by_type[ftype].append(f)

	for ftype in by_type.keys():
		var items = by_type[ftype]
		var type_info = _get_type_info(ftype)
		var type_name = type_info.get("name", ftype)

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 28)
		placed_container.add_child(row)

		# Color swatch
		var swatch = ColorRect.new()
		swatch.custom_minimum_size = Vector2(20, 20)
		swatch.color = type_info.get("color", OfficePalette.GRUVBOX_LIGHT4)
		row.add_child(swatch)

		# Spacer
		var spacer1 = Control.new()
		spacer1.custom_minimum_size = Vector2(8, 0)
		row.add_child(spacer1)

		# Name and count
		var label = Label.new()
		label.text = "%s x%d" % [type_name, items.size()]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
		label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
		row.add_child(label)

		# Remove one button
		var remove_btn = Button.new()
		remove_btn.text = "-"
		remove_btn.custom_minimum_size = Vector2(28, 24)
		remove_btn.add_theme_font_size_override("font_size", 14)
		remove_btn.tooltip_text = "Remove one %s" % type_name
		remove_btn.pressed.connect(_on_remove_one.bind(ftype))
		row.add_child(remove_btn)

func _on_remove_one(furniture_type: String) -> void:
	# Find the last placed item of this type and remove it
	for i in range(placed_furniture.size() - 1, -1, -1):
		if placed_furniture[i].get("type") == furniture_type:
			var furniture_id = placed_furniture[i].get("id", "")
			furniture_remove_requested.emit(furniture_id)
			break

func _get_type_info(furniture_type: String) -> Dictionary:
	for ftype in FURNITURE_TYPES:
		if ftype.get("type") == furniture_type:
			return ftype
	return {"name": furniture_type, "color": OfficePalette.GRUVBOX_LIGHT4}

func _on_close_pressed() -> void:
	visible = false
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
