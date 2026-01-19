extends Node2D
class_name OfficeCat

enum State { IDLE, WALKING, SITTING, GROOMING, SLEEPING, STRETCHING }

var state: State = State.IDLE
var target_position: Vector2
var speed: float = OfficeConstants.CAT_WALK_SPEED

# Timers
var state_timer: float = 0.0
var next_action_time: float = 3.0
var animation_timer: float = 0.0

# Meow speech bubbles
var meow_bubble: Node2D = null
var meow_timer: float = 0.0
var meow_cooldown: float = 0.0
const MEOW_CHECK_INTERVAL: float = 20.0  # Check every 20 seconds
const MEOW_CHANCE: float = 0.18  # 18% chance when checked
const MEOW_COOLDOWN: float = 40.0  # Minimum 40s between meows
const PATH_REROUTE_ATTEMPTS: int = 8  # Attempts to find alternate path before giving up
const STEER_MULTIPLIER: float = 3.0  # How far to steer perpendicular (frames worth)

const MEOW_PHRASES = [
	"meow", "mrrp?", "prrrr", "mew!", "nya~", "*purr*",
	"meow?", "mrow!", "*stretch*", "prrt!", "mrrrow",
]

# Visual nodes
var body: ColorRect
var head: ColorRect
var ears: Array[ColorRect] = []
var tail: ColorRect
var eyes: Array[ColorRect] = []
var sleeping_z: Label  # Zzz indicator

# Cat appearance
var cat_color: Color = OfficePalette.CAT_ORANGE_TABBY  # Orange tabby by default
var is_facing_left: bool = true  # Starts facing left (head on left side)

# Boundaries for wandering
var bounds_min: Vector2 = Vector2(30, 100)
var bounds_max: Vector2 = Vector2(1250, 620)  # Full width like other furniture

# Obstacles to avoid (desks, furniture, etc.)
var obstacle_rects: Array[Rect2] = []
const DESK_SIZE: Vector2 = Vector2(80, 28)  # Matches OfficeConstants.DESK_WIDTH x DESK_DEPTH
const CAT_COLLIDER_SIZE: Vector2 = Vector2(22, 10)
const STUCK_DISTANCE_EPS: float = 0.75
const STUCK_TIMEOUT: float = 1.5
const CAT_WALL_MARGIN: float = 18.0
const CAT_NUDGE_RADIUS: float = 18.0

# Dragging
var is_being_dragged: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
var nap_spot: Vector2 = Vector2.ZERO
var pending_sleep: bool = false
var cat_bed_position: Vector2 = Vector2.ZERO
var consecutive_blocks: int = 0  # Track how many frames we've been blocked

# A* Pathfinding (uses same grid as agents)
var navigation_grid: NavigationGrid = null
var path_waypoints: Array[Vector2] = []
var current_waypoint_index: int = 0

# Audio
var audio_manager = null  # AudioManager instance

func _ready() -> void:
	_randomize_appearance()
	_create_visuals()
	position = Vector2(randf_range(bounds_min.x, bounds_max.x), randf_range(bounds_min.y, bounds_max.y))
	next_action_time = randf_range(2.0, 5.0)
	last_position = position
	nap_spot = _find_valid_nap_spot()

func _randomize_appearance() -> void:
	# Random cat colors (using Gruvbox palette)
	var colors = [
		OfficePalette.CAT_ORANGE_TABBY,   # Orange tabby
		OfficePalette.CAT_BLACK,          # Black
		OfficePalette.CAT_WHITE,          # White
		OfficePalette.CAT_GRAY,           # Gray
		OfficePalette.CAT_BROWN_TABBY,    # Brown tabby
		OfficePalette.CAT_CREAM,          # Cream
	]
	cat_color = colors[randi() % colors.size()]

