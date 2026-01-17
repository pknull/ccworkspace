extends Node2D
class_name Agent

signal work_completed(agent: Agent)

enum State { SPAWNING, WALKING_TO_DESK, WORKING, DELIVERING, SOCIALIZING, LEAVING, COMPLETING, IDLE, MEETING }

# Shirt/tie colors by agent type (more muted, office-appropriate)
const AGENT_COLORS = {
	"orchestrator": Color(0.85, 0.75, 0.55),  # Tan/khaki - session orchestrator
	"main": Color(0.85, 0.75, 0.55),          # Tan/khaki (legacy)
	"Explore": Color(0.45, 0.55, 0.70),       # Dusty blue - researcher
	"Coder": Color(0.50, 0.60, 0.50),         # Sage green - developer
	"full-stack-developer": Color(0.50, 0.60, 0.50),
	"debugger": Color(0.70, 0.45, 0.45),      # Dusty red - bug hunter
	"refactoring-specialist": Color(0.60, 0.50, 0.65),  # Muted purple
	"test-automator": Color(0.70, 0.65, 0.45),  # Mustard - QA
	"research-assistant": Color(0.50, 0.65, 0.65),  # Teal
	"Plan": Color(0.70, 0.55, 0.45),          # Terracotta - planner
	"code-reviewer": Color(0.55, 0.50, 0.60), # Mauve - reviewer
	"default": Color(0.55, 0.55, 0.55)        # Gray
}

const AGENT_LABELS = {
	"orchestrator": "Orchestrator",
	"main": "Claude",  # legacy
	"Explore": "Explorer",
	"Coder": "Coder",
	"full-stack-developer": "Developer",
	"debugger": "Debugger",
	"refactoring-specialist": "Architect",
	"test-automator": "QA",
	"research-assistant": "Researcher",
	"Plan": "Planner",
	"code-reviewer": "Reviewer",
	"default": "Worker"
}

const TOOL_ICONS = {
	"Bash": "[>_]",
	"Read": "[R]",
	"Edit": "[E]",
	"Write": "[W]",
	"Glob": "[*]",
	"Grep": "[?]",
	"WebFetch": "[W]",
	"WebSearch": "[S]",
	"Task": "[T]",
	"NotebookEdit": "[N]"
}

const TOOL_COLORS = {
	"Bash": Color(0.2, 0.8, 0.2),
	"Read": Color(0.4, 0.6, 1.0),
	"Edit": Color(1.0, 0.8, 0.2),
	"Write": Color(1.0, 0.6, 0.2),
	"Glob": Color(0.8, 0.4, 1.0),
	"Grep": Color(0.8, 0.4, 1.0),
	"WebFetch": Color(0.2, 0.8, 0.8),
	"WebSearch": Color(0.2, 0.8, 0.8),
	"Task": Color(0.9, 0.5, 0.2),
	"NotebookEdit": Color(1.0, 0.6, 0.2)
}

@export var agent_type: String = "default"
@export var description: String = ""

var agent_id: String = ""
var parent_id: String = ""
var session_id: String = ""
var state: State = State.SPAWNING
var target_position: Vector2
var assigned_desk: Node2D = null
var shredder_position: Vector2 = Vector2(1200, 520)  # Center of shredder
var inbox_position: Vector2 = Vector2(1200, 580)  # Default delivery position (in front)
var water_cooler_position: Vector2 = Vector2(50, 200)
var plant_position: Vector2 = Vector2(50, 400)
var filing_cabinet_position: Vector2 = Vector2(50, 550)
var door_position: Vector2 = Vector2(640, 620)
var aisle_y: float = 460  # Y coordinate of horizontal aisle

# Floor bounds (agents can only walk here)
const FLOOR_MIN_X: float = 10.0
const FLOOR_MAX_X: float = 1270.0
const FLOOR_MIN_Y: float = 85.0   # Below back wall seam
const FLOOR_MAX_Y: float = 625.0  # Above bottom wall seam

# Obstacles to avoid (set by OfficeManager)
var obstacles: Array[Rect2] = []
var work_timer: float = 0.0
var socialize_timer: float = 0.0

# Meeting overflow state
var is_in_meeting: bool = false
var meeting_spot: Vector2 = Vector2.ZERO

# Pathfinding
var path_waypoints: Array[Vector2] = []
var current_waypoint_index: int = 0
var navigation_grid: NavigationGrid = null  # Set by OfficeManager for grid-based pathfinding
var spawn_timer: float = 0.0
var is_waiting_for_completion: bool = true
var pending_completion: bool = false
var min_work_time: float = 3.0  # Minimum seconds to show working at desk
var work_elapsed: float = 0.0

# Document being carried
var document: ColorRect = null

# Visual nodes
var body: ColorRect
var shirt: ColorRect
var tie: ColorRect
var head: ColorRect
var hair: ColorRect
var status_label: Label
var type_label: Label
var tool_label: Label
var tool_bg: ColorRect

# Hover tooltip
var tooltip_panel: ColorRect
var tooltip_label: Label
var is_hovered: bool = false

# Tool display
var current_tool: String = ""
var tool_display_timer: float = 0.0

var _visuals_created: bool = false
var is_female: bool = false
var hair_color: Color = Color(0.35, 0.25, 0.20)  # Default brown

# Personal items this worker brings to their desk
var personal_item_types: Array[String] = []  # Which items this worker has

# Click reactions
var reaction_phrases: Array[String] = []  # This worker's personality phrases
var reaction_bubble: Node2D = null
var reaction_timer: float = 0.0

# Spontaneous voice bubbles
var spontaneous_bubble_timer: float = 0.0
var spontaneous_cooldown: float = 0.0
const SPONTANEOUS_CHECK_INTERVAL: float = 12.0  # Check every 12 seconds (was 25)
const SPONTANEOUS_CHANCE: float = 0.25  # 25% chance when checked (was 15%)
const SPONTANEOUS_COOLDOWN: float = 30.0  # Minimum 30s between spontaneous bubbles (was 45)
var office_manager: Node = null  # Set by OfficeManager for global coordination

# Idle fidget animations
var fidget_timer: float = 0.0
var next_fidget_time: float = 0.0
var current_fidget: String = ""
var fidget_progress: float = 0.0
var base_head_y: float = -35
var base_body_y: float = -15

func _init() -> void:
	_create_visuals()
	_visuals_created = true

func _ready() -> void:
	if not _visuals_created:
		_create_visuals()
		_visuals_created = true
	_update_appearance()
	_generate_reaction_phrases()
	if description and status_label:
		set_description(description)
	spawn_timer = 0.5
	# Initialize fidget timing
	next_fidget_time = randf_range(3.0, 8.0)  # First fidget after 3-8 seconds of work

