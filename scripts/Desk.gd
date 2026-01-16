extends Node2D
class_name Desk

var is_occupied: bool = false

# Visual nodes
var desk_rect: ColorRect
var monitor: ColorRect
var status_indicator: ColorRect

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	# Desk surface - beige laminate like Wernham Hogg
	desk_rect = ColorRect.new()
	desk_rect.size = Vector2(90, 55)
	desk_rect.position = Vector2(-45, -5)
	desk_rect.color = Color(0.76, 0.70, 0.60)  # Beige laminate
	add_child(desk_rect)

	# Desk edge (darker trim)
	var desk_edge = ColorRect.new()
	desk_edge.size = Vector2(90, 4)
	desk_edge.position = Vector2(-45, 46)
	desk_edge.color = Color(0.45, 0.40, 0.35)
	add_child(desk_edge)

	# Monitor base/stand
	var monitor_stand = ColorRect.new()
	monitor_stand.size = Vector2(20, 8)
	monitor_stand.position = Vector2(-10, -8)
	monitor_stand.color = Color(0.25, 0.25, 0.28)
	add_child(monitor_stand)

	# Monitor - chunky CRT style
	monitor = ColorRect.new()
	monitor.size = Vector2(44, 36)
	monitor.position = Vector2(-22, -42)
	monitor.color = Color(0.82, 0.80, 0.75)  # Beige plastic (old monitor)
	add_child(monitor)

	# Monitor bezel (inner frame)
	var bezel = ColorRect.new()
	bezel.size = Vector2(38, 28)
	bezel.position = Vector2(-19, -39)
	bezel.color = Color(0.2, 0.2, 0.22)
	add_child(bezel)

	# Monitor screen
	var screen = ColorRect.new()
	screen.size = Vector2(34, 24)
	screen.position = Vector2(-17, -37)
	screen.color = Color(0.15, 0.22, 0.18)  # Dark green-ish (old CRT)
	add_child(screen)

	# Keyboard
	var keyboard = ColorRect.new()
	keyboard.size = Vector2(36, 12)
	keyboard.position = Vector2(-18, 18)
	keyboard.color = Color(0.85, 0.83, 0.78)  # Beige keyboard
	add_child(keyboard)

	# Mouse
	var mouse = ColorRect.new()
	mouse.size = Vector2(8, 12)
	mouse.position = Vector2(24, 20)
	mouse.color = Color(0.85, 0.83, 0.78)
	add_child(mouse)

	# Stack of papers (left side)
	var papers = ColorRect.new()
	papers.size = Vector2(18, 14)
	papers.position = Vector2(-42, 10)
	papers.color = Color(0.95, 0.95, 0.92)  # White paper
	add_child(papers)

	# Coffee mug (right side)
	var mug = ColorRect.new()
	mug.size = Vector2(10, 14)
	mug.position = Vector2(32, 8)
	mug.color = Color(0.9, 0.9, 0.9)  # White mug
	add_child(mug)

	# Mug handle
	var handle = ColorRect.new()
	handle.size = Vector2(4, 8)
	handle.position = Vector2(42, 11)
	handle.color = Color(0.9, 0.9, 0.9)
	add_child(handle)

	# Pen holder
	var pen_holder = ColorRect.new()
	pen_holder.size = Vector2(8, 12)
	pen_holder.position = Vector2(-38, -2)
	pen_holder.color = Color(0.3, 0.3, 0.35)
	add_child(pen_holder)

	# Pens sticking out
	var pen1 = ColorRect.new()
	pen1.size = Vector2(2, 8)
	pen1.position = Vector2(-37, -8)
	pen1.color = Color(0.1, 0.2, 0.6)  # Blue pen
	add_child(pen1)

	var pen2 = ColorRect.new()
	pen2.size = Vector2(2, 6)
	pen2.position = Vector2(-34, -6)
	pen2.color = Color(0.6, 0.1, 0.1)  # Red pen
	add_child(pen2)

	# Status indicator (power light on monitor)
	status_indicator = ColorRect.new()
	status_indicator.size = Vector2(6, 6)
	status_indicator.position = Vector2(12, -12)
	status_indicator.color = Color(0.2, 0.7, 0.2)  # Green = available
	add_child(status_indicator)

func get_work_position() -> Vector2:
	# Position where agent should stand (in front of desk)
	return global_position + Vector2(0, 70)

func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	if status_indicator:
		status_indicator.color = Color(0.8, 0.3, 0.2) if occupied else Color(0.2, 0.7, 0.2)

func is_available() -> bool:
	return not is_occupied