func _create_visuals() -> void:
	# Shadow under cat
	var shadow = ColorRect.new()
	shadow.size = Vector2(24, 8)
	shadow.position = Vector2(-12, 10)
	shadow.color = OfficePalette.SHADOW
	shadow.z_index = -4
	add_child(shadow)

	# Tail (behind body)
	tail = ColorRect.new()
	tail.size = Vector2(14, 4)
	tail.position = Vector2(10, -2)
	tail.color = cat_color.darkened(0.05)
	tail.z_index = -3
	add_child(tail)

	# Body (oval-ish via rectangle)
	body = ColorRect.new()
	body.size = Vector2(24, 12)
	body.position = Vector2(-12, 0)
	body.color = cat_color
	body.z_index = -2
	add_child(body)

	# Head (as container for face parts)
	head = ColorRect.new()
	head.size = Vector2(12, 10)
	head.position = Vector2(-18, -6)  # Head in front (facing left by default)
	head.color = cat_color
	head.z_index = -1
	add_child(head)

	# Ears (children of head, positioned relative to head)
	var ear_left = ColorRect.new()
	ear_left.size = Vector2(4, 6)
	ear_left.position = Vector2(0, -5)  # Relative to head
	ear_left.color = cat_color.darkened(0.1)
	head.add_child(ear_left)
	ears.append(ear_left)

	var ear_right = ColorRect.new()
	ear_right.size = Vector2(4, 6)
	ear_right.position = Vector2(8, -5)  # Relative to head
	ear_right.color = cat_color.darkened(0.1)
	head.add_child(ear_right)
	ears.append(ear_right)

	# Inner ears (pink) - children of head
	var inner_left = ColorRect.new()
	inner_left.size = Vector2(2, 3)
	inner_left.position = Vector2(1, -4)
	inner_left.color = OfficePalette.CAT_INNER_EAR
	head.add_child(inner_left)

	var inner_right = ColorRect.new()
	inner_right.size = Vector2(2, 3)
	inner_right.position = Vector2(9, -4)
	inner_right.color = OfficePalette.CAT_INNER_EAR
	head.add_child(inner_right)

	# Eyes (children of head)
	var eye_left = ColorRect.new()
	eye_left.size = Vector2(3, 3)
	eye_left.position = Vector2(2, 3)  # Relative to head
	eye_left.color = OfficePalette.CAT_EYES_GREEN
	head.add_child(eye_left)
	eyes.append(eye_left)

	var eye_right = ColorRect.new()
	eye_right.size = Vector2(3, 3)
	eye_right.position = Vector2(7, 3)  # Relative to head
	eye_right.color = OfficePalette.CAT_EYES_GREEN
	head.add_child(eye_right)
	eyes.append(eye_right)

	# Nose (child of head)
	var nose = ColorRect.new()
	nose.size = Vector2(2, 2)
	nose.position = Vector2(5, 6)  # Relative to head
	nose.color = OfficePalette.CAT_INNER_EAR  # Same pink as inner ear
	head.add_child(nose)

	# Sleeping Zzz (hidden by default)
	sleeping_z = Label.new()
	sleeping_z.text = "z z z"
	sleeping_z.position = Vector2(-5, -20)
	sleeping_z.add_theme_font_size_override("font_size", 10)
	sleeping_z.add_theme_color_override("font_color", OfficePalette.CAT_SLEEPING_Z)
	sleeping_z.visible = false
	add_child(sleeping_z)

func _process(delta: float) -> void:
	# Skip normal behavior when being dragged
	if is_being_dragged:
		return

	state_timer += delta
	animation_timer += delta

	match state:
		State.IDLE:
			_process_idle(delta)
		State.WALKING:
			_process_walking(delta)
		State.SITTING:
			_process_sitting(delta)
		State.GROOMING:
			_process_grooming(delta)
		State.SLEEPING:
			_process_sleeping(delta)
		State.STRETCHING:
			_process_stretching(delta)

	# Tail wag animation (always subtle movement)
	if tail and state != State.SLEEPING:
		tail.rotation = sin(animation_timer * 2.0) * 0.15

	# Process meow bubbles (not while sleeping)
	if state != State.SLEEPING:
		_process_meow_bubble(delta)

	if state != State.WALKING:
		stuck_timer = 0.0
		last_position = position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if click is on cat (rough bounds)
				var local_pos = get_local_mouse_position()
				if local_pos.x > -20 and local_pos.x < 25 and local_pos.y > -15 and local_pos.y < 20:
					is_being_dragged = true
					drag_offset = position - get_global_mouse_position()
					# Wake up if sleeping
					if state == State.SLEEPING:
						sleeping_z.visible = false
						for eye in eyes:
							eye.visible = true
					state = State.IDLE
					get_viewport().set_input_as_handled()  # Prevent other nodes from receiving this click
			else:
				if is_being_dragged:
					is_being_dragged = false
					# Sleep if dropped onto the bed, otherwise pick a new action
					if cat_bed_position != Vector2.ZERO and position.distance_to(cat_bed_position) <= 24.0:
						state_timer = 0.0
						pending_sleep = false
						state = State.SLEEPING
						sleeping_z.visible = true
						next_action_time = randf_range(8.0, 20.0)
					else:
						_pick_next_action()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_being_dragged:
		var new_pos = get_global_mouse_position() + drag_offset
		# Clamp to bounds
		new_pos.x = clamp(new_pos.x, bounds_min.x, bounds_max.x)
		new_pos.y = clamp(new_pos.y, bounds_min.y, bounds_max.y)
		position = new_pos
		get_viewport().set_input_as_handled()