func _create_visuals() -> void:
	# Randomly determine gender and appearance
	is_female = randf() < 0.5

	# Random hair color
	var hair_colors = [
		Color(0.35, 0.25, 0.20),  # Brown
		Color(0.15, 0.12, 0.10),  # Black
		Color(0.55, 0.35, 0.20),  # Auburn
		Color(0.75, 0.60, 0.35),  # Blonde
		Color(0.45, 0.30, 0.25),  # Dark brown
		Color(0.30, 0.20, 0.18),  # Very dark
	]
	hair_color = hair_colors[randi() % hair_colors.size()]

	# Random skin tone
	var skin_tones = [
		Color(0.87, 0.75, 0.65),  # Light
		Color(0.78, 0.62, 0.50),  # Medium
		Color(0.65, 0.50, 0.40),  # Tan
		Color(0.50, 0.38, 0.30),  # Dark
		Color(0.92, 0.82, 0.72),  # Very light
	]
	var skin_color = skin_tones[randi() % skin_tones.size()]

	if is_female:
		_create_female_visuals(skin_color)
	else:
		_create_male_visuals(skin_color)

	# Eyes are now added as children of head in _create_male/female_visuals

	# Type label (hidden - clutters the view)
	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.position = Vector2(-40, -55)
	type_label.size = Vector2(80, 16)
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	type_label.visible = false  # Hidden
	add_child(type_label)

	# Status label background (hidden - only shown on hover via tooltip)
	var status_bg = ColorRect.new()
	status_bg.name = "StatusBg"
	status_bg.size = Vector2(120, 16)
	status_bg.position = Vector2(-60, -72)
	status_bg.color = Color(0.2, 0.2, 0.22, 0.9)
	status_bg.visible = false  # Hidden by default
	add_child(status_bg)

	# Status label (hidden - status shown in hover tooltip)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(-60, -73)
	status_label.size = Vector2(120, 16)
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	status_label.visible = false  # Hidden by default
	add_child(status_label)

	# Tool indicator
	tool_bg = ColorRect.new()
	tool_bg.size = Vector2(32, 20)
	tool_bg.position = Vector2(18, -30)
	tool_bg.color = Color(0.15, 0.15, 0.18, 0.9)
	tool_bg.visible = false
	add_child(tool_bg)

	tool_label = Label.new()
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tool_label.position = Vector2(18, -30)
	tool_label.size = Vector2(32, 20)
	tool_label.add_theme_font_size_override("font_size", 12)
	tool_label.visible = false
	add_child(tool_label)

	# Hover tooltip (hidden by default)
	_create_tooltip()

func _create_male_visuals(skin_color: Color) -> void:
	# Shadow under agent (ellipse approximation with rounded rect look)
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = Color(0.0, 0.0, 0.0, 0.2)
	shadow.z_index = -1
	add_child(shadow)

	# Legs (dark trousers)
	var left_leg = ColorRect.new()
	left_leg.size = Vector2(10, 18)
	left_leg.position = Vector2(-12, 15)
	left_leg.color = Color(0.25, 0.25, 0.28)
	add_child(left_leg)

	var right_leg = ColorRect.new()
	right_leg.size = Vector2(10, 18)
	right_leg.position = Vector2(2, 15)
	right_leg.color = Color(0.25, 0.25, 0.28)
	add_child(right_leg)

	# Body/torso (white shirt)
	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = Color(0.95, 0.95, 0.93)  # Off-white shirt
	body.z_index = 0
	add_child(body)

	# Shirt collar points
	var collar_left = ColorRect.new()
	collar_left.size = Vector2(8, 6)
	collar_left.position = Vector2(-11, -15)
	collar_left.color = Color(0.95, 0.95, 0.93)
	collar_left.z_index = 0
	add_child(collar_left)

	var collar_right = ColorRect.new()
	collar_right.size = Vector2(8, 6)
	collar_right.position = Vector2(3, -15)
	collar_right.color = Color(0.95, 0.95, 0.93)
	collar_right.z_index = 0
	add_child(collar_right)

	# Tie (colored by agent type)
	tie = ColorRect.new()
	tie.size = Vector2(6, 22)
	tie.position = Vector2(-3, -12)
	tie.z_index = 1
	add_child(tie)

	# Tie knot
	var tie_knot = ColorRect.new()
	tie_knot.name = "TieKnot"
	tie_knot.size = Vector2(8, 5)
	tie_knot.position = Vector2(-4, -15)
	tie_knot.z_index = 1
	add_child(tie_knot)

	# Head (container for face parts)
	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = skin_color
	head.z_index = 2
	add_child(head)

	# Hair (short male style) - child of head
	hair = ColorRect.new()
	hair.size = Vector2(20, 8)
	hair.position = Vector2(-1, -5)  # Relative to head
	hair.color = hair_color
	head.add_child(hair)

	# Eyes - children of head
	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(3, 5)  # Relative to head
	left_eye.color = Color(0.2, 0.2, 0.2)
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)  # Relative to head
	right_eye.color = Color(0.2, 0.2, 0.2)
	head.add_child(right_eye)

