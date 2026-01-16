extends Node2D
class_name OfficeCat

enum State { IDLE, WALKING, SITTING, GROOMING, SLEEPING, STRETCHING }

var state: State = State.IDLE
var target_position: Vector2
var speed: float = 40.0  # Cats are slower/lazier than workers

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
var cat_color: Color = Color(0.6, 0.4, 0.25)  # Orange tabby by default
var is_facing_left: bool = true  # Starts facing left (head on left side)

# Boundaries for wandering
var bounds_min: Vector2 = Vector2(30, 100)
var bounds_max: Vector2 = Vector2(780, 620)

# Desk obstacles (rectangles to avoid)
var desk_rects: Array[Rect2] = []
const DESK_SIZE: Vector2 = Vector2(100, 80)  # Desk footprint including work area

# Dragging
var is_being_dragged: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_randomize_appearance()
	_create_visuals()
	position = Vector2(randf_range(bounds_min.x, bounds_max.x), randf_range(bounds_min.y, bounds_max.y))
	next_action_time = randf_range(2.0, 5.0)

func _randomize_appearance() -> void:
	# Random cat colors
	var colors = [
		Color(0.65, 0.45, 0.25),  # Orange tabby
		Color(0.25, 0.25, 0.28),  # Black
		Color(0.9, 0.88, 0.82),   # White
		Color(0.55, 0.55, 0.52),  # Gray
		Color(0.4, 0.32, 0.25),   # Brown tabby
		Color(0.8, 0.6, 0.35),    # Cream
	]
	cat_color = colors[randi() % colors.size()]

func _create_visuals() -> void:
	# Shadow under cat
	var shadow = ColorRect.new()
	shadow.size = Vector2(24, 8)
	shadow.position = Vector2(-12, 10)
	shadow.color = Color(0.0, 0.0, 0.0, 0.15)
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
	inner_left.color = Color(0.9, 0.7, 0.7)
	head.add_child(inner_left)

	var inner_right = ColorRect.new()
	inner_right.size = Vector2(2, 3)
	inner_right.position = Vector2(9, -4)
	inner_right.color = Color(0.9, 0.7, 0.7)
	head.add_child(inner_right)

	# Eyes (children of head)
	var eye_left = ColorRect.new()
	eye_left.size = Vector2(3, 3)
	eye_left.position = Vector2(2, 3)  # Relative to head
	eye_left.color = Color(0.3, 0.5, 0.3)  # Green eyes
	head.add_child(eye_left)
	eyes.append(eye_left)

	var eye_right = ColorRect.new()
	eye_right.size = Vector2(3, 3)
	eye_right.position = Vector2(7, 3)  # Relative to head
	eye_right.color = Color(0.3, 0.5, 0.3)
	head.add_child(eye_right)
	eyes.append(eye_right)

	# Nose (child of head)
	var nose = ColorRect.new()
	nose.size = Vector2(2, 2)
	nose.position = Vector2(5, 6)  # Relative to head
	nose.color = Color(0.9, 0.7, 0.7)
	head.add_child(nose)

	# Sleeping Zzz (hidden by default)
	sleeping_z = Label.new()
	sleeping_z.text = "z z z"
	sleeping_z.position = Vector2(-5, -20)
	sleeping_z.add_theme_font_size_override("font_size", 10)
	sleeping_z.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.8))
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
			else:
				if is_being_dragged:
					is_being_dragged = false
					# Pick new random action after being moved
					_pick_next_action()

	elif event is InputEventMouseMotion and is_being_dragged:
		var new_pos = get_global_mouse_position() + drag_offset
		# Clamp to bounds
		new_pos.x = clamp(new_pos.x, bounds_min.x, bounds_max.x)
		new_pos.y = clamp(new_pos.y, bounds_min.y, bounds_max.y)
		position = new_pos

func _process_idle(delta: float) -> void:
	if state_timer >= next_action_time:
		_pick_next_action()