func _process_idle(delta: float) -> void:
	if state_timer >= next_action_time:
		_pick_next_action()

func _process_walking(delta: float) -> void:
	# If we're inside an obstacle, nudge out gradually instead of teleporting
	if _is_position_blocked(position):
		var nudge_dir = _find_nudge_direction()
		if nudge_dir != Vector2.ZERO:
			position += nudge_dir * speed * delta * 2.0  # Move out at double speed
			_log_event("STUCK", "Inside obstacle, nudging out")
			return
		else:
			# Can't find a way out - only then teleport as last resort
			_log_event("STUCK", "No nudge direction found, teleporting")
			position = _find_valid_position()
			target_position = _find_valid_position()
			_build_path_to(target_position)
			stuck_timer = 0.0
			last_position = position
			return

	# Follow waypoints if we have them
	if path_waypoints.size() > 0 and current_waypoint_index < path_waypoints.size():
		var current_waypoint = path_waypoints[current_waypoint_index]
		var direction = current_waypoint - position

		# Reached current waypoint?
		if direction.length() < 8:
			current_waypoint_index += 1
			if current_waypoint_index >= path_waypoints.size():
				# Reached final destination
				path_waypoints.clear()
				current_waypoint_index = 0
				if pending_sleep:
					pending_sleep = false
					state = State.SLEEPING
					sleeping_z.visible = true
					next_action_time = randf_range(8.0, 20.0)
				else:
					_pick_next_action()
				return
			return

		# Move toward current waypoint
		var move_dir = direction.normalized()
		var step_size = speed * delta
		var next_pos = position + move_dir * step_size

		# Boundary check
		if _is_out_of_bounds(next_pos):
			_log_event("NAV", "Hit boundary, rebuilding path")
			consecutive_blocks = 0
			target_position = _find_valid_position()
			_build_path_to(target_position)
			return

		# Check if next position is blocked BEFORE moving
		if _is_position_blocked(next_pos):
			consecutive_blocks += 1
			_log_event("NAV", "Path blocked (count: %d)" % consecutive_blocks)

			# Try perpendicular dodge first
			var perp = Vector2(-move_dir.y, move_dir.x)  # Perpendicular direction
			var dodge_pos = position + perp * step_size * 2.0
			if not _is_position_blocked(dodge_pos) and not _is_out_of_bounds(dodge_pos):
				position = dodge_pos
				consecutive_blocks = 0
				return
			# Try other perpendicular
			dodge_pos = position - perp * step_size * 2.0
			if not _is_position_blocked(dodge_pos) and not _is_out_of_bounds(dodge_pos):
				position = dodge_pos
				consecutive_blocks = 0
				return

			# If blocked multiple times, rebuild path
			if consecutive_blocks >= 3:
				_log_event("NAV", "Rebuilding path after %d blocks" % consecutive_blocks)
				consecutive_blocks = 0
				# Skip current waypoint and try to path to next one or final destination
				if current_waypoint_index < path_waypoints.size() - 1:
					current_waypoint_index += 1
					_build_path_to(path_waypoints[path_waypoints.size() - 1])
				else:
					target_position = _find_valid_position()
					_build_path_to(target_position)
			return

		consecutive_blocks = 0
		position = next_pos

		# Stuck detection
		if position.distance_to(last_position) < STUCK_DISTANCE_EPS:
			stuck_timer += delta
			if stuck_timer >= STUCK_TIMEOUT:
				_log_event("STUCK", "No progress for %.1fs, finding new destination" % STUCK_TIMEOUT)
				target_position = _find_valid_position()
				_build_path_to(target_position)
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
		last_position = position

		# Face direction of movement
		if abs(direction.x) > 1:
			_set_facing(direction.x < 0)

		# Subtle bobbing while walking
		if body:
			body.position.y = sin(animation_timer * 12.0) * 1.5
		return

	# No waypoints - we must have reached target or path was empty
	# This handles the fallback case where pathfinding failed
	var direction = target_position - position
	if direction.length() < 5:
		if pending_sleep:
			pending_sleep = false
			state = State.SLEEPING
			sleeping_z.visible = true
			next_action_time = randf_range(8.0, 20.0)
		else:
			_pick_next_action()
		return

	# Direct movement fallback (shouldn't happen often with pathfinding)
	var move_dir = direction.normalized()
	position += move_dir * speed * delta
	last_position = position

	if abs(direction.x) > 1:
		_set_facing(direction.x < 0)

	if body:
		body.position.y = sin(animation_timer * 12.0) * 1.5