func _create_female_visuals(skin_color: Color) -> void:
	# Shadow under agent
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = Color(0.0, 0.0, 0.0, 0.2)
	shadow.z_index = -1
	add_child(shadow)

	# Legs (skirt or trousers - random)
	var wears_skirt = randf() < 0.6

	if wears_skirt:
		# Skirt
		var skirt = ColorRect.new()
		skirt.size = Vector2(28, 14)
		skirt.position = Vector2(-14, 10)
		skirt.color = Color(0.25, 0.25, 0.35)  # Dark skirt
		add_child(skirt)

		# Legs below skirt
		var left_leg = ColorRect.new()
		left_leg.size = Vector2(8, 10)
		left_leg.position = Vector2(-10, 22)
		left_leg.color = skin_color.darkened(0.1)  # Stockings
		add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(8, 10)
		right_leg.position = Vector2(2, 22)
		right_leg.color = skin_color.darkened(0.1)
		add_child(right_leg)
	else:
		# Trousers
		var left_leg = ColorRect.new()
		left_leg.size = Vector2(10, 18)
		left_leg.position = Vector2(-12, 15)
		left_leg.color = Color(0.25, 0.25, 0.35)
		add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(10, 18)
		right_leg.position = Vector2(2, 15)
		right_leg.color = Color(0.25, 0.25, 0.35)
		add_child(right_leg)

	# Body/torso (blouse - can be white or colored)
	var blouse_colors = [
		Color(0.95, 0.95, 0.93),  # White
		Color(0.85, 0.75, 0.80),  # Light pink
		Color(0.75, 0.85, 0.90),  # Light blue
		Color(0.90, 0.88, 0.80),  # Cream
	]
	var blouse_color = blouse_colors[randi() % blouse_colors.size()]

	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = blouse_color
	body.z_index = 0
	add_child(body)

	# Collar (rounded for blouse)
	var collar = ColorRect.new()
	collar.size = Vector2(18, 6)
	collar.position = Vector2(-9, -17)
	collar.color = blouse_color
	collar.z_index = 0
	add_child(collar)

	# Female agents don't have a visible tie/necklace - it translated poorly visually
	# The agent type is still shown via the label above their head
	tie = null

	# Head (container for face parts)
	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = skin_color
	head.z_index = 2
	add_child(head)

	# Eyes - children of head
	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(3, 5)  # Relative to head
	left_eye.color = Color(0.2, 0.2, 0.2)
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)  # Relative to head
	right_eye.color = Color(0.2, 0.2, 0.2)
	head.add_child(right_eye)

	# Hair (longer female style) - children of head
	var hair_style = randi() % 3

	if hair_style == 0:
		# Long hair with side parts
		hair = ColorRect.new()
		hair.size = Vector2(24, 12)
		hair.position = Vector2(-3, -7)  # Relative to head
		hair.color = hair_color
		head.add_child(hair)

		# Hair sides
		var hair_left = ColorRect.new()
		hair_left.size = Vector2(6, 18)
		hair_left.position = Vector2(-5, -1)  # Relative to head
		hair_left.color = hair_color
		head.add_child(hair_left)

		var hair_right = ColorRect.new()
		hair_right.size = Vector2(6, 18)
		hair_right.position = Vector2(17, -1)  # Relative to head
		hair_right.color = hair_color
		head.add_child(hair_right)
	elif hair_style == 1:
		# Bob cut
		hair = ColorRect.new()
		hair.size = Vector2(26, 14)
		hair.position = Vector2(-4, -9)  # Relative to head
		hair.color = hair_color
		head.add_child(hair)

		var hair_sides = ColorRect.new()
		hair_sides.size = Vector2(28, 8)
		hair_sides.position = Vector2(-5, 1)  # Relative to head
		hair_sides.color = hair_color
		head.add_child(hair_sides)
	else:
		# Ponytail/updo
		hair = ColorRect.new()
		hair.size = Vector2(22, 10)
		hair.position = Vector2(-2, -8)  # Relative to head
		hair.color = hair_color
		head.add_child(hair)

		# Bun/ponytail
		var bun = ColorRect.new()
		bun.size = Vector2(10, 10)
		bun.position = Vector2(4, -15)  # Relative to head
		bun.color = hair_color
		head.add_child(bun)

func _create_tooltip() -> void:
	tooltip_panel = ColorRect.new()
	tooltip_panel.size = Vector2(200, 72)  # Compact size
	tooltip_panel.position = Vector2(30, -50)
	tooltip_panel.color = Color(0.95, 0.93, 0.85, 0.98)  # Cream paper
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100  # Always on top
	add_child(tooltip_panel)

	# Tooltip border
	var border = ColorRect.new()
	border.size = Vector2(200, 72)
	border.position = Vector2(0, 0)
	border.color = Color(0.6, 0.55, 0.45)
	tooltip_panel.add_child(border)

	var inner = ColorRect.new()
	inner.size = Vector2(196, 68)
	inner.position = Vector2(2, 2)
	inner.color = Color(0.95, 0.93, 0.85)
	tooltip_panel.add_child(inner)

	# Tooltip header
	var header = Label.new()
	header.name = "Header"
	header.position = Vector2(6, 4)
	header.size = Vector2(188, 16)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	tooltip_panel.add_child(header)

	# Divider line
	var divider = ColorRect.new()
	divider.size = Vector2(188, 1)
	divider.position = Vector2(6, 20)
	divider.color = Color(0.7, 0.65, 0.55)
	tooltip_panel.add_child(divider)

	# Tooltip content
	tooltip_label = Label.new()
	tooltip_label.position = Vector2(6, 23)
	tooltip_label.size = Vector2(188, 45)
	tooltip_label.add_theme_font_size_override("font_size", 9)
	tooltip_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_panel.add_child(tooltip_label)

func _update_appearance() -> void:
	var color = AGENT_COLORS.get(agent_type, AGENT_COLORS["default"])
	if tie:
		tie.color = color
	var tie_knot_node = get_node_or_null("TieKnot")
	if tie_knot_node:
		tie_knot_node.color = color.darkened(0.1)
	type_label.text = AGENT_LABELS.get(agent_type, AGENT_LABELS["default"])

func _process(delta: float) -> void:
	# Update z_index based on Y position - agents lower on screen render in front
	z_index = int(position.y)

	_check_mouse_hover()
	_update_reaction_timer(delta)

	match state:
		State.SPAWNING:
			_process_spawning(delta)
		State.WALKING_TO_DESK:
			_process_walking_path(delta)
		State.WORKING:
			_process_working(delta)
		State.DELIVERING:
			_process_walking_path(delta)
		State.SOCIALIZING:
			_process_socializing(delta)
		State.LEAVING:
			_process_walking_path(delta)
		State.COMPLETING:
			_process_completing(delta)
		State.IDLE:
			# Idle agents can still walk to a destination (e.g., water cooler)
			if not path_waypoints.is_empty():
				_process_walking_path(delta)
		State.MEETING:
			_process_meeting(delta)

func _check_mouse_hover() -> void:
	var mouse_pos = get_local_mouse_position()
	# Check if mouse is within agent bounds (roughly -15 to 15 x, -45 to 30 y)
	var in_bounds = mouse_pos.x > -20 and mouse_pos.x < 20 and mouse_pos.y > -50 and mouse_pos.y < 35

	if in_bounds and not is_hovered:
		is_hovered = true
		_show_tooltip()
	elif not in_bounds and is_hovered:
		is_hovered = false
		_hide_tooltip()

