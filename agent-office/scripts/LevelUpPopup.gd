extends Node2D
class_name LevelUpPopup

# =============================================================================
# LEVEL UP POPUP - Notification when agent levels up
# =============================================================================
# Animated notification that slides in from the right when an agent levels up

signal popup_finished()

# Animation states
enum AnimState { SLIDING_IN, DISPLAYING, SLIDING_OUT, FINISHED }

# Visual elements
var background: ColorRect
var border: ColorRect
var portrait_bg: ColorRect
var name_label: Label
var level_label: Label
var title_label: Label
var star_label: Label

# Animation state
var animation_state: AnimState = AnimState.SLIDING_IN
var animation_progress: float = 0.0
const SLIDE_DURATION: float = 0.4
const DISPLAY_DURATION: float = 3.0
const SLIDE_OUT_DURATION: float = 0.3

# Pulse animation
const PULSE_BASE: float = 0.8
const PULSE_AMPLITUDE: float = 0.2
const PULSE_FREQUENCY: float = 3.0

# Layout
const POPUP_WIDTH: float = 260
const POPUP_HEIGHT: float = 70
const POPUP_Y: float = 180  # Below achievement popups

# Font sizes
const FONT_SIZE_STAR: int = 16
const FONT_SIZE_NAME: int = 14
const FONT_SIZE_LEVEL: int = 12
const FONT_SIZE_TITLE: int = 11

# Computed at runtime
var start_x: float
var end_x: float

func _ready() -> void:
	start_x = OfficeConstants.SCREEN_WIDTH + 10
	end_x = OfficeConstants.SCREEN_WIDTH - POPUP_WIDTH - 20
	_create_visuals()
	position = Vector2(start_x, POPUP_Y)

func setup(agent_name: String, new_level: int, new_title: String) -> void:
	if name_label:
		name_label.text = agent_name
	if level_label:
		level_label.text = "Level %d" % new_level
	if title_label:
		title_label.text = new_title

func _create_visuals() -> void:
	# Border (gold for level up)
	border = ColorRect.new()
	border.size = Vector2(POPUP_WIDTH + 4, POPUP_HEIGHT + 4)
	border.position = Vector2(-2, -2)
	border.color = OfficePalette.GRUVBOX_YELLOW
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	# Main background
	background = ColorRect.new()
	background.size = Vector2(POPUP_WIDTH, POPUP_HEIGHT)
	background.color = OfficePalette.GRUVBOX_BG1
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	# Inner highlight
	var highlight = ColorRect.new()
	highlight.size = Vector2(POPUP_WIDTH - 4, 3)
	highlight.position = Vector2(2, 2)
	highlight.color = OfficePalette.GRUVBOX_YELLOW_BRIGHT
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(highlight)

	# Star icon background
	portrait_bg = ColorRect.new()
	portrait_bg.size = Vector2(44, 44)
	portrait_bg.position = Vector2(10, 13)
	portrait_bg.color = OfficePalette.GRUVBOX_YELLOW
	portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_bg)

	# Star label
	star_label = Label.new()
	star_label.text = "[^]"
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	star_label.position = Vector2(10, 13)
	star_label.size = Vector2(44, 44)
	star_label.add_theme_font_size_override("font_size", FONT_SIZE_STAR)
	star_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_BG)
	star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(star_label)

	# "LEVEL UP!" header
	var header = Label.new()
	header.text = "LEVEL UP!"
	header.position = Vector2(64, 8)
	header.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW_BRIGHT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	# Agent name
	name_label = Label.new()
	name_label.text = "Agent Name"
	name_label.position = Vector2(64, 24)
	name_label.size = Vector2(POPUP_WIDTH - 74, 20)
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_NAME)
	name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	# Level text
	level_label = Label.new()
	level_label.text = "Level X"
	level_label.position = Vector2(64, 42)
	level_label.add_theme_font_size_override("font_size", FONT_SIZE_LEVEL)
	level_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(level_label)

	# Title text
	title_label = Label.new()
	title_label.text = "Title"
	title_label.position = Vector2(140, 42)
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_LEVEL)
	title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_AQUA_BRIGHT)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

func _process(delta: float) -> void:
	match animation_state:
		AnimState.SLIDING_IN:
			_process_slide_in(delta)
		AnimState.DISPLAYING:
			_process_display(delta)
		AnimState.SLIDING_OUT:
			_process_slide_out(delta)
		AnimState.FINISHED:
			popup_finished.emit()
			set_process(false)

func _process_slide_in(delta: float) -> void:
	animation_progress += delta
	var t = min(animation_progress / SLIDE_DURATION, 1.0)
	var eased_t = 1.0 - pow(1.0 - t, 3.0)
	position.x = lerp(start_x, end_x, eased_t)
	modulate.a = t

	if animation_progress >= SLIDE_DURATION:
		animation_progress = 0.0
		animation_state = AnimState.DISPLAYING

func _process_display(delta: float) -> void:
	animation_progress += delta

	# Pulse effect on border
	var pulse = PULSE_BASE + PULSE_AMPLITUDE * sin(animation_progress * PULSE_FREQUENCY)
	border.color = OfficePalette.GRUVBOX_YELLOW.lightened(PULSE_AMPLITUDE * pulse)

	if animation_progress >= DISPLAY_DURATION:
		animation_progress = 0.0
		animation_state = AnimState.SLIDING_OUT

func _process_slide_out(delta: float) -> void:
	animation_progress += delta
	var t = min(animation_progress / SLIDE_OUT_DURATION, 1.0)
	var eased_t = pow(t, 2.0)
	position.x = lerp(end_x, start_x, eased_t)
	modulate.a = 1.0 - t

	if animation_progress >= SLIDE_OUT_DURATION:
		animation_state = AnimState.FINISHED