func _process_sitting(delta: float) -> void:
	# Cat sits and looks around
	if head:
		head.position.x = -16 + sin(animation_timer * 0.8) * 2

	if state_timer >= next_action_time:
		# Reset head position before transitioning
		if head:
			head.position.x = -18 if is_facing_left else 6
		_pick_next_action()

func _process_grooming(delta: float) -> void:
	# Cat grooms - head moves up and down
	if head:
		head.position.y = -6 + sin(animation_timer * 4.0) * 2
		head.rotation = sin(animation_timer * 3.0) * 0.2

	if state_timer >= next_action_time:
		if head:
			head.rotation = 0
			head.position.y = -6
		_pick_next_action()

func _process_sleeping(delta: float) -> void:
	# Cat sleeps - show Zzz, slow breathing
	if body:
		body.size.y = 12 + sin(animation_timer * 1.5) * 1  # Breathing

	# Zzz floats up
	if sleeping_z:
		sleeping_z.position.y = -20 - (sin(animation_timer * 2.0) + 1) * 3

	# Hide eyes when sleeping
	for eye in eyes:
		eye.visible = false

	if state_timer >= next_action_time:
		# Wake up
		sleeping_z.visible = false
		for eye in eyes:
			eye.visible = true
		_pick_next_action()

func _process_stretching(delta: float) -> void:
	# Cat stretches - body elongates
	var t = state_timer / 2.0  # 2 second stretch

	if body:
		if t < 0.5:
			# Stretch forward
			body.size.x = 24 + t * 20
		else:
			# Return to normal
			body.size.x = 24 + (1.0 - t) * 20

	if state_timer >= 2.0:
		if body:
			body.size.x = 24
		_pick_next_action()

func _pick_next_action() -> void:
	state_timer = 0.0
	consecutive_blocks = 0

	# Weight different actions
	var roll = randf()

	if roll < 0.35:
		# Walk somewhere (avoiding desks)
		state = State.WALKING
		target_position = _find_valid_position()
		_build_path_to(target_position)
		_log_event("NAV", "Walking to (%.0f, %.0f)" % [target_position.x, target_position.y])
		next_action_time = 999  # Walk until destination
	elif roll < 0.50:
		# Sit and look around
		state = State.SITTING
		next_action_time = randf_range(3.0, 8.0)
	elif roll < 0.65:
		# Groom
		state = State.GROOMING
		next_action_time = randf_range(2.0, 5.0)
	elif roll < 0.85:
		# Sleep (walk to nap spot first)
		state = State.WALKING
		nap_spot = _find_valid_nap_spot()
		target_position = nap_spot
		_build_path_to(target_position)
		pending_sleep = true
		_log_event("NAV", "Walking to nap spot (%.0f, %.0f)" % [target_position.x, target_position.y])
		next_action_time = 999
	elif roll < 0.88:
		# Idle (small chance - just stand there)
		state = State.IDLE
		next_action_time = randf_range(1.0, 3.0)
	else:
		# Stretch
		state = State.STRETCHING
		next_action_time = 2.0

