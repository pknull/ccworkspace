extends Node2D
class_name AchievementPopup

# =============================================================================
# ACHIEVEMENT POPUP - Single Achievement Unlock Notification
# =============================================================================
# Animated slide-in notification when an achievement is unlocked

signal popup_finished()

var panel: ColorRect
var icon_label: Label
var name_label: Label
var desc_label: Label

var slide_timer: float = 0.0
var display_timer: float = 0.0
const SLIDE_DURATION: float = 0.3
const DISPLAY_DURATION: float = 3.0
var is_sliding_in: bool = true
var is_sliding_out: bool = false

const PANEL_WIDTH: float = 300
const PANEL_HEIGHT: float = 70
var start_x: float = 0.0
var end_x: float = 0.0

func _ready() -> void:
	# Position off-screen right
	start_x = OfficeConstants.SCREEN_WIDTH + 10
	end_x = OfficeConstants.SCREEN_WIDTH - PANEL_WIDTH - 20
	position = Vector2(start_x, 80)
	z_index = OfficeConstants.Z_UI_TOOLTIP
	
	# Create visuals
	_create_visuals()

func _create_visuals() -> void:
	# Panel background
	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.color = OfficePalette.GRUVBOX_BG
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, PANEL_HEIGHT + 4)
	border.position = Vector2(-2, -2)
	border.color = OfficePalette.GRUVBOX_YELLOW
	border.z_index = -1
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	
	# Icon
	icon_label = Label.new()
	icon_label.position = Vector2(10, 10)
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_label)
	
	# Achievement name
	name_label = Label.new()
	name_label.position = Vector2(50, 10)
	name_label.size = Vector2(240, 24)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	
	# Description
	desc_label = Label.new()
	desc_label.position = Vector2(50, 35)
	desc_label.size = Vector2(240, 30)
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(desc_label)

func setup(achievement_name: String, description: String, icon: String) -> void:
	icon_label.text = icon if icon else "[!]"
	name_label.text = achievement_name
	desc_label.text = description

func _process(delta: float) -> void:
	if is_sliding_in:
		slide_timer += delta
		var t = min(slide_timer / SLIDE_DURATION, 1.0)
		# Ease out
		t = 1.0 - pow(1.0 - t, 3)
		position.x = lerp(start_x, end_x, t)
		
		if slide_timer >= SLIDE_DURATION:
			is_sliding_in = false
			position.x = end_x
	elif not is_sliding_out:
		display_timer += delta
		if display_timer >= DISPLAY_DURATION:
			is_sliding_out = true
			slide_timer = 0.0
	else:
		slide_timer += delta
		var t = min(slide_timer / SLIDE_DURATION, 1.0)
		# Ease in
		t = pow(t, 3)
		position.x = lerp(end_x, start_x, t)
		
		if slide_timer >= SLIDE_DURATION:
			popup_finished.emit()
