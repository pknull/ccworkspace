extends CanvasLayer
class_name WeatherSettingsPopup

# =============================================================================
# WEATHER SETTINGS POPUP - Configure weather display
# =============================================================================

signal close_requested()

# Layout constants
const PANEL_WIDTH: float = 350
const PANEL_HEIGHT: float = 220
const BUTTON_WIDTH: float = 280
const BUTTON_HEIGHT: float = 28
const BUTTON_SPACING: float = 8
const FONT_SIZE_TITLE: int = 16
const FONT_SIZE_BODY: int = 12

# Visual elements
var container: Control
var background: ColorRect
var panel: ColorRect
var title_label: Label
var close_button: Button

# Weather controls
var weather_mode_button: Button
var weather_location_input: LineEdit
var weather_units_button: Button
var weather_service = null

func _init() -> void:
	layer = OfficeConstants.Z_UI_POPUP_LAYER + 1  # Above parent menu

func _ready() -> void:
	_create_visuals()

func setup(p_weather_service) -> void:
	weather_service = p_weather_service
	_sync_settings()

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
	title_label.text = "WEATHER SETTINGS"
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

	var button_x = panel_x + (PANEL_WIDTH - BUTTON_WIDTH) / 2
	var button_y = panel_y + 50

	# Location mode button
	var mode_label = Label.new()
	mode_label.text = "Location Source"
	mode_label.position = Vector2(button_x, button_y)
	mode_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	mode_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(mode_label)
	button_y += 20

	weather_mode_button = _create_button("Location: Auto", button_x, button_y)
	weather_mode_button.pressed.connect(_on_weather_mode_pressed)
	container.add_child(weather_mode_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Location input
	var location_label = Label.new()
	location_label.text = "Custom Location (city, region)"
	location_label.position = Vector2(button_x, button_y)
	location_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	location_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(location_label)
	button_y += 20

	weather_location_input = LineEdit.new()
	weather_location_input.position = Vector2(button_x, button_y)
	weather_location_input.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	weather_location_input.placeholder_text = "e.g., Seattle, WA"
	weather_location_input.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	weather_location_input.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	weather_location_input.text_submitted.connect(_on_weather_location_submitted)
	container.add_child(weather_location_input)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Units button
	var units_label = Label.new()
	units_label.text = "Temperature Units"
	units_label.position = Vector2(button_x, button_y)
	units_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	units_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(units_label)
	button_y += 20

	weather_units_button = _create_button("Units: Metric", button_x, button_y)
	weather_units_button.pressed.connect(_on_weather_units_pressed)
	container.add_child(weather_units_button)

func _create_button(text: String, x: float, y: float) -> Button:
	var button = Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	return button

func _sync_settings() -> void:
	if not weather_service:
		return
	if weather_mode_button:
		weather_mode_button.text = _get_weather_mode_text()
	if weather_location_input and weather_service.has_method("get_location_query"):
		weather_location_input.text = weather_service.get_location_query()
		weather_location_input.editable = not weather_service.is_auto_location()
	if weather_units_button:
		weather_units_button.text = _get_weather_units_text()

func _get_weather_mode_text() -> String:
	if weather_service and weather_service.has_method("is_auto_location"):
		return "Location: Auto" if weather_service.is_auto_location() else "Location: Custom"
	return "Location: Auto"

func _get_weather_units_text() -> String:
	if weather_service and weather_service.has_method("is_fahrenheit"):
		return "Units: Imperial (\u00b0F)" if weather_service.is_fahrenheit() else "Units: Metric (\u00b0C)"
	return "Units: Metric (\u00b0C)"

func _on_weather_mode_pressed() -> void:
	if weather_service and weather_service.has_method("set_use_auto_location"):
		var new_auto = not weather_service.is_auto_location()
		weather_service.set_use_auto_location(new_auto)
		weather_mode_button.text = _get_weather_mode_text()
		if weather_location_input:
			weather_location_input.editable = not new_auto

func _on_weather_location_submitted(text: String) -> void:
	if weather_service and weather_service.has_method("set_custom_location"):
		weather_service.set_custom_location(text)
		_sync_settings()

func _on_weather_units_pressed() -> void:
	if weather_service and weather_service.has_method("set_use_fahrenheit"):
		weather_service.set_use_fahrenheit(not weather_service.is_fahrenheit())
		weather_units_button.text = _get_weather_units_text()

func _on_close_pressed() -> void:
	# Apply location if changed and not in auto mode
	if weather_location_input and weather_service and weather_service.has_method("set_custom_location"):
		if not weather_service.is_auto_location():
			var text = weather_location_input.text.strip_edges()
			if text != "" and text != weather_service.get_location_query():
				weather_service.set_custom_location(text)
	visible = false
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