func _set_facing(left: bool) -> void:
	if is_facing_left == left:
		return

	is_facing_left = left

	# Flip visuals by moving head and tail (face parts are children of head)
	if left:
		# Facing left: head on left side, tail on right
		if head:
			head.position.x = -18
		if tail:
			tail.position.x = 10
	else:
		# Facing right: head on right side, tail on left
		if head:
			head.position.x = 6
		if tail:
			tail.position.x = -24

func set_bounds(min_pos: Vector2, max_pos: Vector2) -> void:
	bounds_min = min_pos
	bounds_max = max_pos

func set_cat_bed_position(pos: Vector2) -> void:
	cat_bed_position = pos

func set_desk_positions(positions: Array[Vector2]) -> void:
	# Add desk obstacles (keep for backwards compatibility)
	for pos in positions:
		var rect = Rect2(pos - DESK_SIZE / 2, DESK_SIZE)
		obstacle_rects.append(rect)

func add_obstacle(rect: Rect2) -> void:
	obstacle_rects.append(rect)

func clear_obstacles() -> void:
	obstacle_rects.clear()

func set_navigation_grid(grid: NavigationGrid) -> void:
	navigation_grid = grid

func _build_path_to(destination: Vector2) -> void:
	"""Build A* path to destination using navigation grid."""
	path_waypoints.clear()
	current_waypoint_index = 0

	if navigation_grid:
		var path = navigation_grid.find_path(position, destination)
		if path.size() > 0:
			for point in path:
				path_waypoints.append(point)
			return

	# Fallback: direct path if no grid or path failed
	path_waypoints.append(destination)

func _is_position_blocked(pos: Vector2) -> bool:
	var cat_rect = Rect2(pos - CAT_COLLIDER_SIZE / 2, CAT_COLLIDER_SIZE)
	for rect in obstacle_rects:
		if rect.intersects(cat_rect):
			return true
	return false

func _find_nudge_direction() -> Vector2:
	"""Find the best direction to nudge the cat out of an obstacle."""
	# Try 8 directions and find the one that leads to unblocked space fastest
	var directions = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized(),
	]

	var best_dir = Vector2.ZERO
	var best_dist = INF

	for dir in directions:
		# Check how far we need to go in this direction to be clear
		for dist in [10, 20, 30, 40, 50]:
			var test_pos = position + dir * dist
			if not _is_position_blocked(test_pos) and not _is_out_of_bounds(test_pos):
				if dist < best_dist:
					best_dist = dist
					best_dir = dir
				break

	return best_dir

func _is_out_of_bounds(pos: Vector2) -> bool:
	return pos.x < bounds_min.x + CAT_WALL_MARGIN or pos.x > bounds_max.x - CAT_WALL_MARGIN or pos.y < bounds_min.y + CAT_WALL_MARGIN or pos.y > bounds_max.y - CAT_WALL_MARGIN

func _find_valid_position() -> Vector2:
	# Try to find a position with clearance around it (not just barely valid)
	var clearance = 30.0  # Prefer positions with this much clearance

	# First pass: try to find position with good clearance
	for _i in range(20):
		var test_pos = Vector2(
			randf_range(bounds_min.x + CAT_WALL_MARGIN, bounds_max.x - CAT_WALL_MARGIN),
			randf_range(bounds_min.y + CAT_WALL_MARGIN, bounds_max.y - CAT_WALL_MARGIN)
		)
		if _has_clearance(test_pos, clearance):
			return test_pos

	# Second pass: accept any valid position
	for _i in range(20):
		var test_pos = Vector2(
			randf_range(bounds_min.x + CAT_WALL_MARGIN, bounds_max.x - CAT_WALL_MARGIN),
			randf_range(bounds_min.y + CAT_WALL_MARGIN, bounds_max.y - CAT_WALL_MARGIN)
		)
		if not _is_position_blocked(test_pos) and not _is_out_of_bounds(test_pos):
			return test_pos

	# Fallback: return position in a known safe corridor (left side of room)
	_log_event("NAV", "Using fallback corridor position")
	return Vector2(randf_range(100, 180), randf_range(bounds_min.y + CAT_WALL_MARGIN, bounds_max.y - CAT_WALL_MARGIN))

