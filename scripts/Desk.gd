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
	# Desk surface
	desk_rect = ColorRect.new()
	desk_rect.size = Vector2(80, 50)
	desk_rect.position = Vector2(-40, 0)
	desk_rect.color = Color(0.55, 0.35, 0.2)  # Wood brown
	add_child(desk_rect)

	# Monitor
	monitor = ColorRect.new()
	monitor.size = Vector2(40, 30)
	monitor.position = Vector2(-20, -30)
	monitor.color = Color(0.2, 0.2, 0.25)  # Dark gray
	add_child(monitor)

	# Monitor screen
	var screen = ColorRect.new()
	screen.size = Vector2(36, 26)
	screen.position = Vector2(-18, -28)
	screen.color = Color(0.1, 0.3, 0.5)  # Blue screen
	add_child(screen)

	# Status indicator (small light)
	status_indicator = ColorRect.new()
	status_indicator.size = Vector2(8, 8)
	status_indicator.position = Vector2(30, -5)
	status_indicator.color = Color(0.2, 0.8, 0.2)  # Green = available
	add_child(status_indicator)

func get_work_position() -> Vector2:
	# Position where agent should stand (in front of desk)
	return global_position + Vector2(0, 60)

func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	if status_indicator:
		status_indicator.color = Color(0.8, 0.2, 0.2) if occupied else Color(0.2, 0.8, 0.2)

func is_available() -> bool:
	return not is_occupied
