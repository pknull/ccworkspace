extends Node2D
class_name WallClock

# A wall clock that displays real time with hour and minute hands

const CLOCK_RADIUS: float = 20.0
const HOUR_HAND_LENGTH: float = 10.0
const MINUTE_HAND_LENGTH: float = 14.0
const SECOND_HAND_LENGTH: float = 16.0

var hour_hand: ColorRect
var minute_hand: ColorRect
var second_hand: ColorRect
var center_dot: ColorRect

func _ready() -> void:
	_create_visuals()
	_update_hands()

func _create_visuals() -> void:
	# Clock face (circular approximation - octagonal would be better but square is simpler)
	var face = ColorRect.new()
	face.size = Vector2(CLOCK_RADIUS * 2, CLOCK_RADIUS * 2)
	face.position = Vector2(-CLOCK_RADIUS, -CLOCK_RADIUS)
	face.color = OfficePalette.GRUVBOX_LIGHT
	add_child(face)

	# Clock rim
	var rim = ColorRect.new()
	rim.size = Vector2(CLOCK_RADIUS * 2 + 4, CLOCK_RADIUS * 2 + 4)
	rim.position = Vector2(-CLOCK_RADIUS - 2, -CLOCK_RADIUS - 2)
	rim.color = OfficePalette.WOOD_FRAME
	rim.z_index = -1
	add_child(rim)

	# Hour markers (12, 3, 6, 9 only for simplicity)
	var marker_positions = [
		Vector2(0, -CLOCK_RADIUS + 4),   # 12
		Vector2(CLOCK_RADIUS - 4, 0),     # 3
		Vector2(0, CLOCK_RADIUS - 4),     # 6
		Vector2(-CLOCK_RADIUS + 4, 0),    # 9
	]
	for pos in marker_positions:
		var marker = ColorRect.new()
		marker.size = Vector2(2, 4)
		marker.position = pos - Vector2(1, 2)
		marker.color = OfficePalette.UI_TEXT_DARK
		add_child(marker)

	# Hour hand (short and thick)
	hour_hand = ColorRect.new()
	hour_hand.size = Vector2(3, HOUR_HAND_LENGTH)
	hour_hand.position = Vector2(-1.5, -HOUR_HAND_LENGTH)
	hour_hand.color = OfficePalette.UI_TEXT_DARK
	hour_hand.pivot_offset = Vector2(1.5, HOUR_HAND_LENGTH)
	add_child(hour_hand)

	# Minute hand (longer and thinner)
	minute_hand = ColorRect.new()
	minute_hand.size = Vector2(2, MINUTE_HAND_LENGTH)
	minute_hand.position = Vector2(-1, -MINUTE_HAND_LENGTH)
	minute_hand.color = OfficePalette.UI_TEXT_DARK
	minute_hand.pivot_offset = Vector2(1, MINUTE_HAND_LENGTH)
	add_child(minute_hand)

	# Second hand (longest and thinnest, red)
	second_hand = ColorRect.new()
	second_hand.size = Vector2(1, SECOND_HAND_LENGTH)
	second_hand.position = Vector2(-0.5, -SECOND_HAND_LENGTH)
	second_hand.color = OfficePalette.GRUVBOX_RED
	second_hand.pivot_offset = Vector2(0.5, SECOND_HAND_LENGTH)
	add_child(second_hand)

	# Center dot
	center_dot = ColorRect.new()
	center_dot.size = Vector2(4, 4)
	center_dot.position = Vector2(-2, -2)
	center_dot.color = OfficePalette.UI_TEXT_DARK
	add_child(center_dot)

func _process(_delta: float) -> void:
	_update_hands()

func _update_hands() -> void:
	var time = Time.get_time_dict_from_system()
	var hours = time.hour % 12
	var minutes = time.minute
	var seconds = time.second

	# Calculate angles (0 = 12 o'clock, clockwise)
	var hour_angle = (hours + minutes / 60.0) * (PI * 2 / 12.0)
	var minute_angle = (minutes + seconds / 60.0) * (PI * 2 / 60.0)
	var second_angle = seconds * (PI * 2 / 60.0)

	hour_hand.rotation = hour_angle
	minute_hand.rotation = minute_angle
	second_hand.rotation = second_angle
