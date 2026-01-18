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
var quit_button: Button

# Layout constants
const PANEL_WIDTH: float = 250
const PANEL_HEIGHT: float = 260
const BUTTON_WIDTH: float = 200
const BUTTON_HEIGHT: float = 32
const BUTTON_SPACING: float = 8

func _init() -> void:
	layer = 100

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	var screen_center = Vector2(OfficeConstants.SCREEN_WIDTH / 2, OfficeConstants.SCREEN_HEIGHT / 2)
	var panel_x = screen_center.x - PANEL_WIDTH / 2
	var panel_y = screen_center.y - PANEL_HEIGHT / 2

	# Background overlay (semi-transparent)
	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.position = Vector2.ZERO
	background.color = Color(0, 0, 0, 0.7)
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
	button_y += BUTTON_HEIGHT + BUTTON_SPACING

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

func _on_roster_pressed() -> void:
	roster_requested.emit()

func _on_reset_pressed() -> void:
	reset_layout_requested.emit()

func _on_achievements_pressed() -> void:
	achievements_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			resume_requested.emit()
			get_viewport().set_input_as_handled()
