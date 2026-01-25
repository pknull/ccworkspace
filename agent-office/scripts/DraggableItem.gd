extends Node2D
class_name DraggableItem

signal position_changed(item_name: String, new_position: Vector2)

@export var item_name: String = ""
@export var drag_bounds_min: Vector2 = Vector2(30, 100)
@export var drag_bounds_max: Vector2 = Vector2(1250, 620)
@export var snap_to_grid: bool = true
@export var use_dynamic_z_index: bool = true  # False for wall-mounted items (taskboard)

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var click_area: Rect2 = Rect2(-30, -30, 60, 60)  # Default click area

# Visual center offset - for items where position is not the visual center (e.g., taskboard)
# Set this to the offset from position to the visual center of the item
var visual_center_offset: Vector2 = Vector2.ZERO

# Drag preview visuals
var ghost_preview: Node2D = null      # Semi-transparent copy at snap position
var grid_overlay: Node2D = null       # Container for grid cell visuals

# For collision checking
var navigation_grid: NavigationGrid = null
var office_manager: Node = null  # Set by OfficeManager to check popup state
var obstacle_size: Vector2 = Vector2(40, 40)  # Default size, set by OfficeManager

func _ready() -> void:
	# Will be configured by parent
	# Set initial z_index based on Y position (only for floor items)
	if use_dynamic_z_index:
		z_index = int(position.y)

func _process(_delta: float) -> void:
	# Only update z_index while dragging (no need to update every frame when stationary)
	if is_dragging and use_dynamic_z_index:
		z_index = int(position.y)

func set_click_area(rect: Rect2) -> void:
	click_area = rect

func _snap_to_grid(pos: Vector2) -> Vector2:
	if not snap_to_grid:
		return pos
	return OfficeConstants.snap_to_grid(pos)

func _get_obstacle_rect(pos: Vector2) -> Rect2:
	return Rect2(pos.x - obstacle_size.x / 2, pos.y - obstacle_size.y / 2, obstacle_size.x, obstacle_size.y)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Don't start dragging if a popup is open
				if office_manager and office_manager.has_method("is_any_popup_open") and office_manager.is_any_popup_open():
					return
				# Check if click is within our bounds
				var local_pos = get_local_mouse_position()
				if click_area.has_point(local_pos):
					is_dragging = true
					drag_offset = position - get_global_mouse_position()
					_create_ghost_preview()
					_create_grid_overlay()
			else:
				if is_dragging:
					is_dragging = false
					# Use ghost position if valid, otherwise find nearest valid
					var snapped_pos = _snap_to_grid(position)
					var original_snapped = snapped_pos

					# Check for valid placement (no overlap with other objects)
					if navigation_grid:
						var test_rect = _get_obstacle_rect(snapped_pos)
						if not navigation_grid.can_place_obstacle(test_rect, item_name):
							# Find nearest valid position
							snapped_pos = navigation_grid.find_nearest_valid_position(test_rect, item_name)
							if OfficeConstants.DEBUG_EVENTS:
								print("[DraggableItem] %s: position adjusted from %s to %s (collision detected)" % [item_name, original_snapped, snapped_pos])

					position = snapped_pos
					_cleanup_drag_visuals()
					position_changed.emit(item_name, position)

	elif event is InputEventMouseMotion and is_dragging:
		var new_pos = get_global_mouse_position() + drag_offset
		# Clamp to bounds
		new_pos.x = clamp(new_pos.x, drag_bounds_min.x, drag_bounds_max.x)
		new_pos.y = clamp(new_pos.y, drag_bounds_min.y, drag_bounds_max.y)
		position = new_pos

		# Update ghost preview position and validity
		var snapped_pos = _snap_to_grid(new_pos)
		if ghost_preview:
			ghost_preview.position = snapped_pos
		if grid_overlay:
			grid_overlay.position = snapped_pos

		# Check placement validity and update ghost color
		var is_valid = true
		if navigation_grid:
			var test_rect = _get_obstacle_rect(snapped_pos)
			is_valid = navigation_grid.can_place_obstacle(test_rect, item_name)
		_update_ghost_validity(is_valid)


func _create_ghost_preview() -> void:
	if not get_parent():
		return
	ghost_preview = Node2D.new()
	ghost_preview.z_index = z_index + 100

	# Copy all ColorRect children as semi-transparent and hide originals
	for child in get_children():
		if child is ColorRect:
			var ghost_rect = ColorRect.new()
			ghost_rect.size = child.size
			ghost_rect.position = child.position
			ghost_rect.color = child.color
			ghost_rect.modulate.a = 0.6
			ghost_preview.add_child(ghost_rect)
			child.visible = false  # Hide original while dragging

	# If no ColorRects found, ghost_preview will be empty but still functional
	get_parent().add_child(ghost_preview)
	ghost_preview.position = _snap_to_grid(position)


func _create_grid_overlay() -> void:
	if not get_parent():
		return
	grid_overlay = Node2D.new()
	grid_overlay.z_index = z_index - 1

	# Draw 7x7 grid of cells centered on item's visual center
	# Offset by -cell_size/2 to center cells on grid intersections
	var cell_size = OfficeConstants.CELL_SIZE
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var cell = ColorRect.new()
			cell.size = Vector2(cell_size - 1, cell_size - 1)
			# Apply visual_center_offset so grid is centered on visual center, not position
			cell.position = Vector2(
				dx * cell_size - cell_size / 2.0 + visual_center_offset.x,
				dy * cell_size - cell_size / 2.0 + visual_center_offset.y
			)
			cell.color = Color(1.0, 1.0, 1.0, 0.08)  # Subtle white grid
			grid_overlay.add_child(cell)

	get_parent().add_child(grid_overlay)
	grid_overlay.position = _snap_to_grid(position)


func _update_ghost_validity(is_valid: bool) -> void:
	if not ghost_preview:
		return
	var tint = OfficePalette.GRUVBOX_GREEN if is_valid else OfficePalette.GRUVBOX_RED
	for child in ghost_preview.get_children():
		if child is ColorRect:
			child.modulate = Color(tint.r, tint.g, tint.b, 0.6)


func _cleanup_drag_visuals() -> void:
	# Show original children again
	for child in get_children():
		if child is ColorRect:
			child.visible = true

	if ghost_preview:
		ghost_preview.queue_free()
		ghost_preview = null
	if grid_overlay:
		grid_overlay.queue_free()
		grid_overlay = null