func _has_clearance(pos: Vector2, clearance: float) -> bool:
	# Check if position has clearance in all directions
	if _is_position_blocked(pos) or _is_out_of_bounds(pos):
		return false

	# Check cardinal directions
	var offsets = [
		Vector2(clearance, 0), Vector2(-clearance, 0),
		Vector2(0, clearance), Vector2(0, -clearance),
		Vector2(clearance * 0.7, clearance * 0.7),  # Diagonals
		Vector2(-clearance * 0.7, clearance * 0.7),
		Vector2(clearance * 0.7, -clearance * 0.7),
		Vector2(-clearance * 0.7, -clearance * 0.7),
	]

	for offset in offsets:
		if _is_position_blocked(pos + offset) or _is_out_of_bounds(pos + offset):
			return false

	return true

func _log_event(category: String, message: String) -> void:
	var script = load("res://scripts/DebugEventLog.gd")
	if script and script.has_meta("instance"):
		var inst = script.get_meta("instance")
		if inst and inst.has_method("add_event"):
			inst.add_event(category, message, "cat")

func _find_valid_nap_spot() -> Vector2:
	if cat_bed_position != Vector2.ZERO:
		var center = cat_bed_position
		# Try center first if it has clearance
		if _has_clearance(center, 15.0):
			return center
		# Try nearby positions
		for _i in range(20):
			var test_pos = center + Vector2(randf_range(-12, 12), randf_range(-8, 8))
			if not _is_position_blocked(test_pos) and not _is_out_of_bounds(test_pos):
				return test_pos
		if not _is_position_blocked(center) and not _is_out_of_bounds(center):
			return center

	# Fallback: find a cozy corner
	var center = Vector2(bounds_min.x + 90, bounds_max.y - 70)
	for _i in range(20):
		var test_pos = center + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		if _has_clearance(test_pos, 20.0):
			return test_pos

	# Last resort
	return _find_valid_position()

# =============================================================================
# MEOW SPEECH BUBBLES
# =============================================================================

var _meow_check_timer: float = 0.0  # Separate timer for meow checks

func _process_meow_bubble(delta: float) -> void:
	# Update meow bubble fade
	if meow_bubble and meow_timer > 0:
		meow_timer -= delta
		if meow_timer < 0.4:
			meow_bubble.modulate.a = meow_timer / 0.4
		if meow_timer <= 0:
			meow_bubble.queue_free()
			meow_bubble = null

	# Cooldown between meows
	if meow_cooldown > 0:
		meow_cooldown -= delta
		return

	# Check for spontaneous meow at fixed intervals
	_meow_check_timer += delta
	if _meow_check_timer >= MEOW_CHECK_INTERVAL:
		_meow_check_timer = 0.0
		if randf() < MEOW_CHANCE and meow_bubble == null:
			_show_meow()
			meow_cooldown = MEOW_COOLDOWN

func _show_meow() -> void:
	if meow_bubble:
		meow_bubble.queue_free()

	# Play meow sound
	if audio_manager:
		audio_manager.play_meow()

	var phrase = MEOW_PHRASES[randi() % MEOW_PHRASES.size()]

	meow_bubble = Node2D.new()
	meow_bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	add_child(meow_bubble)

	# Tiny speech bubble
	var bubble_bg = ColorRect.new()
	var text_width = phrase.length() * 6 + 10
	bubble_bg.size = Vector2(max(text_width, 35), 16)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -28)
	bubble_bg.color = OfficePalette.SPEECH_BUBBLE
	meow_bubble.add_child(bubble_bg)

	# Border
	var border = ColorRect.new()
	border.size = bubble_bg.size + Vector2(2, 2)
	border.position = bubble_bg.position - Vector2(1, 1)
	border.color = OfficePalette.SPEECH_BUBBLE_BORDER
	border.z_index = -1
	meow_bubble.add_child(border)

	# Tiny pointer
	var pointer = ColorRect.new()
	pointer.size = Vector2(5, 5)
	pointer.position = Vector2(-2.5, -13)
	pointer.color = OfficePalette.SPEECH_BUBBLE
	meow_bubble.add_child(pointer)

	# Text
	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(5, 1)
	text_label.add_theme_font_size_override("font_size", 9)
	text_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	meow_bubble.add_child(text_label)

	meow_timer = 2.0  # Show for 2 seconds
