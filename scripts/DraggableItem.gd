extends Node2D
class_name DraggableItem

signal position_changed(item_name: String, new_position: Vector2)

@export var item_name: String = ""
@export var drag_bounds_min: Vector2 = Vector2(30, 100)
@export var drag_bounds_max: Vector2 = Vector2(1250, 620)
@export var snap_to_grid: bool = true

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var drag_start_position: Vector2 = Vector2.ZERO  # Position before drag started
var click_area: Rect2 = Rect2(-30, -30, 60, 60)  # Default click area

# For collision checking
var navigation_grid: NavigationGrid = null
var obstacle_size: Vector2 = Vector2(40, 40)  # Default size, set by OfficeManager

func _ready() -> void:
	# Will be configured by parent
	# Set initial z_index based on Y position
	z_index = int(position.y)

func _process(_delta: float) -> void:
	# Update z_index based on Y position - items lower on screen render in front
	z_index = int(position.y)

func set_click_area(rect: Rect2) -> void:
	click_area = rect

func _snap_to_grid(pos: Vector2) -> Vector2:
	if not snap_to_grid:
		return pos
	var cell_size = OfficeConstants.CELL_SIZE
	var origin = OfficeConstants.GRID_ORIGIN
	# Snap to cell center
	var gx = round((pos.x - origin.x) / cell_size)
	var gy = round((pos.y - origin.y) / cell_size)
	return Vector2(
		gx * cell_size + origin.x + cell_size / 2.0,
		gy * cell_size + origin.y + cell_size / 2.0
	)

func _get_obstacle_rect(pos: Vector2) -> Rect2:
	return Rect2(pos.x - obstacle_size.x / 2, pos.y - obstacle_size.y / 2, obstacle_size.x, obstacle_size.y)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if click is within our bounds
				var local_pos = get_local_mouse_position()
				if click_area.has_point(local_pos):
					is_dragging = true
					drag_offset = position - get_global_mouse_position()
					drag_start_position = position
			else:
				if is_dragging:
					is_dragging = false
					# Snap to grid on release
					var snapped_pos = _snap_to_grid(position)

					# Check for valid placement (no overlap with other objects)
					if navigation_grid:
						var test_rect = _get_obstacle_rect(snapped_pos)
						if not navigation_grid.can_place_obstacle(test_rect, item_name):
							# Find nearest valid position
							snapped_pos = navigation_grid.find_nearest_valid_position(test_rect, item_name)

					position = snapped_pos
					position_changed.emit(item_name, position)

	elif event is InputEventMouseMotion and is_dragging:
		var new_pos = get_global_mouse_position() + drag_offset
		# Clamp to bounds
		new_pos.x = clamp(new_pos.x, drag_bounds_min.x, drag_bounds_max.x)
		new_pos.y = clamp(new_pos.y, drag_bounds_min.y, drag_bounds_max.y)
		position = new_pos
