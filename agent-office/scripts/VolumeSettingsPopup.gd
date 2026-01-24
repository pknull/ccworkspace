extends CanvasLayer
class_name VolumeSettingsPopup

# =============================================================================
# VOLUME SETTINGS POPUP - Configure audio volumes
# =============================================================================

signal close_requested()

# Layout constants
const PANEL_WIDTH: float = 350
const PANEL_HEIGHT: float = 200
const SLIDER_WIDTH: float = 200
const SLIDER_HEIGHT: float = 20
const LABEL_WIDTH: float = 70
const ROW_SPACING: float = 12
const FONT_SIZE_TITLE: int = 16
const FONT_SIZE_BODY: int = 12

# Visual elements
var container: Control
var background: ColorRect
var panel: ColorRect
var title_label: Label
var close_button: Button

# Volume controls
var typing_slider: HSlider
var meow_slider: HSlider
var achievement_slider: HSlider
var typing_value_label: Label
var meow_value_label: Label
var achievement_value_label: Label
var audio_manager = null

func _init() -> void:
	layer = OfficeConstants.Z_UI_POPUP_LAYER + 1  # Above parent menu

func _ready() -> void:
	_create_visuals()

func setup(p_audio_manager) -> void:
	audio_manager = p_audio_manager
	_sync_volumes()

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
	title_label.text = "VOLUME SETTINGS"
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

	var row_x = panel_x + 25
	var slider_x = row_x + LABEL_WIDTH + 10
	var value_x = slider_x + SLIDER_WIDTH + 10
	var row_y = panel_y + 55

	# Typing volume
	var typing_result = _create_volume_row("Typing", row_x, slider_x, value_x, row_y)
	typing_slider = typing_result[0]
	typing_value_label = typing_result[1]
	typing_slider.value_changed.connect(_on_typing_volume_changed)
	row_y += SLIDER_HEIGHT + ROW_SPACING

	# Meow volume
	var meow_result = _create_volume_row("Meow", row_x, slider_x, value_x, row_y)
	meow_slider = meow_result[0]
	meow_value_label = meow_result[1]
	meow_slider.value_changed.connect(_on_meow_volume_changed)
	row_y += SLIDER_HEIGHT + ROW_SPACING

	# Achievement volume
	var achievement_result = _create_volume_row("Chime", row_x, slider_x, value_x, row_y)
	achievement_slider = achievement_result[0]
	achievement_value_label = achievement_result[1]
	achievement_slider.value_changed.connect(_on_achievement_volume_changed)

func _create_volume_row(label_text: String, label_x: float, slider_x: float, value_x: float, y: float) -> Array:
	var label = Label.new()
	label.text = label_text
	label.position = Vector2(label_x, y + 2)
	label.size = Vector2(LABEL_WIDTH, SLIDER_HEIGHT)
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	container.add_child(label)

	var slider = HSlider.new()
	slider.position = Vector2(slider_x, y)
	slider.size = Vector2(SLIDER_WIDTH, SLIDER_HEIGHT)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 0.5
	container.add_child(slider)

	var value_label = Label.new()
	value_label.text = "50%"
	value_label.position = Vector2(value_x, y + 2)
	value_label.size = Vector2(40, SLIDER_HEIGHT)
	value_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	value_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(value_label)

	return [slider, value_label]

func _sync_volumes() -> void:
	if not audio_manager:
		return
	if typing_slider and audio_manager.has_method("get_typing_volume"):
		typing_slider.value = audio_manager.get_typing_volume()
		_update_value_label(typing_value_label, typing_slider.value)
	if meow_slider and audio_manager.has_method("get_meow_volume"):
		meow_slider.value = audio_manager.get_meow_volume()
		_update_value_label(meow_value_label, meow_slider.value)
	if achievement_slider and audio_manager.has_method("get_achievement_volume"):
		achievement_slider.value = audio_manager.get_achievement_volume()
		_update_value_label(achievement_value_label, achievement_slider.value)

func _update_value_label(label: Label, value: float) -> void:
	if label:
		label.text = "%d%%" % int(value * 100)

func _on_typing_volume_changed(value: float) -> void:
	_update_value_label(typing_value_label, value)
	if audio_manager and audio_manager.has_method("set_typing_volume"):
		audio_manager.set_typing_volume(value)

func _on_meow_volume_changed(value: float) -> void:
	_update_value_label(meow_value_label, value)
	if audio_manager and audio_manager.has_method("set_meow_volume"):
		audio_manager.set_meow_volume(value)

func _on_achievement_volume_changed(value: float) -> void:
	_update_value_label(achievement_value_label, value)
	if audio_manager and audio_manager.has_method("set_achievement_volume"):
		audio_manager.set_achievement_volume(value)

func _on_close_pressed() -> void:
	visible = false
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
