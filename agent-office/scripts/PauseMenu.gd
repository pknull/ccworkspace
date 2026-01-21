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
var reset_button: Button
var achievements_button: Button
var profiler_button: Button
var debug_button: Button
var event_log_button: Button
var quit_button: Button
var profiler_enabled: bool = false
var debug_enabled: bool = false

# Weather controls
var weather_label: Label
var weather_mode_button: Button
var weather_units_button: Button
var weather_location_input: LineEdit

# Volume sliders
var typing_slider: HSlider
var meow_slider: HSlider
var achievement_slider: HSlider
var typing_label: Label
var meow_label: Label
var achievement_label: Label

# Audio manager reference (set by OfficeManager)
var audio_manager = null
var weather_service = null

# Layout constants
const PANEL_WIDTH: float = 280
const PANEL_HEIGHT: float = 680
const BUTTON_WIDTH: float = 200
const BUTTON_HEIGHT: float = 32
const BUTTON_SPACING: float = 8
const SLIDER_HEIGHT: float = 20
const VOLUME_SECTION_SPACING: float = 12
const VOLUME_LABEL_WIDTH: float = 70
const VOLUME_LABEL_HEIGHT: float = 22

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
	button_y += BUTTON_HEIGHT + BUTTON_SPACING + VOLUME_SECTION_SPACING

	# Volume controls section
	var volume_label = Label.new()
	volume_label.text = "— Volume —"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_label.position = Vector2(panel_x, button_y)
	volume_label.size = Vector2(PANEL_WIDTH, 20)
	volume_label.add_theme_font_size_override("font_size", 12)
	volume_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GRAY)
	container.add_child(volume_label)
	button_y += VOLUME_LABEL_HEIGHT

	# Typing volume
	typing_label = Label.new()
	typing_label.text = "Typing"
	typing_label.position = Vector2(button_x, button_y)
	typing_label.size = Vector2(VOLUME_LABEL_WIDTH, SLIDER_HEIGHT)
	typing_label.add_theme_font_size_override("font_size", 12)
	typing_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	container.add_child(typing_label)
	typing_slider = _create_slider(button_x + VOLUME_LABEL_WIDTH + 5, button_y, BUTTON_WIDTH - VOLUME_LABEL_WIDTH - 5)
	typing_slider.value_changed.connect(_on_typing_volume_changed)
	container.add_child(typing_slider)
	button_y += SLIDER_HEIGHT + BUTTON_SPACING

	# Cat volume
	meow_label = Label.new()
	meow_label.text = "Meow"
	meow_label.position = Vector2(button_x, button_y)
	meow_label.size = Vector2(VOLUME_LABEL_WIDTH, SLIDER_HEIGHT)
	meow_label.add_theme_font_size_override("font_size", 12)
	meow_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	container.add_child(meow_label)
	meow_slider = _create_slider(button_x + VOLUME_LABEL_WIDTH + 5, button_y, BUTTON_WIDTH - VOLUME_LABEL_WIDTH - 5)
	meow_slider.value_changed.connect(_on_meow_volume_changed)
	container.add_child(meow_slider)
	button_y += SLIDER_HEIGHT + BUTTON_SPACING

	# Achievement volume
	achievement_label = Label.new()
	achievement_label.text = "Chime"
	achievement_label.position = Vector2(button_x, button_y)
	achievement_label.size = Vector2(VOLUME_LABEL_WIDTH, SLIDER_HEIGHT)
	achievement_label.add_theme_font_size_override("font_size", 12)
	achievement_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	container.add_child(achievement_label)
	achievement_slider = _create_slider(button_x + VOLUME_LABEL_WIDTH + 5, button_y, BUTTON_WIDTH - VOLUME_LABEL_WIDTH - 5)
	achievement_slider.value_changed.connect(_on_achievement_volume_changed)
	container.add_child(achievement_slider)
	button_y += SLIDER_HEIGHT + BUTTON_SPACING + VOLUME_SECTION_SPACING

	# Weather controls section
	weather_label = Label.new()
	weather_label.text = "— Weather —"
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_label.position = Vector2(panel_x, button_y)
	weather_label.size = Vector2(PANEL_WIDTH, 20)
	weather_label.add_theme_font_size_override("font_size", 12)
	weather_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GRAY)
	container.add_child(weather_label)
	button_y += VOLUME_LABEL_HEIGHT

	weather_mode_button = _create_button(_get_weather_mode_button_text(), button_x, button_y)
	weather_mode_button.pressed.connect(_on_weather_mode_pressed)
	container.add_child(weather_mode_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	weather_location_input = LineEdit.new()
	weather_location_input.position = Vector2(button_x, button_y)
	weather_location_input.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	weather_location_input.placeholder_text = "City, Region (Enter)"
	weather_location_input.add_theme_font_size_override("font_size", 12)
	weather_location_input.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	weather_location_input.text_submitted.connect(_on_weather_location_submitted)
	weather_location_input.focus_exited.connect(_on_weather_location_focus_exited)
	container.add_child(weather_location_input)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

	weather_units_button = _create_button(_get_weather_units_button_text(), button_x, button_y)
	weather_units_button.pressed.connect(_on_weather_units_pressed)
	container.add_child(weather_units_button)
	button_y += BUTTON_HEIGHT + BUTTON_SPACING + VOLUME_SECTION_SPACING

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
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

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

func _create_slider(x: float, y: float, width: float) -> HSlider:
	var slider = HSlider.new()
	slider.position = Vector2(x, y)
	slider.size = Vector2(width, SLIDER_HEIGHT)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 0.5
	return slider

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_roster_pressed() -> void:
	roster_requested.emit()

func _on_reset_pressed() -> void:
	reset_layout_requested.emit()

func _on_achievements_pressed() -> void:
	achievements_requested.emit()

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

func _get_weather_mode_button_text() -> String:
	if weather_service and weather_service.is_auto_location():
		return "Location: Auto"
	return "Location: Custom"

func _get_weather_units_button_text() -> String:
	if weather_service and weather_service.is_fahrenheit():
		return "Units: F"
	return "Units: C"

# Volume callbacks
func _on_typing_volume_changed(value: float) -> void:
	if audio_manager:
		audio_manager.set_typing_volume(value)

func _on_meow_volume_changed(value: float) -> void:
	if audio_manager:
		audio_manager.set_meow_volume(value)

func _on_achievement_volume_changed(value: float) -> void:
	if audio_manager:
		audio_manager.set_achievement_volume(value)

func _on_weather_mode_pressed() -> void:
	if weather_service:
		weather_service.set_use_auto_location(not weather_service.is_auto_location())
		sync_weather_settings()

func _on_weather_units_pressed() -> void:
	if weather_service:
		weather_service.set_use_fahrenheit(not weather_service.is_fahrenheit())
		sync_weather_settings()

func _on_weather_location_submitted(text: String) -> void:
	_apply_weather_location(text)

func _on_weather_location_focus_exited() -> void:
	if weather_location_input:
		_apply_weather_location(weather_location_input.text)

func _apply_weather_location(text: String) -> void:
	if not weather_service:
		return
	var trimmed = text.strip_edges()
	if trimmed == "":
		weather_service.set_use_auto_location(true)
	else:
		weather_service.set_custom_location(trimmed)
	sync_weather_settings()

# Initialize sliders from AudioManager values
func sync_volume_sliders() -> void:
	if audio_manager:
		if typing_slider:
			typing_slider.set_value_no_signal(audio_manager.get_typing_volume())
		if meow_slider:
			meow_slider.set_value_no_signal(audio_manager.get_meow_volume())
		if achievement_slider:
			achievement_slider.set_value_no_signal(audio_manager.get_achievement_volume())

func sync_weather_settings() -> void:
	if not weather_service:
		return
	var is_auto = weather_service.is_auto_location()
	if weather_mode_button:
		weather_mode_button.text = _get_weather_mode_button_text()
	if weather_units_button:
		weather_units_button.text = _get_weather_units_button_text()
	if weather_location_input:
		weather_location_input.editable = not is_auto
		if is_auto:
			weather_location_input.text = ""
			weather_location_input.placeholder_text = "Auto (office)"
		else:
			weather_location_input.text = weather_service.get_location_query()
			weather_location_input.placeholder_text = "City, Region (Enter)"