func _show_tooltip() -> void:
	if tooltip_panel:
		var header = tooltip_panel.get_node_or_null("Header")
		if header:
			header.text = AGENT_LABELS.get(agent_type, "Worker") + " (" + agent_id.substr(0, 8) + ")"
		if tooltip_label:
			var state_text = ""
			match state:
				State.SPAWNING: state_text = "Entering..."
				State.WALKING_TO_DESK: state_text = "Walking to desk"
				State.WORKING: state_text = "Working"
				State.DELIVERING: state_text = "Delivering work"
				State.SOCIALIZING: state_text = "Chatting"
				State.LEAVING: state_text = "Leaving"
				State.COMPLETING: state_text = "Done!"
				State.IDLE: state_text = "Idle"
				State.MEETING: state_text = "In meeting"

			# Build tooltip content - compact single-line spacing
			var lines: Array[String] = []

			# Task description (truncate if too long)
			if description:
				var desc = description
				if desc.length() > 60:
					desc = desc.substr(0, 57) + "..."
				lines.append(desc)
			else:
				lines.append("(no task)")

			# Current tool (if working and using a tool)
			if state == State.WORKING and current_tool:
				lines.append("Using: " + current_tool)

			# Status with optional work time
			var status_line = "Status: " + state_text
			if state == State.WORKING and work_elapsed > 0:
				status_line += " (%.0fs)" % work_elapsed
			lines.append(status_line)

			tooltip_label.text = "\n".join(lines)
		tooltip_panel.visible = true