func _process_walking(delta: float) -> void:
	var direction = target_position - position
	if direction.length() < 5:
		position = target_position
		_pick_next_action()
		return

	# Calculate next position
	var move_dir = direction.normalized()
	var next_pos = position + move_dir * speed * delta

	# Check if next position is blocked by a desk
	if _is_position_blocked(next_pos):
		# Steer around: try perpendicular directions
		var perp1 = Vector2(-move_dir.y, move_dir.x)  # Perpendicular
		var perp2 = Vector2(move_dir.y, -move_dir.x)  # Other perpendicular

		var alt_pos1 = position + perp1 * speed * delta
		var alt_pos2 = position + perp2 * speed * delta

		if not _is_position_blocked(alt_pos1):
			next_pos = alt_pos1
		elif not _is_position_blocked(alt_pos2):
			next_pos = alt_pos2
		else:
			# Stuck - pick new destination
			target_position = _find_valid_position()
			return

	position = next_pos

	# Face direction of movement (left if moving left, right if moving right)
	if abs(direction.x) > 1:  # Only change facing if significant horizontal movement
		_set_facing(direction.x < 0)

	# Subtle bobbing while walking
	if body:
		body.position.y = sin(animation_timer * 12.0) * 1.5

func _process_sitting(delta: float) -> void:
	# Cat sits and looks around
	if head:
		head.position.x = -16 + sin(animation_timer * 0.8) * 2

	if state_timer >= next_action_time:
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

	# Weight different actions
	var roll = randf()

	if roll < 0.35:
		# Walk somewhere (avoiding desks)
		state = State.WALKING
		target_position = _find_valid_position()
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
		# Sleep
		state = State.SLEEPING
		sleeping_z.visible = true
		next_action_time = randf_range(8.0, 20.0)  # Cats sleep a lot
	else:
		# Stretch
		state = State.STRETCHING
		next_action_time = 2.0
	# Idle (small chance)
	if roll >= 0.85 and roll < 0.88:
		state = State.IDLE
		next_action_time = randf_range(1.0, 3.0)

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

func set_desk_positions(positions: Array) -> void:
	desk_rects.clear()
	for pos in positions:
		# Create a rect centered on desk position, covering desk + work area in front
		var rect = Rect2(pos - DESK_SIZE / 2, DESK_SIZE)
		desk_rects.append(rect)

func _is_position_blocked(pos: Vector2) -> bool:
	for rect in desk_rects:
		if rect.has_point(pos):
			return true
	return false

func _find_valid_position() -> Vector2:
	# Try to find a position not inside a desk
	for _i in range(20):  # Max attempts
		var test_pos = Vector2(
			randf_range(bounds_min.x, bounds_max.x),
			randf_range(bounds_min.y, bounds_max.y)
		)
		if not _is_position_blocked(test_pos):
			return test_pos
	# Fallback: return position in a known safe corridor
	return Vector2(randf_range(100, 180), randf_range(bounds_min.y, bounds_max.y))

# =============================================================================
# MEOW SPEECH BUBBLES
# =============================================================================

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

	# Check for spontaneous meow
	animation_timer += delta  # Reuse animation_timer for meow checks
	if int(animation_timer) % int(MEOW_CHECK_INTERVAL) == 0 and int(animation_timer) > 0:
		if randf() < MEOW_CHANCE and meow_bubble == null:
			_show_meow()
			meow_cooldown = MEOW_COOLDOWN

func _show_meow() -> void:
	if meow_bubble:
		meow_bubble.queue_free()

	var phrase = MEOW_PHRASES[randi() % MEOW_PHRASES.size()]

	meow_bubble = Node2D.new()
	meow_bubble.z_index = 100
	add_child(meow_bubble)

	# Tiny speech bubble
	var bubble_bg = ColorRect.new()
	var text_width = phrase.length() * 6 + 10
	bubble_bg.size = Vector2(max(text_width, 35), 16)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -28)
	bubble_bg.color = Color(1.0, 0.98, 0.92, 0.95)  # Warm cream
	meow_bubble.add_child(bubble_bg)

	# Border
	var border = ColorRect.new()
	border.size = bubble_bg.size + Vector2(2, 2)
	border.position = bubble_bg.position - Vector2(1, 1)
	border.color = Color(0.5, 0.45, 0.35)
	border.z_index = -1
	meow_bubble.add_child(border)

	# Tiny pointer
	var pointer = ColorRect.new()
	pointer.size = Vector2(5, 5)
	pointer.position = Vector2(-2.5, -13)
	pointer.color = Color(1.0, 0.98, 0.92, 0.95)
	meow_bubble.add_child(pointer)

	# Text
	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(5, 1)
	text_label.add_theme_font_size_override("font_size", 9)
	text_label.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25))
	meow_bubble.add_child(text_label)

	meow_timer = 2.0  # Show for 2 seconds
