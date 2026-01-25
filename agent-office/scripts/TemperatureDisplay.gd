extends Node2D
class_name TemperatureDisplay

const DISPLAY_SIZE: Vector2 = Vector2(56, 28)
const BORDER_THICKNESS: float = 1.0
const TEXT_PADDING: Vector2 = Vector2(3, 2)

var background: ColorRect
var border: ColorRect
var temp_label: Label
var condition_label: Label

func _ready() -> void:
	_create_visuals()
	set_status("Weather...")

func _create_visuals() -> void:
	border = ColorRect.new()
	border.size = DISPLAY_SIZE + Vector2(BORDER_THICKNESS * 2, BORDER_THICKNESS * 2)
	border.position = Vector2(-border.size.x / 2, -border.size.y / 2)
	border.color = OfficePalette.WOOD_FRAME
	add_child(border)

	background = ColorRect.new()
	background.size = DISPLAY_SIZE
	background.position = Vector2(-DISPLAY_SIZE.x / 2, -DISPLAY_SIZE.y / 2)
	background.color = OfficePalette.MONITOR_SCREEN_ON
	add_child(background)

	var text_area = DISPLAY_SIZE - TEXT_PADDING * 2
	var text_position = background.position + TEXT_PADDING

	temp_label = Label.new()
	temp_label.position = text_position
	temp_label.size = Vector2(text_area.x, 12)
	temp_label.add_theme_font_size_override("font_size", 9)
	temp_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GREEN_BRIGHT)
	temp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	temp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(temp_label)

	condition_label = Label.new()
	condition_label.position = text_position + Vector2(0, 11)
	condition_label.size = Vector2(text_area.x, 10)
	condition_label.add_theme_font_size_override("font_size", 7)
	condition_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_GREEN)
	condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	condition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(condition_label)

func set_status(text: String) -> void:
	if temp_label:
		temp_label.text = text
	if condition_label:
		condition_label.text = ""

func set_readout(temperature: float, unit_label: String, condition: String) -> void:
	if not temp_label or not condition_label:
		return
	if is_nan(temperature):
		temp_label.text = "Weather offline"
		condition_label.text = ""
		return
	var temp_text = str(int(round(temperature)))
	var condition_text = condition.strip_edges()
	if condition_text == "":
		condition_text = "Clear"
	temp_label.text = "%s%s" % [temp_text, unit_label]
	condition_label.text = condition_text