func _hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _process_spawning(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = 1.0 - (spawn_timer / 0.5)
	if spawn_timer <= 0:
		modulate.a = 1.0
		if assigned_desk:
			start_walking_to_desk()
			if pending_completion and status_label:
				status_label.text = "Finishing up..."
		else:
			state = State.IDLE

func _process_walking_path(delta: float) -> void:
	if path_waypoints.is_empty():
		return

	var target = path_waypoints[current_waypoint_index]
	var direction = target - position

	if direction.length() < 5:
		position = target
		current_waypoint_index += 1

		if current_waypoint_index >= path_waypoints.size():
			# Reached final destination
			_on_path_complete()
		return

	var new_pos = position + direction.normalized() * OfficeConstants.AGENT_WALK_SPEED * delta

	# Clamp to floor bounds
	new_pos.x = clamp(new_pos.x, FLOOR_MIN_X, FLOOR_MAX_X)
	new_pos.y = clamp(new_pos.y, FLOOR_MIN_Y, FLOOR_MAX_Y)

	# Only check obstacle collisions if not using grid navigation
	# (grid-based A* already handles obstacle avoidance)
	if not navigation_grid:
		var agent_rect = Rect2(new_pos.x - 10, new_pos.y - 5, 20, 30)
		for obstacle in obstacles:
			if agent_rect.intersects(obstacle):
				# Try to go around the obstacle
				var obstacle_center = obstacle.get_center()
				if position.x < obstacle_center.x:
					new_pos.x = obstacle.position.x - 15
				else:
					new_pos.x = obstacle.position.x + obstacle.size.x + 15
				new_pos.x = clamp(new_pos.x, FLOOR_MIN_X, FLOOR_MAX_X)
				break

	position = new_pos

func set_obstacles(obs: Array[Rect2]) -> void:
	obstacles = obs

func _on_path_complete() -> void:
	path_waypoints.clear()
	current_waypoint_index = 0

	match state:
		State.WALKING_TO_DESK:
			# Arrived at desk, start working
			work_elapsed = 0.0
			state = State.WORKING
			# Turn on monitor now that agent has arrived
			if assigned_desk and assigned_desk.has_method("set_monitor_active"):
				assigned_desk.set_monitor_active(true)
			# Place personal items on desk
			_place_personal_items_on_desk()
			print("[Agent %s] Reached desk, starting work (pending_completion=%s)" % [agent_id, pending_completion])
			if status_label:
				status_label.text = "Working..."
		State.DELIVERING:
			# Arrived at shredder, deliver document
			print("[Agent %s] Reached shredder at %s, delivering document" % [agent_id, position])
			_deliver_document()
			# Pick next action: socialize somewhere or leave
			_pick_post_work_action()
		State.LEAVING:
			# Arrived at door, complete and fade out
			state = State.COMPLETING
			spawn_timer = 0.5
			if status_label:
				status_label.text = "Goodbye!"

func _pick_post_work_action() -> void:
	# After delivering or socializing, randomly pick: socialize spot or exit
	# Options: cooler, plant, cabinet, exit (weighted toward socializing)
	var options = [
		{"type": "socialize", "pos": water_cooler_position, "name": "Water cooler break..."},
		{"type": "socialize", "pos": plant_position, "name": "Admiring the plant..."},
		{"type": "socialize", "pos": filing_cabinet_position, "name": "Filing paperwork..."},
		{"type": "exit", "pos": door_position, "name": "Heading out..."},
	]
	var choice = options[randi() % options.size()]

	if choice["type"] == "exit":
		_start_leaving()
	else:
		_start_socializing_at(choice["pos"], choice["name"])

func _start_socializing_at(target_pos: Vector2, status_text: String) -> void:
	socialize_timer = randf_range(2.0, 5.0)  # Hang out for 2-5 seconds
	state = State.SOCIALIZING
	# Add some randomness to exact position
	_build_path_to(target_pos + Vector2(randf_range(20, 50), randf_range(-20, 20)))
	if status_label:
		status_label.text = status_text

func _start_leaving() -> void:
	state = State.LEAVING
	_build_path_to(door_position)
	if status_label:
		status_label.text = "Heading out..."

func start_leaving() -> void:
	# Public method for external callers (e.g., when session exits)
	_start_leaving()

func _process_socializing(delta: float) -> void:
	# Walk to water cooler if not there yet
	if not path_waypoints.is_empty():
		_process_walking_path(delta)
		return

	# Chat animation (slight sway)
	if body:
		body.position.y = -15 + sin(Time.get_ticks_msec() * 0.005) * 2
	if head:
		head.position.y = -35 + sin(Time.get_ticks_msec() * 0.005 + 0.5) * 2

	# Higher chance of spontaneous bubbles while socializing
	_process_spontaneous_bubble(delta, true)

	socialize_timer -= delta
	if socialize_timer <= 0:
		# Pick next action: another spot or finally leave
		_pick_post_work_action()

func _process_meeting(delta: float) -> void:
	# Walk to meeting spot if not there yet
	if not path_waypoints.is_empty():
		_process_walking_path(delta)
		return

	# Track work time (meetings count as work)
	work_elapsed += delta

	# Subtle standing animation (shift weight)
	if body:
		body.position.y = -15 + sin(Time.get_ticks_msec() * 0.003) * 1.5
	if head:
		head.position.y = -35 + sin(Time.get_ticks_msec() * 0.003 + 0.3) * 1.5

	# Meeting-specific spontaneous bubbles
	_process_spontaneous_bubble(delta, false, true)  # Third param = is_meeting

	# Check if we have a pending completion
	if pending_completion:
		if work_elapsed >= min_work_time:
			print("[Agent %s] Meeting done, completing" % agent_id)
			pending_completion = false
			is_in_meeting = false
			_start_delivering()

func start_meeting(spot: Vector2) -> void:
	is_in_meeting = true
	meeting_spot = spot
	state = State.MEETING
	_build_path_to(spot)
	if status_label:
		status_label.text = "Heading to meeting..."

func _process_working(delta: float) -> void:
	# Track work time
	work_elapsed += delta

	# Process fidget animations if one is active
	if current_fidget != "":
		_process_fidget(delta)
	else:
		# Normal typing animation when not fidgeting
		if body:
			body.position.y = base_body_y + sin(Time.get_ticks_msec() * 0.008) * 1.5
		if head:
			head.position.y = base_head_y + sin(Time.get_ticks_msec() * 0.008) * 1.5

		# Time-based fidget trigger
		fidget_timer += delta
		if fidget_timer >= next_fidget_time:
			fidget_timer = 0.0
			_start_random_fidget()

	# Spontaneous voice bubble check
	_process_spontaneous_bubble(delta)

	# Check if we have a pending completion and met minimum work time
	if pending_completion:
		if work_elapsed >= min_work_time:
			print("[Agent %s] Min work time reached (%.1f >= %.1f), completing" % [agent_id, work_elapsed, min_work_time])
			pending_completion = false
			complete_work()

func _build_path_to(destination: Vector2) -> void:
	path_waypoints.clear()
	current_waypoint_index = 0

	# Use grid-based A* pathfinding if available
	if navigation_grid:
		var path = navigation_grid.find_path(position, destination)
		for waypoint in path:
			path_waypoints.append(waypoint)
		return

	# Fallback: direct path (shouldn't happen if grid is set up correctly)
	path_waypoints.append(destination)

func _process_completing(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = spawn_timer / 0.5
	if spawn_timer <= 0:
		work_completed.emit(self)

func complete_work() -> void:
	_create_document()
	# Clear personal items and tool display from desk
	_clear_personal_items_from_desk()
	if assigned_desk:
		if assigned_desk.has_method("hide_tool"):
			assigned_desk.hide_tool()
		assigned_desk.set_occupied(false)
	_start_delivering()

func _start_delivering() -> void:
	state = State.DELIVERING
	if not document:
		_create_document()
	# Pick a random approach position to the shredder (from any accessible side)
	var delivery_pos = _get_random_shredder_approach()
	_build_path_to(delivery_pos)
	if status_label:
		status_label.text = "Delivering..."

func _get_random_shredder_approach() -> Vector2:
	# Pick a random position around the shredder (avoiding the obstacle itself)
	# Shredder is at (1200, 520), obstacle is roughly 60x75 centered on it
	var approaches = [
		shredder_position + Vector2(0, 60),    # Below (south)
		shredder_position + Vector2(-50, 40),  # Bottom-left
		shredder_position + Vector2(-50, 0),   # Left (west)
		shredder_position + Vector2(-50, -30), # Top-left
	]
	# Pick a random approach
	return approaches[randi() % approaches.size()]

func _create_document() -> void:
	# Manila folder
	document = ColorRect.new()
	document.size = Vector2(18, 24)
	document.position = Vector2(-9, -65)
	document.color = Color(0.85, 0.78, 0.55)  # Manila folder color
	add_child(document)

	# Folder tab
	var tab = ColorRect.new()
	tab.size = Vector2(8, 4)
	tab.position = Vector2(5, -2)
	tab.color = Color(0.85, 0.78, 0.55)
	document.add_child(tab)

	# Paper sticking out
	var paper = ColorRect.new()
	paper.size = Vector2(14, 4)
	paper.position = Vector2(2, 2)
	paper.color = Color(0.98, 0.98, 0.95)
	document.add_child(paper)

func _deliver_document() -> void:
	if document:
		document.queue_free()
		document = null

func assign_desk(desk: Node2D) -> void:
	assigned_desk = desk
	desk.set_occupied(true)  # Reserve the desk
	target_position = desk.get_work_position()

func start_walking_to_desk() -> void:
	if assigned_desk:
		state = State.WALKING_TO_DESK
		_build_path_to(assigned_desk.get_work_position())
		if status_label:
			status_label.text = "Going to desk..."

func set_inbox_position(pos: Vector2) -> void:
	inbox_position = pos

func set_shredder_position(pos: Vector2) -> void:
	shredder_position = pos

func set_water_cooler_position(pos: Vector2) -> void:
	water_cooler_position = pos

func set_plant_position(pos: Vector2) -> void:
	plant_position = pos

func set_filing_cabinet_position(pos: Vector2) -> void:
	filing_cabinet_position = pos

func set_meeting_table_position(_pos: Vector2) -> void:
	# Meeting spot updates are handled by OfficeManager._update_meeting_spots()
	pass

func set_door_position(pos: Vector2) -> void:
	door_position = pos

func set_aisle_y(y: float) -> void:
	aisle_y = y

func set_description(desc: String) -> void:
	description = desc
	if status_label:
		if desc.length() > 25:
			status_label.text = desc.substr(0, 22) + "..."
		else:
			status_label.text = desc

func force_complete() -> void:
	match state:
		State.WORKING:
			# If we haven't worked long enough, delay completion
			if work_elapsed >= min_work_time:
				complete_work()
			else:
				pending_completion = true
				if status_label:
					status_label.text = "Wrapping up..."
		State.MEETING:
			# If we haven't met long enough, delay completion
			if work_elapsed >= min_work_time:
				is_in_meeting = false
				_start_delivering()
			else:
				pending_completion = true
				if status_label:
					status_label.text = "Wrapping up meeting..."
		State.SPAWNING, State.WALKING_TO_DESK:
			pending_completion = true
			if status_label:
				status_label.text = "Finishing up..."
		State.IDLE:
			state = State.COMPLETING
			spawn_timer = 0.5
		State.DELIVERING, State.SOCIALIZING, State.LEAVING, State.COMPLETING:
			pass  # Already on their way out

func show_tool(tool_name: String) -> void:
	current_tool = tool_name
	# No timer - tool persists until changed

	var icon = TOOL_ICONS.get(tool_name, "[" + tool_name.substr(0, 1) + "]")
	var color = TOOL_COLORS.get(tool_name, Color(0.5, 0.5, 0.5))

	# Show on desk monitor if we have an assigned desk
	if assigned_desk and assigned_desk.has_method("show_tool"):
		assigned_desk.show_tool(icon, color)
	else:
		# Fallback to floating label if no desk
		if tool_label and tool_bg:
			tool_label.text = icon
			tool_label.add_theme_color_override("font_color", color)
			tool_bg.color = Color(0.1, 0.1, 0.1, 0.9)
			tool_label.visible = true
			tool_bg.visible = true
			tool_label.modulate.a = 1.0
			tool_bg.modulate.a = 1.0

func _hide_tool() -> void:
	current_tool = ""
	# Hide desk tool display
	if assigned_desk and assigned_desk.has_method("hide_tool"):
		assigned_desk.hide_tool()
	# Also hide floating label if used
	if tool_label:
		tool_label.visible = false
	if tool_bg:
		tool_bg.visible = false

# Personal items functions
func _generate_personal_items() -> void:
	# Each worker has just 1 personal item
	var all_items = ["coffee_mug", "photo_frame", "plant", "pencil_cup", "stress_ball", "snack", "water_bottle", "figurine"]
	personal_item_types.clear()
	all_items.shuffle()
	personal_item_types.append(all_items[0])  # Just one item

func _place_personal_items_on_desk() -> void:
	if not assigned_desk:
		return

	# Clear any existing items first (defensive - in case previous agent didn't clean up)
	if assigned_desk.has_method("clear_personal_items"):
		assigned_desk.clear_personal_items()

	# Generate items if not already done
	if personal_item_types.is_empty():
		_generate_personal_items()

	# Place single item on desk (left side, personal_items container is pre-positioned)
	if personal_item_types.size() > 0:
		var item = _create_personal_item(personal_item_types[0])
		if item:
			item.position = Vector2(0, 0)  # Container is already positioned
			assigned_desk.add_personal_item(item)

func _clear_personal_items_from_desk() -> void:
	if assigned_desk:
		assigned_desk.clear_personal_items()

func _create_personal_item(item_type: String) -> Node2D:
	var item = Node2D.new()

	match item_type:
		"coffee_mug":
			# Mug body
			var mug = ColorRect.new()
			mug.size = Vector2(10, 14)
			mug.position = Vector2(0, 0)
			# Random mug color
			var mug_colors = [Color(0.9, 0.9, 0.9), Color(0.85, 0.3, 0.3), Color(0.3, 0.5, 0.85), Color(0.4, 0.7, 0.4), Color(0.95, 0.85, 0.4)]
			mug.color = mug_colors[randi() % mug_colors.size()]
			item.add_child(mug)
			# Handle
			var handle = ColorRect.new()
			handle.size = Vector2(4, 8)
			handle.position = Vector2(10, 3)
			handle.color = mug.color
			item.add_child(handle)

		"photo_frame":
			# Frame
			var frame = ColorRect.new()
			frame.size = Vector2(14, 16)
			frame.position = Vector2(0, -4)
			frame.color = Color(0.4, 0.3, 0.25)  # Wood color
			item.add_child(frame)
			# Photo inside
			var photo = ColorRect.new()
			photo.size = Vector2(10, 10)
			photo.position = Vector2(2, 2)
			photo.color = Color(0.7, 0.8, 0.9)  # Light blue (sky)
			item.add_child(photo)

		"plant":
			# Small terracotta pot
			var pot = ColorRect.new()
			pot.size = Vector2(14, 10)
			pot.position = Vector2(0, 4)
			pot.color = Color(0.65, 0.38, 0.25)  # Terracotta
			item.add_child(pot)
			# Pot rim
			var rim = ColorRect.new()
			rim.size = Vector2(16, 3)
			rim.position = Vector2(-1, 2)
			rim.color = Color(0.58, 0.32, 0.22)  # Darker terracotta
			item.add_child(rim)
			# Soil
			var soil = ColorRect.new()
			soil.size = Vector2(12, 3)
			soil.position = Vector2(1, 3)
			soil.color = Color(0.35, 0.25, 0.18)  # Dark brown soil
			item.add_child(soil)
			# Succulent/cactus body
			var cactus = ColorRect.new()
			cactus.size = Vector2(8, 10)
			cactus.position = Vector2(3, -6)
			cactus.color = Color(0.35, 0.55, 0.35)  # Green
			item.add_child(cactus)
			# Small arm/leaf
			var leaf = ColorRect.new()
			leaf.size = Vector2(4, 6)
			leaf.position = Vector2(10, -4)
			leaf.color = Color(0.38, 0.58, 0.38)  # Lighter green
			item.add_child(leaf)

		"pencil_cup":
			# Cup
			var cup = ColorRect.new()
			cup.size = Vector2(10, 14)
			cup.position = Vector2(0, 0)
			cup.color = Color(0.3, 0.3, 0.35)
			item.add_child(cup)
			# Pencils
			var pencil1 = ColorRect.new()
			pencil1.size = Vector2(2, 8)
			pencil1.position = Vector2(2, -6)
			pencil1.color = Color(0.9, 0.8, 0.2)  # Yellow
			item.add_child(pencil1)
			var pencil2 = ColorRect.new()
			pencil2.size = Vector2(2, 6)
			pencil2.position = Vector2(6, -4)
			pencil2.color = Color(0.2, 0.4, 0.8)  # Blue
			item.add_child(pencil2)

		"stress_ball":
			var ball = ColorRect.new()
			ball.size = Vector2(12, 12)
			ball.position = Vector2(0, 2)
			var ball_colors = [Color(0.9, 0.3, 0.3), Color(0.3, 0.7, 0.9), Color(0.9, 0.7, 0.2), Color(0.5, 0.9, 0.5)]
			ball.color = ball_colors[randi() % ball_colors.size()]
			item.add_child(ball)

		"snack":
			# Snack wrapper/bag
			var wrapper = ColorRect.new()
			wrapper.size = Vector2(14, 10)
			wrapper.position = Vector2(0, 4)
			var snack_colors = [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.9, 0.6, 0.1)]
			wrapper.color = snack_colors[randi() % snack_colors.size()]
			item.add_child(wrapper)

		"water_bottle":
			# Bottle
			var bottle = ColorRect.new()
			bottle.size = Vector2(8, 18)
			bottle.position = Vector2(0, -4)
			bottle.color = Color(0.6, 0.8, 0.95, 0.8)  # Translucent blue
			item.add_child(bottle)
			# Cap
			var cap = ColorRect.new()
			cap.size = Vector2(6, 4)
			cap.position = Vector2(1, -6)
			cap.color = Color(0.3, 0.5, 0.8)
			item.add_child(cap)

		"figurine":
			# Base
			var base = ColorRect.new()
			base.size = Vector2(10, 4)
			base.position = Vector2(0, 10)
			base.color = Color(0.3, 0.3, 0.3)
			item.add_child(base)
			# Figure body
			var fig = ColorRect.new()
			fig.size = Vector2(8, 14)
			fig.position = Vector2(1, -4)
			var fig_colors = [Color(0.8, 0.2, 0.2), Color(0.2, 0.6, 0.2), Color(0.2, 0.4, 0.8), Color(0.8, 0.8, 0.2)]
			fig.color = fig_colors[randi() % fig_colors.size()]
			item.add_child(fig)

		_:
			return null

	return item

# Click reaction functions
func _generate_reaction_phrases() -> void:
	# Generate a set of personality-based phrases for this worker
	var all_phrases = [
		# Busy responses
		["Can't talk now, on deadline!", "Super busy here!", "In the zone!", "Working on it!"],
		# Friendly responses
		["Hey there!", "Hi! Nice office, huh?", "Great to see you!", "How's it going?"],
		# Sarcastic/funny responses
		["Another meeting?", "Is it Friday yet?", "Need more coffee...", "Who moved my stapler?"],
		# Professional responses
		["Just reviewing the specs.", "Making progress!", "Almost done here.", "Back to work!"],
		# Tired responses
		["*yawn*", "Long day...", "Is it 5 yet?", "Coffee break soon?"],
		# Enthusiastic responses
		["Love this project!", "Crushing it today!", "Let's go!", "Productivity mode!"],
	]

	# Pick 2-3 random phrase groups
	reaction_phrases.clear()
	all_phrases.shuffle()
	for i in range(randi_range(2, 3)):
		if i < all_phrases.size():
			var group = all_phrases[i]
			# Pick 2-3 phrases from each group
			group.shuffle()
			for j in range(min(randi_range(2, 3), group.size())):
				reaction_phrases.append(group[j])

# Spontaneous phrases (context-aware)
const WORKING_PHRASES = [
	"Hmm...", "Interesting...", "Almost there!", "Let me think...",
	"Ah, I see!", "That's clever.", "One sec...", "Getting close!",
	"Just a bit more...", "Oh!", "Eureka!", "Compiling...",
	"Debugging...", "Reading docs...", "Found it!", "Nice!",
]

const SOCIALIZING_PHRASES = [
	"Great weather!", "Monday, huh?", "Coffee?", "Nice plant!",
	"Did you see that?", "How's it going?", "Break time!", "Ah, refreshing!",
	"Love this cooler.", "Quick break!", "Busy day!", "Same here.",
]

const MEETING_PHRASES = [
	"Good point.", "Let's sync up.", "Action items?", "Any blockers?",
	"Per my last...", "Circling back...", "Take it offline?", "Synergies!",
	"Moving forward...", "Aligned.", "Let's table that.", "Deep dive?",
	"Bandwidth?", "EOD works.", "Ping me later.", "Noted.",
	"That's a stretch.", "Can we scope it?", "Dependencies?", "Ship it!",
]

# Tool-aware phrase templates ({tool} gets replaced)
const TOOL_PHRASES_WORKING = [
	"Working on {tool}...", "This {tool}...", "Hmm, {tool}...",
	"Almost done with {tool}", "{tool} looks good", "Running {tool}...",
	"Checking {tool}...", "{tool} is tricky", "Nice {tool} result!",
]

const TOOL_PHRASES_MEETING = [
	"The {tool} shows...", "Per the {tool}...", "Based on {tool}...",
	"Running {tool} here", "{tool} says...", "Let me {tool} that",
	"My {tool} found...", "The {tool} output...", "Checking {tool}...",
]

func _get_tool_aware_phrase(tool_name: String, is_meeting: bool) -> String:
	var templates = TOOL_PHRASES_MEETING if is_meeting else TOOL_PHRASES_WORKING
	var template = templates[randi() % templates.size()]
	# Shorten tool name if too long
	var short_tool = tool_name
	if short_tool.length() > 12:
		short_tool = short_tool.substr(0, 10) + ".."
	return template.replace("{tool}", short_tool)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is on this agent
		var mouse_pos = get_local_mouse_position()
		var in_bounds = mouse_pos.x > -20 and mouse_pos.x < 20 and mouse_pos.y > -50 and mouse_pos.y < 35
		if in_bounds:
			_show_reaction()

func _show_reaction() -> void:
	# Don't show if already showing a reaction
	if reaction_timer > 0:
		return

	# Pick a random phrase
	if reaction_phrases.is_empty():
		_generate_reaction_phrases()

	var phrase = reaction_phrases[randi() % reaction_phrases.size()]

	# Create or update reaction bubble
	if reaction_bubble:
		reaction_bubble.queue_free()

	reaction_bubble = Node2D.new()
	reaction_bubble.z_index = 100
	add_child(reaction_bubble)

	# Speech bubble background
	var bubble_bg = ColorRect.new()
	var text_width = phrase.length() * 7 + 16
	bubble_bg.size = Vector2(max(text_width, 60), 24)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -95)
	bubble_bg.color = Color(1.0, 1.0, 0.85, 0.95)  # Light yellow
	reaction_bubble.add_child(bubble_bg)

	# Bubble border
	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(4, 4)
	bubble_border.position = bubble_bg.position - Vector2(2, 2)
	bubble_border.color = Color(0.3, 0.3, 0.25)
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	# Bubble pointer (triangle approximation with small rect)
	var pointer = ColorRect.new()
	pointer.size = Vector2(8, 8)
	pointer.position = Vector2(-4, -73)
	pointer.color = Color(1.0, 1.0, 0.85, 0.95)
	reaction_bubble.add_child(pointer)

	# Pointer border
	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(10, 10)
	pointer_border.position = Vector2(-5, -74)
	pointer_border.color = Color(0.3, 0.3, 0.25)
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	# Text
	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(8, 3)
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.15))
	reaction_bubble.add_child(text_label)

	# Set timer for how long the bubble shows
	reaction_timer = 2.5

