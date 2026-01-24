extends CanvasLayer
class_name PauseMenu

# =============================================================================
# PAUSE MENU - Simple menu overlay with game options
# =============================================================================
# Press Escape to toggle. Options: Reset Layout, Achievements, Quit

signal resume_requested()
signal roster_requested()
signal reset_layout_requested()
signal achievements_requested()
signal watchers_requested()
signal furniture_shelf_requested()
signal profiler_toggled(enabled: bool)
signal debug_toggled(enabled: bool)
signal event_log_requested()
signal quit_requested()

# Container for all visual elements
var container: Control

# Visual elements
var background: ColorRect
var panel: ColorRect
var title_label: Label
var resume_button: Button
var roster_button: Button
var volume_button: Button
var weather_button: Button
var watchers_button: Button
var furniture_button: Button
var reset_button: Button
var achievements_button: Button
var profiler_button: Button
var debug_button: Button
var event_log_button: Button
var quit_button: Button
var profiler_enabled: bool = false
var debug_enabled: bool = false

# Sub-popups
var volume_popup: VolumeSettingsPopup = null
var weather_popup: WeatherSettingsPopup = null

# Audio manager reference (set by OfficeManager)
var audio_manager = null
var weather_service = null

# Layout constants
const PANEL_WIDTH: float = 280
const PANEL_HEIGHT: float = 560
const BUTTON_WIDTH: float = 200
const BUTTON_HEIGHT: float = 28
const BUTTON_SPACING: float = 6
const SECTION_SPACING: float = 12

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

	# Background overlay (semi-transparent)
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.position = Vector2.ZERO
	background.color = Color(0, 0, 0, 0.7)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(background)

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
	title_label = Label.new()
	title_label.text = "PAUSED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(panel_x, panel_y + 15)
	title_label.size = Vector2(PANEL_WIDTH, 30)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(title_label)

	# Button start position
	var button_x = panel_x + (PANEL_WIDTH - BUTTON_WIDTH) / 2
	var button_y = panel_y + 55

	# Resume button
	resume_button = _create_button("Resume", button_x, button_y)
	resume_button.pressed.connect(_on_resume_pressed)
	container.add_child(resume_button)
	button_y += BUTTON_HEIGHT + SECTION_SPACING

	# Volume Settings button (opens popup)
	volume_button = _create_button("Volume Settings", button_x, button_y)
	volume_button.pressed.connect(_on_volume_pressed)
	container.add_child(volume_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Weather Settings button (opens popup)
	weather_button = _create_button("Weather Settings", button_x, button_y)
	weather_button.pressed.connect(_on_weather_pressed)
	container.add_child(weather_button)
	button_y += BUTTON_HEIGHT + SECTION_SPACING

	# Roster button
	roster_button = _create_button("Roster", button_x, button_y)
	roster_button.pressed.connect(_on_roster_pressed)
	container.add_child(roster_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Achievements button
	achievements_button = _create_button("Achievements", button_x, button_y)
	achievements_button.pressed.connect(_on_achievements_pressed)
	container.add_child(achievements_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Reset Layout button
	reset_button = _create_button("Reset Layout", button_x, button_y)
	reset_button.pressed.connect(_on_reset_pressed)
	container.add_child(reset_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Watchers button
	watchers_button = _create_button("Watchers", button_x, button_y)
	watchers_button.pressed.connect(_on_watchers_pressed)
	container.add_child(watchers_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Furniture button
	furniture_button = _create_button("Furniture", button_x, button_y)
	furniture_button.pressed.connect(_on_furniture_pressed)
	container.add_child(furniture_button)
	button_y += BUTTON_HEIGHT + SECTION_SPACING

	# Profiler toggle button
	profiler_button = _create_button(_get_profiler_button_text(), button_x, button_y)
	profiler_button.pressed.connect(_on_profiler_pressed)
	container.add_child(profiler_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Debug overlay toggle button
	debug_button = _create_button(_get_debug_button_text(), button_x, button_y)
	debug_button.pressed.connect(_on_debug_pressed)
	container.add_child(debug_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	# Event Log button
	event_log_button = _create_button("Event Log", button_x, button_y)
	event_log_button.pressed.connect(_on_event_log_pressed)
	container.add_child(event_log_button)
	button_y += BUTTON_HEIGHT + SECTION_SPACING

	# Quit button
	quit_button = _create_button("Quit", button_x, button_y)
	quit_button.pressed.connect(_on_quit_pressed)
	container.add_child(quit_button)

func _create_button(text: String, x: float, y: float) -> Button:
	var button = Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", 14)
	return button

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_volume_pressed() -> void:
	if volume_popup == null:
		volume_popup = VolumeSettingsPopup.new()
		volume_popup.close_requested.connect(_on_volume_popup_closed)
		get_tree().root.add_child(volume_popup)
		volume_popup.visible = false
	if audio_manager:
		volume_popup.setup(audio_manager)
	volume_popup.visible = true

func _on_volume_popup_closed() -> void:
	# Volume popup closed, nothing special to do
	pass

func _on_weather_pressed() -> void:
	if weather_popup == null:
		weather_popup = WeatherSettingsPopup.new()
		weather_popup.close_requested.connect(_on_weather_popup_closed)
		get_tree().root.add_child(weather_popup)
		weather_popup.visible = false
	if weather_service:
		weather_popup.setup(weather_service)
	weather_popup.visible = true

func _on_weather_popup_closed() -> void:
	# Weather popup closed, nothing special to do
	pass

func _on_roster_pressed() -> void:
	roster_requested.emit()

func _on_reset_pressed() -> void:
	reset_layout_requested.emit()

func _on_achievements_pressed() -> void:
	achievements_requested.emit()

func _on_watchers_pressed() -> void:
	watchers_requested.emit()

func _on_furniture_pressed() -> void:
	furniture_shelf_requested.emit()

func _on_profiler_pressed() -> void:
	profiler_enabled = not profiler_enabled
	if profiler_button:
		profiler_button.text = _get_profiler_button_text()
	profiler_toggled.emit(profiler_enabled)

func _on_debug_pressed() -> void:
	debug_enabled = not debug_enabled
	if debug_button:
		debug_button.text = _get_debug_button_text()
	debug_toggled.emit(debug_enabled)

func _on_event_log_pressed() -> void:
	event_log_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			resume_requested.emit()
			get_viewport().set_input_as_handled()

func _get_profiler_button_text() -> String:
	return "Profiler: On" if profiler_enabled else "Profiler: Off"

func _get_debug_button_text() -> String:
	return "Debug: On" if debug_enabled else "Debug: Off"
