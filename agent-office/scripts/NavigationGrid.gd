class_name NavigationGrid

# =============================================================================
# Grid-based navigation system with A* pathfinding
# =============================================================================

class MinHeap:
	var _positions: Array[Vector2i] = []
	var _priorities: Array[float] = []

	func is_empty() -> bool:
		return _positions.is_empty()

	func push(pos: Vector2i, priority: float) -> void:
		_positions.append(pos)
		_priorities.append(priority)
		_sift_up(_positions.size() - 1)

	func pop() -> Dictionary:
		if _positions.is_empty():
			return {}
		var pos = _positions[0]
		var priority = _priorities[0]
		var last_index = _positions.size() - 1
		if last_index == 0:
			_positions.clear()
			_priorities.clear()
			return {"pos": pos, "priority": priority}
		_positions[0] = _positions[last_index]
		_priorities[0] = _priorities[last_index]
		_positions.remove_at(last_index)
		_priorities.remove_at(last_index)
		_sift_down(0)
		return {"pos": pos, "priority": priority}

	func _sift_up(index: int) -> void:
		var i = index
		while i > 0:
			var parent = (i - 1) / 2
			if _priorities[i] >= _priorities[parent]:
				break
			_swap(i, parent)
			i = parent

	func _sift_down(index: int) -> void:
		var i = index
		while true:
			var left = i * 2 + 1
			var right = i * 2 + 2
			var smallest = i
			if left < _positions.size() and _priorities[left] < _priorities[smallest]:
				smallest = left
			if right < _positions.size() and _priorities[right] < _priorities[smallest]:
				smallest = right
			if smallest == i:
				break
			_swap(i, smallest)
			i = smallest

	func _swap(a: int, b: int) -> void:
		var temp_pos = _positions[a]
		_positions[a] = _positions[b]
		_positions[b] = temp_pos
		var temp_priority = _priorities[a]
		_priorities[a] = _priorities[b]
		_priorities[b] = temp_priority

enum CellState { WALKABLE, BLOCKED, WORK_POSITION }

# Grid storage - cells[x][y] = CellState
var cells: Array = []

# Obstacle tracking - obstacle_id -> Array of Vector2i grid positions
var obstacles: Dictionary = {}

# Work position tracking - grid_pos string -> desk reference
var work_positions: Dictionary = {}

# Path cache (start_grid|end_grid -> Array[Vector2i])
const PATH_CACHE_LIMIT: int = 200
var path_cache: Dictionary = {}
var path_cache_order: Array[String] = []

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	cells.clear()
	for x in range(OfficeConstants.GRID_WIDTH):
		var column: Array = []
		for y in range(OfficeConstants.GRID_HEIGHT):
			column.append(CellState.WALKABLE)
		cells.append(column)

func clear() -> void:
	obstacles.clear()
	work_positions.clear()
	clear_path_cache()
	_initialize_grid()

func clear_path_cache() -> void:
	path_cache.clear()
	path_cache_order.clear()

# =============================================================================
# COORDINATE CONVERSION
# =============================================================================

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx = int((world_pos.x - OfficeConstants.GRID_ORIGIN.x) / OfficeConstants.CELL_SIZE)
	var gy = int((world_pos.y - OfficeConstants.GRID_ORIGIN.y) / OfficeConstants.CELL_SIZE)
	return Vector2i(gx, gy)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var wx = grid_pos.x * OfficeConstants.CELL_SIZE + OfficeConstants.GRID_ORIGIN.x
	var wy = grid_pos.y * OfficeConstants.CELL_SIZE + OfficeConstants.GRID_ORIGIN.y
	return Vector2(wx, wy)

func grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	var wx = grid_pos.x * OfficeConstants.CELL_SIZE + OfficeConstants.GRID_ORIGIN.x + OfficeConstants.CELL_SIZE / 2.0
	var wy = grid_pos.y * OfficeConstants.CELL_SIZE + OfficeConstants.GRID_ORIGIN.y + OfficeConstants.CELL_SIZE / 2.0
	return Vector2(wx, wy)

func is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < OfficeConstants.GRID_WIDTH and \
		   grid_pos.y >= 0 and grid_pos.y < OfficeConstants.GRID_HEIGHT

# =============================================================================
# CELL MANAGEMENT
# =============================================================================

func set_cell_state(grid_pos: Vector2i, state: CellState) -> void:
	if is_valid_grid_pos(grid_pos):
		cells[grid_pos.x][grid_pos.y] = state