func _update_reaction_timer(delta: float) -> void:
	if reaction_timer > 0:
		reaction_timer -= delta
		# Fade out near the end
		if reaction_timer < 0.5 and reaction_bubble:
			reaction_bubble.modulate.a = reaction_timer / 0.5
		if reaction_timer <= 0:
			if reaction_bubble:
				reaction_bubble.queue_free()
				reaction_bubble = null

# Idle fidget animation functions
func _start_random_fidget() -> void:
	var fidgets = ["head_scratch", "stretch", "look_around", "lean_back", "sip_drink", "adjust_posture"]
	current_fidget = fidgets[randi() % fidgets.size()]
	fidget_progress = 0.0
	next_fidget_time = randf_range(5.0, 15.0)  # Next fidget after this one

func _process_fidget(delta: float) -> void:
	if current_fidget == "":
		return

	fidget_progress += delta
	var fidget_duration = 1.5  # How long the fidget lasts
	var t = fidget_progress / fidget_duration

	match current_fidget:
		"head_scratch":
			# Head tilts slightly, then returns
			if head:
				var tilt = sin(t * PI) * 4
				head.position.x = -9 + tilt
				head.rotation = sin(t * PI) * 0.1

		"stretch":
			# Body leans back, then returns
			if body:
				var lean = sin(t * PI) * 3
				body.position.y = base_body_y - lean
			if head:
				var head_tilt = sin(t * PI) * 4
				head.position.y = base_head_y - head_tilt
				head.rotation = sin(t * PI) * -0.15

		"look_around":
			# Head turns left, then right, then center
			if head:
				if t < 0.33:
					head.position.x = -9 + (t / 0.33) * 3
				elif t < 0.66:
					head.position.x = -9 + 3 - ((t - 0.33) / 0.33) * 6
				else:
					head.position.x = -9 - 3 + ((t - 0.66) / 0.34) * 3

		"lean_back":
			# Lean back in chair, relax
			if body:
				body.position.y = base_body_y - sin(t * PI) * 2
			if head:
				head.position.y = base_head_y - sin(t * PI) * 3

		"sip_drink":
			# Head tilts back slightly (drinking)
			if head:
				var tilt_back = sin(t * PI) * 5
				head.position.y = base_head_y - tilt_back * 0.5
				head.rotation = sin(t * PI) * -0.2

		"adjust_posture":
			# Quick shift - lean forward then settle
			if body:
				if t < 0.3:
					body.position.y = base_body_y + (t / 0.3) * 2
				else:
					body.position.y = base_body_y + 2 - ((t - 0.3) / 0.7) * 2

	# Fidget complete
	if fidget_progress >= fidget_duration:
		_end_fidget()

func _end_fidget() -> void:
	current_fidget = ""
	fidget_progress = 0.0
	# Reset positions
	if head:
		head.position = Vector2(-9, base_head_y)
		head.rotation = 0
	if body:
		body.position.y = base_body_y

# Spontaneous voice bubble functions
func _process_spontaneous_bubble(delta: float, is_socializing: bool = false, is_meeting: bool = false) -> void:
	# Don't process if already showing a reaction
	if reaction_timer > 0:
		return

	# Cooldown between spontaneous bubbles
	if spontaneous_cooldown > 0:
		spontaneous_cooldown -= delta
		return

	spontaneous_bubble_timer += delta

	# Different intervals: meetings have higher chance (more chatty)
	var check_interval = SPONTANEOUS_CHECK_INTERVAL
	var chance = SPONTANEOUS_CHANCE
	if is_meeting:
		check_interval = SPONTANEOUS_CHECK_INTERVAL * 0.5  # Check more often in meetings
		chance = SPONTANEOUS_CHANCE * 2.0  # Much more chatty
	elif is_socializing:
		check_interval = SPONTANEOUS_CHECK_INTERVAL * 0.6
		chance = SPONTANEOUS_CHANCE * 1.5

	if spontaneous_bubble_timer >= check_interval:
		spontaneous_bubble_timer = 0.0
		if randf() < chance:
			# Check global coordination (only one spontaneous bubble at a time)
			if _can_show_spontaneous_globally():
				_show_spontaneous_reaction(is_socializing, is_meeting)
				spontaneous_cooldown = SPONTANEOUS_COOLDOWN