func get_cell_state(grid_pos: Vector2i) -> CellState:
	if is_valid_grid_pos(grid_pos):
		return cells[grid_pos.x][grid_pos.y]
	return CellState.BLOCKED  # Out of bounds = blocked

func is_walkable(grid_pos: Vector2i) -> bool:
	var state = get_cell_state(grid_pos)
	return state == CellState.WALKABLE or state == CellState.WORK_POSITION

# =============================================================================
# OBSTACLE REGISTRATION
# =============================================================================

func register_obstacle(world_rect: Rect2, obstacle_id: String) -> void:
	# Convert world rect to grid cells and mark as blocked
	var grid_cells: Array[Vector2i] = _rect_to_grid_cells(world_rect)
	obstacles[obstacle_id] = grid_cells
	for cell in grid_cells:
		set_cell_state(cell, CellState.BLOCKED)
	clear_path_cache()

func unregister_obstacle(obstacle_id: String) -> void:
	if obstacles.has(obstacle_id):
		var grid_cells = obstacles[obstacle_id]
		for cell in grid_cells:
			set_cell_state(cell, CellState.WALKABLE)
		obstacles.erase(obstacle_id)
		clear_path_cache()

func update_obstacle(obstacle_id: String, new_world_rect: Rect2) -> void:
	unregister_obstacle(obstacle_id)
	register_obstacle(new_world_rect, obstacle_id)

func get_obstacle_bounds(obstacle_id: String) -> Rect2:
	## Returns world-space bounding rect for an obstacle (for debug visualization)
	if not obstacles.has(obstacle_id):
		return Rect2()
	var cells: Array = obstacles[obstacle_id]
	if cells.is_empty():
		return Rect2()
	# Find bounding box of all cells
	var min_cell: Vector2i = cells[0]
	var max_cell: Vector2i = cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	# Convert to world coordinates
	var top_left = grid_to_world(min_cell)
	var bottom_right = grid_to_world(max_cell + Vector2i(1, 1))
	return Rect2(top_left, bottom_right - top_left)

func get_all_obstacle_ids() -> Array[String]:
	## Returns all registered obstacle IDs
	var ids: Array[String] = []
	for key in obstacles.keys():
		ids.append(key)
	return ids

func can_place_obstacle(world_rect: Rect2, exclude_obstacle_id: String = "") -> bool:
	# Check if the given rect can be placed without overlapping other obstacles
	var grid_cells = _rect_to_grid_cells(world_rect)

	# Get cells occupied by the excluded obstacle (the one being moved)
	var excluded_cells: Array = []
	if exclude_obstacle_id != "" and obstacles.has(exclude_obstacle_id):
		excluded_cells = obstacles[exclude_obstacle_id]

	for cell in grid_cells:
		if not is_valid_grid_pos(cell):
			return false  # Out of bounds
		var state = get_cell_state(cell)
		if state == CellState.BLOCKED:
			# Check if this cell is from the excluded obstacle
			if cell not in excluded_cells:
				return false  # Blocked by another obstacle
	return true

func get_blocking_obstacle(world_rect: Rect2, exclude_obstacle_id: String = "") -> String:
	# Return the ID of the first obstacle blocking this rect
	var grid_cells = _rect_to_grid_cells(world_rect)
	for cell in grid_cells:
		if get_cell_state(cell) == CellState.BLOCKED:
			for obstacle_id in obstacles.keys():
				if obstacle_id != exclude_obstacle_id and cell in obstacles[obstacle_id]:
					return obstacle_id
	return ""

func find_nearest_valid_position(world_rect: Rect2, exclude_obstacle_id: String = "") -> Vector2:
	# If current position is valid, return it
	if can_place_obstacle(world_rect, exclude_obstacle_id):
		return world_rect.position + world_rect.size / 2

	# BFS to find nearest valid position
	var center = world_rect.position + world_rect.size / 2
	var start_grid = world_to_grid(center)
	var queue: Array[Vector2i] = [start_grid]
	var visited: Dictionary = {}
	visited[_grid_pos_to_key(start_grid)] = true

	var half_size = world_rect.size / 2

	while not queue.is_empty():
		var current = queue.pop_front()
		var test_center = grid_to_world_center(current)
		var test_rect = Rect2(test_center - half_size, world_rect.size)

		if can_place_obstacle(test_rect, exclude_obstacle_id):
			return test_center

		# Add neighbors
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor = Vector2i(current.x + dx, current.y + dy)
				var key = _grid_pos_to_key(neighbor)
				if is_valid_grid_pos(neighbor) and not visited.has(key):
					visited[key] = true
					queue.append(neighbor)

	# Fallback to original position
	return center

func _rect_to_grid_cells(world_rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var top_left = world_to_grid(world_rect.position)
	var bottom_right = world_to_grid(world_rect.position + world_rect.size)

	for x in range(top_left.x, bottom_right.x + 1):
		for y in range(top_left.y, bottom_right.y + 1):
			var pos = Vector2i(x, y)
			if is_valid_grid_pos(pos):
				result.append(pos)
	return result

# =============================================================================
# WORK POSITION REGISTRATION
# =============================================================================

func register_work_position(world_pos: Vector2, desk: Node2D) -> void:
	var grid_pos = world_to_grid(world_pos)
	var key = _grid_pos_to_key(grid_pos)
	work_positions[key] = desk
	set_cell_state(grid_pos, CellState.WORK_POSITION)

func unregister_work_position(desk: Node2D) -> void:
	var to_remove: Array[String] = []
	for key in work_positions:
		if work_positions[key] == desk:
			to_remove.append(key)
	for key in to_remove:
		var grid_pos = _key_to_grid_pos(key)
		set_cell_state(grid_pos, CellState.WALKABLE)
		work_positions.erase(key)

func get_desk_for_work_position(world_pos: Vector2) -> Node2D:
	var grid_pos = world_to_grid(world_pos)
	var key = _grid_pos_to_key(grid_pos)
	return work_positions.get(key, null)

func _grid_pos_to_key(grid_pos: Vector2i) -> String:
	return "%d,%d" % [grid_pos.x, grid_pos.y]

func _key_to_grid_pos(key: String) -> Vector2i:
	var parts = key.split(",")
	if parts.size() != 2:
		push_error("[NavigationGrid] Invalid grid pos key: %s" % key)
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _path_cache_key(start: Vector2i, end: Vector2i) -> String:
	return "%d,%d|%d,%d" % [start.x, start.y, end.x, end.y]

func _touch_path_cache(key: String) -> void:
	if path_cache_order.has(key):
		path_cache_order.erase(key)
	path_cache_order.append(key)
	if path_cache_order.size() > PATH_CACHE_LIMIT:
		var oldest = path_cache_order.pop_front()
		path_cache.erase(oldest)

# =============================================================================
# A* PATHFINDING
# =============================================================================

func find_path(start_world: Vector2, end_world: Vector2) -> Array[Vector2]:
	var start_grid = world_to_grid(start_world)
	var end_grid = world_to_grid(end_world)

	# Clamp to valid grid bounds
	start_grid.x = clampi(start_grid.x, 0, OfficeConstants.GRID_WIDTH - 1)
	start_grid.y = clampi(start_grid.y, 0, OfficeConstants.GRID_HEIGHT - 1)
	end_grid.x = clampi(end_grid.x, 0, OfficeConstants.GRID_WIDTH - 1)
	end_grid.y = clampi(end_grid.y, 0, OfficeConstants.GRID_HEIGHT - 1)

	# If start or end is blocked, find nearest walkable cell
	if not is_walkable(start_grid):
		start_grid = _find_nearest_walkable(start_grid)
	if not is_walkable(end_grid):
		end_grid = _find_nearest_walkable(end_grid)

	if start_grid == end_grid:
		return [end_world]

	var cache_key = _path_cache_key(start_grid, end_grid)
	if path_cache.has(cache_key):
		_touch_path_cache(cache_key)
		var cached_path: Array = path_cache[cache_key]
		if cached_path.is_empty():
			return []
		return _smooth_path(cached_path, end_world)

	var grid_path = _astar_search(start_grid, end_grid)
	if grid_path.is_empty():
		# No path found - return empty (let agent handle gracefully)
		print("[NavigationGrid] No path from %s to %s" % [start_world, end_world])
		path_cache[cache_key] = []
		_touch_path_cache(cache_key)
		return []

	path_cache[cache_key] = grid_path
	_touch_path_cache(cache_key)

	var world_path = _smooth_path(grid_path, end_world)
	return world_path

func _astar_search(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var open_set = MinHeap.new()
	var came_from: Dictionary = {}

	var g_score: Dictionary = {}
	g_score[_grid_pos_to_key(start)] = 0.0

	var f_score: Dictionary = {}
	var start_f = _heuristic(start, goal)
	f_score[_grid_pos_to_key(start)] = start_f
	open_set.push(start, start_f)

	var iterations = 0
	var max_iterations = OfficeConstants.GRID_WIDTH * OfficeConstants.GRID_HEIGHT * 2

	while not open_set.is_empty() and iterations < max_iterations:
		iterations += 1

		var current_item = open_set.pop()
		if current_item.is_empty():
			break
		var current = current_item["pos"]
		var current_key = _grid_pos_to_key(current)
		var current_f = current_item["priority"]
		if current_f > f_score.get(current_key, INF):
			continue

		if current == goal:
			return _reconstruct_path(came_from, current)

		for neighbor in _get_neighbors(current):
			var neighbor_key = _grid_pos_to_key(neighbor)
			var move_cost = 1.0 if (neighbor.x == current.x or neighbor.y == current.y) else 1.414
			var tentative_g = g_score.get(current_key, INF) + move_cost

			if tentative_g < g_score.get(neighbor_key, INF):
				came_from[neighbor_key] = current
				g_score[neighbor_key] = tentative_g
				var neighbor_f = tentative_g + _heuristic(neighbor, goal)
				f_score[neighbor_key] = neighbor_f
				open_set.push(neighbor, neighbor_f)

	# No path found
	return []

func _get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	# 8-directional movement
	var directions = [
		Vector2i(0, -1),   # N
		Vector2i(1, -1),   # NE
		Vector2i(1, 0),    # E
		Vector2i(1, 1),    # SE
		Vector2i(0, 1),    # S
		Vector2i(-1, 1),   # SW
		Vector2i(-1, 0),   # W
		Vector2i(-1, -1),  # NW
	]

	for dir in directions:
		var neighbor = pos + dir
		if is_walkable(neighbor):
			# For diagonal movement, check that we're not cutting corners
			if dir.x != 0 and dir.y != 0:
				var horiz = Vector2i(pos.x + dir.x, pos.y)
				var vert = Vector2i(pos.x, pos.y + dir.y)
				if not is_walkable(horiz) or not is_walkable(vert):
					continue  # Can't cut corners
			neighbors.append(neighbor)

	return neighbors

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	# Diagonal distance (Chebyshev with adjustment for diagonal cost)
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return dx + dy + (1.414 - 2) * min(dx, dy)

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	var current_key = _grid_pos_to_key(current)

	while came_from.has(current_key):
		current = came_from[current_key]
		current_key = _grid_pos_to_key(current)
		path.insert(0, current)

	return path

func _smooth_path(grid_path: Array[Vector2i], final_destination: Vector2) -> Array[Vector2]:
	if grid_path.is_empty():
		return []

	# Convert to world coordinates with cell centers
	var world_path: Array[Vector2] = []

	# Simple path smoothing: remove intermediate points that are in a straight line
	var i = 0
	while i < grid_path.size():
		var current = grid_path[i]
		world_path.append(grid_to_world_center(current))

		# Look ahead to find the furthest point we can reach in a straight line
		var furthest = i + 1
		while furthest < grid_path.size() - 1:
			if _can_walk_straight(current, grid_path[furthest + 1]):
				furthest += 1
			else:
				break

		i = furthest
		if i >= grid_path.size():
			break

	# Replace last waypoint with exact destination
	if not world_path.is_empty():
		world_path[world_path.size() - 1] = final_destination

	return world_path

func _can_walk_straight(from: Vector2i, to: Vector2i) -> bool:
	# Bresenham's line algorithm to check if path is clear
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx - dy

	var x = from.x
	var y = from.y

	while true:
		if not is_walkable(Vector2i(x, y)):
			return false

		if x == to.x and y == to.y:
			break

		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

	return true

func _find_nearest_walkable(pos: Vector2i) -> Vector2i:
	# BFS to find nearest walkable cell
	var queue: Array[Vector2i] = [pos]
	var visited: Dictionary = {}
	visited[_grid_pos_to_key(pos)] = true

	while not queue.is_empty():
		var current = queue.pop_front()
		if is_walkable(current):
			return current

		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor = Vector2i(current.x + dx, current.y + dy)
				var key = _grid_pos_to_key(neighbor)
				if is_valid_grid_pos(neighbor) and not visited.has(key):
					visited[key] = true
					queue.append(neighbor)

	return pos  # Fallback to original if nothing found

# =============================================================================
# DEBUG UTILITIES
# =============================================================================

func get_blocked_cell_count() -> int:
	var count = 0
	for x in range(OfficeConstants.GRID_WIDTH):
		for y in range(OfficeConstants.GRID_HEIGHT):
			if cells[x][y] == CellState.BLOCKED:
				count += 1
	return count

func print_grid_summary() -> void:
	var blocked = get_blocked_cell_count()
	var total = OfficeConstants.GRID_WIDTH * OfficeConstants.GRID_HEIGHT
	print("[NavigationGrid] %d/%d cells blocked, %d obstacles registered" % [blocked, total, obstacles.size()])