func _can_show_spontaneous_globally() -> bool:
	# Check with office manager if we can show a spontaneous bubble
	if office_manager and office_manager.has_method("can_show_spontaneous_bubble"):
		return office_manager.can_show_spontaneous_bubble()
	return true  # Default to yes if no manager

func _show_spontaneous_reaction(is_socializing: bool = false, is_meeting: bool = false) -> void:
	# Pick appropriate phrase based on context
	var phrase = ""

	# If we have a tool and it's work-related context, sometimes mention the tool
	if current_tool and not is_socializing and randf() < 0.5:
		phrase = _get_tool_aware_phrase(current_tool, is_meeting)
	else:
		var phrases = WORKING_PHRASES
		if is_meeting:
			phrases = MEETING_PHRASES
		elif is_socializing:
			phrases = SOCIALIZING_PHRASES
		phrase = phrases[randi() % phrases.size()]

	# Notify manager that we're showing a bubble
	if office_manager and office_manager.has_method("register_spontaneous_bubble"):
		office_manager.register_spontaneous_bubble(self)

	# Create smaller, quicker bubble than click reactions
	if reaction_bubble:
		reaction_bubble.queue_free()

	reaction_bubble = Node2D.new()
	reaction_bubble.z_index = 100
	add_child(reaction_bubble)

	# Smaller speech bubble for spontaneous thoughts
	var bubble_bg = ColorRect.new()
	var text_width = phrase.length() * 6 + 12
	bubble_bg.size = Vector2(max(text_width, 50), 20)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -90)
	bubble_bg.color = Color(0.95, 0.95, 0.90, 0.92)  # Slightly more transparent
	reaction_bubble.add_child(bubble_bg)

	# Thinner border
	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(2, 2)
	bubble_border.position = bubble_bg.position - Vector2(1, 1)
	bubble_border.color = Color(0.5, 0.5, 0.45)
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	# Smaller pointer
	var pointer = ColorRect.new()
	pointer.size = Vector2(6, 6)
	pointer.position = Vector2(-3, -71)
	pointer.color = Color(0.95, 0.95, 0.90, 0.92)
	reaction_bubble.add_child(pointer)

	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(8, 8)
	pointer_border.position = Vector2(-4, -72)
	pointer_border.color = Color(0.5, 0.5, 0.45)
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	# Smaller text
	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(6, 2)
	text_label.add_theme_font_size_override("font_size", 10)
	text_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.25))
	reaction_bubble.add_child(text_label)

	# Shorter display time for spontaneous bubbles
	reaction_timer = 1.8

func clear_spontaneous_bubble() -> void:
	# Called by manager when another agent wants to show a bubble
	if reaction_bubble and reaction_timer > 0.5:
		# Only clear if we've shown for at least 0.5s
		reaction_timer = 0.3  # Quick fade out
