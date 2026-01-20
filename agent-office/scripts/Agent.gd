extends Node2D
class_name Agent

signal work_completed(agent: Agent)

enum State { SPAWNING, WALKING_TO_DESK, WORKING, DELIVERING, SOCIALIZING, LEAVING, COMPLETING, IDLE, MEETING, FURNITURE_TOUR, CHATTING, WANDERING }
enum Mood { CONTENT, TIRED, FRUSTRATED, IRATE }

# Debug event logging helper - safely logs if DebugEventLog exists
func _log_debug_event(category: String, message: String) -> void:
	var debug_log = get_node_or_null("/root/Main/DebugEventLog")
	if debug_log == null:
		# Try static instance via class lookup
		var script = load("res://scripts/DebugEventLog.gd")
		if script and script.get("instance"):
			debug_log = script.instance
	if debug_log and debug_log.has_method("add_event"):
		debug_log.add_event(category, message, agent_id)

# Mood thresholds are now in AgentMood component

# Dynamic agent type assignment - colors/labels assigned as agents appear
# All agent types get assigned colors from the pool dynamically
const FIXED_AGENT_TYPES = {}

# Pool of colors for dynamic assignment (cycles through these)
const COLOR_POOL: Array[Color] = [
	OfficePalette.GRUVBOX_BLUE_BRIGHT,    # Blue
	OfficePalette.GRUVBOX_GREEN_BRIGHT,   # Green
	OfficePalette.GRUVBOX_RED_BRIGHT,     # Red
	OfficePalette.GRUVBOX_PURPLE_BRIGHT,  # Purple
	OfficePalette.GRUVBOX_ORANGE_BRIGHT,  # Orange
	OfficePalette.GRUVBOX_AQUA_BRIGHT,    # Aqua
	OfficePalette.GRUVBOX_YELLOW_BRIGHT,  # Yellow
	OfficePalette.GRUVBOX_BLUE,           # Dark blue
	OfficePalette.GRUVBOX_GREEN,          # Dark green
	OfficePalette.GRUVBOX_RED,            # Dark red
	OfficePalette.GRUVBOX_PURPLE,         # Dark purple
	OfficePalette.GRUVBOX_ORANGE,         # Dark orange
	OfficePalette.GRUVBOX_AQUA,           # Dark aqua
]

# Runtime mapping of agent_type -> assigned index in COLOR_POOL
static var _assigned_types: Dictionary = {}  # agent_type -> color_index
static var _next_color_index: int = 0

# Reset static state (call on scene reload to prevent stale color mappings)
static func reset_color_assignments() -> void:
	_assigned_types.clear()
	_next_color_index = 0

static func get_agent_color(type: String) -> Color:
	# Check fixed types first
	if FIXED_AGENT_TYPES.has(type):
		return FIXED_AGENT_TYPES[type]["color"]
	# Assign color dynamically if not seen before
	if not _assigned_types.has(type):
		_assigned_types[type] = _next_color_index
		_next_color_index = (_next_color_index + 1) % COLOR_POOL.size()
	return COLOR_POOL[_assigned_types[type]]

static func get_agent_label(type: String) -> String:
	# Check fixed types first
	if FIXED_AGENT_TYPES.has(type):
		return FIXED_AGENT_TYPES[type]["label"]
	# Generate a readable label from the type name
	# "full-stack-developer" -> "Full Stack Developer" (truncated for display)
	var label = type.replace("-", " ").replace("_", " ")
	# Capitalize first letter of each word
	var words = label.split(" ")
	var capitalized: Array[String] = []
	for word in words:
		if word.length() > 0:
			capitalized.append(word[0].to_upper() + word.substr(1))
	label = " ".join(capitalized)
	# Truncate if too long
	if label.length() > 12:
		label = label.substr(0, 11) + "."
	return label

# Tool icons and colors are now centralized in OfficePalette.TOOL_ICONS and OfficePalette.TOOL_COLORS

@export var agent_type: String = "default"
@export var description: String = ""

var agent_id: String = ""
var result: String = ""  # The response/result from this agent's work
var parent_id: String = ""
var session_id: String = ""
var profile_id: int = -1  # AgentProfile ID from roster (-1 = no profile)
var profile_name: String = ""  # Display name from roster profile
var profile_badges: Array[String] = []  # Badge IDs from profile
var profile_level: int = 0  # Level from profile
var _pending_profile = null  # Profile to apply once visuals are ready
var state: State = State.SPAWNING
var target_position: Vector2
var assigned_desk: Node2D = null
var shredder_position: Vector2 = OfficeConstants.SHREDDER_POSITION
var water_cooler_position: Vector2 = OfficeConstants.WATER_COOLER_POSITION
var plant_position: Vector2 = OfficeConstants.PLANT_POSITION
var filing_cabinet_position: Vector2 = OfficeConstants.FILING_CABINET_POSITION
var taskboard_position: Vector2 = OfficeConstants.TASKBOARD_POSITION
var meeting_table_position: Vector2 = OfficeConstants.MEETING_TABLE_POSITION
var door_position: Vector2 = OfficeConstants.DOOR_POSITION

# Floor bounds (agents can only walk here) - use centralized constants
const FLOOR_MIN_X: float = OfficeConstants.FLOOR_MIN_X
const FLOOR_MAX_X: float = OfficeConstants.FLOOR_MAX_X
const FLOOR_MIN_Y: float = OfficeConstants.FLOOR_MIN_Y
const FLOOR_MAX_Y: float = OfficeConstants.FLOOR_MAX_Y

# Obstacles to avoid (set by OfficeManager)
var obstacles: Array[Rect2] = []
var socialize_timer: float = 0.0

# Agent-to-agent chatting
var chat_timer: float = 0.0
var chatting_with: Agent = null  # Reference to the other agent we're chatting with
var chat_cooldown: float = 0.0  # Prevent immediate re-chatting after a chat ends
const CHAT_DURATION_MIN: float = 3.0
const CHAT_DURATION_MAX: float = 6.0
const CHAT_COOLDOWN_TIME: float = 15.0  # Time before this agent can chat again
const CHAT_PROXIMITY: float = 60.0  # How close agents need to be to start chatting
const POST_CHAT_EXIT_CHANCE: float = 0.35  # Chance to leave the office after a chat
const SOCIAL_SPOT_COOLDOWN: float = 20.0  # Seconds before revisiting the same spot

# Navigation nudge constants (for path retry when initial path fails)
const NAV_NUDGE_MAX_RETRIES: int = 2     # Max times to retry finding a path
const NAV_NUDGE_SAMPLES: int = 3         # Random offset samples per retry
const NAV_NUDGE_RADIUS: float = 40.0     # Radius for random offset when nudging destination

# Stuck detection constants
const WALK_STUCK_THRESHOLD: float = 0.5  # Distance below which agent is considered stuck
const WALK_STUCK_TIMEOUT: float = 1.2    # Seconds before stuck recovery triggers
const WALK_NUDGE_RADIUS: float = 18.0    # Radius for random recovery nudge

# Cat interaction
var cat_reaction_cooldown: float = 0.0
const CAT_REACTION_COOLDOWN_TIME: float = 30.0  # Time before reacting to cat again

# Meeting overflow state
var is_in_meeting: bool = false
var meeting_spot: Vector2 = Vector2.ZERO

# Interaction point reservation
var current_interaction_furniture: String = ""  # Which furniture we're at
var current_interaction_point_idx: int = -1     # Which point index we reserved
var wander_retries: int = 0                     # How many times we've wandered without finding a spot
const MAX_WANDER_RETRIES: int = 3               # Give up and leave after this many attempts

# Furniture tour (for smoke testing)
var furniture_tour_active: bool = false
var furniture_tour_index: int = 0
var furniture_tour_targets: Array = []

# Pathfinding
var path_waypoints: Array[Vector2] = []
var current_waypoint_index: int = 0
var navigation_grid: NavigationGrid = null  # Set by OfficeManager for grid-based pathfinding
var current_destination: Vector2 = Vector2.ZERO  # Track where we're heading
var destination_furniture: String = ""  # Track which furniture we're heading to (for recalculation)

const TOUR_CLEARANCE: int = 1
var spawn_timer: float = 0.0
var is_waiting_for_completion: bool = true
var pending_completion: bool = false
var min_work_time: float = OfficeConstants.MIN_WORK_TIME
var work_elapsed: float = 0.0
var last_task_duration: float = 0.0  # Duration of most recently completed task
var walk_speed_multiplier: float = 1.0

# Mood system - agents get tired/frustrated the longer they work
var time_on_floor: float = 0.0
var current_mood: Mood = Mood.CONTENT
var mood_indicator: Label = null  # Shows mood emoji above head

# Audio
var audio_manager = null  # AudioManager instance
var typing_timer: float = 0.0
const TYPING_INTERVAL: float = 0.3  # How often to trigger typing sound

# Document being carried
var document: ColorRect = null

# Tool display
var current_tool: String = ""

# Personal items this worker brings to their desk
var personal_item_types: Array[String] = []  # Which items this worker has

# Social spot cooldowns are now managed by AgentSocial component
var nav_nudge_retries: int = 0
var nav_retry_target: Vector2 = Vector2.ZERO
var walk_last_position: Vector2 = Vector2.ZERO
var walk_stuck_timer: float = 0.0

var office_manager: Node = null  # Set by OfficeManager for global coordination

# Component delegates
var visuals: AgentVisuals = null  # Visual creation and appearance
var bubbles: AgentBubbles = null  # Speech bubbles and reactions
var social: AgentSocial = null    # Social spot selection and cooldowns
var mood_component: AgentMood = null  # Mood tracking and fidget animations

# Fidget animations are now managed by AgentMood component

func _init() -> void:
	pass

func _ready() -> void:
	# Initialize component delegates
	visuals = AgentVisuals.new(self)
	visuals.create_visuals()
	visuals.update_appearance(agent_type)
	bubbles = AgentBubbles.new(self)
	bubbles.generate_reaction_phrases()
	social = AgentSocial.new(self)
	mood_component = AgentMood.new(self)
	# Apply pending profile appearance if it was set before _ready
	if _pending_profile:
		visuals.apply_profile_appearance(_pending_profile)
		_pending_profile = null
	if description and visuals and visuals.status_label:
		set_description(description)
	spawn_timer = OfficeConstants.AGENT_SPAWN_FADE_TIME
	walk_speed_multiplier = randf_range(0.9, 1.1)
	walk_last_position = position

func _exit_tree() -> void:
	# Release any reserved interaction points
	if is_instance_valid(office_manager):
		if current_interaction_furniture and office_manager.has_method("release_interaction_point"):
			office_manager.release_interaction_point(agent_id)
		if is_in_meeting and office_manager.has_method("_release_meeting_spot"):
			office_manager._release_meeting_spot(agent_id)

	# Release desk reservation
	if is_instance_valid(assigned_desk):
		assigned_desk.set_occupied(false)
		if assigned_desk.has_method("hide_tool"):
			assigned_desk.hide_tool()
		if assigned_desk.has_method("clear_personal_items"):
			assigned_desk.clear_personal_items()
	assigned_desk = null

	# Clear agent-to-agent chat reference
	chatting_with = null

	# Free dynamically created nodes
	if is_instance_valid(document):
		document.queue_free()
		document = null
	if bubbles:
		bubbles.cleanup()
	if is_instance_valid(mood_indicator):
		mood_indicator.queue_free()
		mood_indicator = null

func _process(delta: float) -> void:
	# Update z_index based on Y position - agents lower on screen render in front
	var new_z = int(position.y)
	if new_z != z_index:
		z_index = new_z

	# Track time on floor and update mood
	if state != State.SPAWNING and state != State.COMPLETING:
		time_on_floor += delta
		_update_mood()

	_check_mouse_hover()
	bubbles.update_reaction_timer(delta)

	# Update cooldowns
	if chat_cooldown > 0:
		chat_cooldown -= delta
	if cat_reaction_cooldown > 0:
		cat_reaction_cooldown -= delta
	_update_social_spot_cooldowns(delta)

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
		State.FURNITURE_TOUR:
			_process_walking_path(delta)
		State.CHATTING:
			_process_chatting(delta)
		State.WANDERING:
			_process_wandering(delta)

func _check_mouse_hover() -> void:
	var mouse_pos = get_local_mouse_position()
	# Check if mouse is within agent bounds (roughly -15 to 15 x, -45 to 30 y)
	var in_bounds = mouse_pos.x > -20 and mouse_pos.x < 20 and mouse_pos.y > -50 and mouse_pos.y < 35

	if in_bounds and not visuals.is_hovered:
		visuals.is_hovered = true
		_show_tooltip()
	elif not in_bounds and visuals.is_hovered:
		visuals.is_hovered = false
		_hide_tooltip()

func _show_tooltip() -> void:
	if not visuals:
		return
	visuals.show_tooltip(_build_tooltip_data())

func _hide_tooltip() -> void:
	if visuals:
		visuals.hide_tooltip()

func _build_tooltip_data() -> Dictionary:
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
		State.CHATTING: state_text = "Small talk"
		State.WANDERING: state_text = "Looking around"

	var lines: Array[String] = []
	var status_line = "Status: " + state_text
	if state == State.WORKING and work_elapsed > 0:
		status_line += " (%.0fs)" % work_elapsed
	if pending_completion:
		status_line += " [pending completion]"
	lines.append(status_line)

	var floor_time = get_floor_time_text()
	var mood_text = get_mood_text()
	if mood_text:
		lines.append("Mood: " + mood_text + (" (%s)" % floor_time if floor_time else ""))
	elif floor_time:
		lines.append(floor_time)

	if not profile_badges.is_empty():
		lines.append("Badges: " + ", ".join(profile_badges))

	if state == State.WORKING and current_tool:
		lines.append("Using: " + current_tool)

	if result and (state == State.DELIVERING or state == State.LEAVING or state == State.COMPLETING or state == State.SOCIALIZING):
		lines.append("")
		var res_text = result.strip_edges()
		if res_text.length() > 500:
			res_text = res_text.substr(0, 497) + "..."
		lines.append("Result: " + res_text)
	else:
		lines.append("")
		if description:
			var desc = description.strip_edges()
			if desc.length() > 500:
				desc = desc.substr(0, 497) + "..."
			lines.append("Task: " + desc)
		else:
			lines.append("(no task assigned)")

	return {
		"profile_name": profile_name,
		"profile_level": profile_level,
		"agent_type": agent_type,
		"agent_id": agent_id,
		"tooltip_text": "\n".join(lines)
	}

func _process_spawning(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = 1.0 - (spawn_timer / OfficeConstants.AGENT_SPAWN_FADE_TIME)
	if spawn_timer <= 0:
		modulate.a = 1.0
		if is_instance_valid(assigned_desk):
			start_walking_to_desk()
			if pending_completion and visuals.status_label:
				visuals.status_label.text = "Finishing up..."
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

	var speed = OfficeConstants.AGENT_WALK_SPEED * walk_speed_multiplier
	var distance = direction.length()
	if current_waypoint_index >= path_waypoints.size() - 1:
		var slow_factor = clamp(distance / 30.0, 0.4, 1.0)
		speed *= slow_factor
	var new_pos = position + direction.normalized() * speed * delta

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

	if position.distance_to(walk_last_position) < WALK_STUCK_THRESHOLD:
		walk_stuck_timer += delta
		if walk_stuck_timer >= WALK_STUCK_TIMEOUT:
			_recover_from_stuck()
			walk_stuck_timer = 0.0
	else:
		walk_stuck_timer = 0.0
	walk_last_position = position

func _recover_from_stuck() -> void:
	if current_destination == Vector2.ZERO:
		return

	_log_debug_event("STUCK", "Stuck recovery triggered at %s" % position)

	if navigation_grid and _try_nudge_path(current_destination, destination_furniture):
		_log_debug_event("STUCK", "Nudge path succeeded")
		return

	for _i in range(6):
		var nudge = position + Vector2(
			randf_range(-WALK_NUDGE_RADIUS, WALK_NUDGE_RADIUS),
			randf_range(-WALK_NUDGE_RADIUS, WALK_NUDGE_RADIUS)
		)
		nudge.x = clamp(nudge.x, FLOOR_MIN_X, FLOOR_MAX_X)
		nudge.y = clamp(nudge.y, FLOOR_MIN_Y, FLOOR_MAX_Y)

		if navigation_grid:
			var grid_pos = navigation_grid.world_to_grid(nudge)
			if navigation_grid.is_valid_grid_pos(grid_pos) and navigation_grid.is_walkable(grid_pos):
				_log_debug_event("STUCK", "Random nudge to %s" % nudge)
				position = nudge
				_build_path_to(current_destination, destination_furniture)
				return
		else:
			position = nudge
			return
	_log_debug_event("STUCK", "All recovery attempts failed, forcing idle")
	# Fallback: clean up state and go idle to prevent infinite stuck loop
	path_waypoints.clear()
	current_waypoint_index = 0
	walk_stuck_timer = 0.0
	# Release any reserved resources (desk, meeting spot) before going idle
	_handle_unreachable_destination()

func set_obstacles(obs: Array[Rect2]) -> void:
	obstacles = obs

func _on_path_complete() -> void:
	path_waypoints.clear()
	current_waypoint_index = 0

	match state:
		State.WALKING_TO_DESK:
			# Verify desk is still valid before starting work
			if not is_instance_valid(assigned_desk):
				_log_debug_event("STATE", "Desk became invalid during walk - going idle")
				state = State.IDLE
				if visuals and visuals.status_label:
					visuals.status_label.text = "Desk unavailable"
				return
			# Arrived at desk, start working
			work_elapsed = 0.0
			state = State.WORKING
			_log_debug_event("STATE", "Started working at desk")
			# Turn on monitor now that agent has arrived
			assigned_desk.set_monitor_active(true)
			# Place personal items on desk
			_place_personal_items_on_desk()
			if visuals and visuals.status_label:
				visuals.status_label.text = "Working..."
		State.DELIVERING:
			# Arrived at shredder, deliver document
			_log_debug_event("STATE", "Delivering document at shredder")
			_deliver_document()
			# Pick next action: socialize somewhere or leave
			_pick_post_work_action()
		State.LEAVING:
			# Arrived at door, complete and fade out
			state = State.COMPLETING
			spawn_timer = OfficeConstants.AGENT_SPAWN_FADE_TIME
			if visuals and visuals.status_label:
				visuals.status_label.text = "Goodbye!"
		State.FURNITURE_TOUR:
			# Arrived at a furniture item during tour
			_furniture_tour_arrived()

func _furniture_tour_arrived() -> void:
	if not furniture_tour_active:
		return

	# Bounds check before array access
	if furniture_tour_index >= furniture_tour_targets.size():
		furniture_tour_active = false
		return

	# Brief pause at each furniture item
	var current_target = furniture_tour_targets[furniture_tour_index]
	_log_debug_event("TOUR", "Arrived at %s" % current_target.get("name", "unknown"))
	if visuals and visuals.status_label:
		visuals.status_label.text = current_target.get("status", "Inspecting...")

	# Move to next target after a short delay
	furniture_tour_index += 1
	if furniture_tour_index < furniture_tour_targets.size():
		# Continue tour after brief pause
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or not furniture_tour_active:
			return
		# Re-validate child nodes after await
		if furniture_tour_index >= furniture_tour_targets.size():
			return
		var next_target = furniture_tour_targets[furniture_tour_index]
		if is_instance_valid(visuals.status_label):
			visuals.status_label.text = "Walking to " + next_target.get("name", "next")
		_build_path_to(next_target["pos"])
	else:
		# Tour complete
		furniture_tour_active = false
		if is_instance_valid(visuals.status_label):
			visuals.status_label.text = "Tour complete!"
		# Leave the office
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(self):
			_start_leaving()

func _is_walkable_with_clearance(world_pos: Vector2, clearance: int = TOUR_CLEARANCE) -> bool:
	if not navigation_grid:
		return true
	var grid_pos = navigation_grid.world_to_grid(world_pos)
	if not navigation_grid.is_valid_grid_pos(grid_pos):
		return false
	for dx in range(-clearance, clearance + 1):
		for dy in range(-clearance, clearance + 1):
			var neighbor = Vector2i(grid_pos.x + dx, grid_pos.y + dy)
			if not navigation_grid.is_valid_grid_pos(neighbor) or not navigation_grid.is_walkable(neighbor):
				return false
	return true

func _pick_tour_target(candidates: Array, fallback: Vector2) -> Vector2:
	if candidates.is_empty():
		return fallback
	if not navigation_grid:
		return candidates[randi() % candidates.size()]

	var shuffled = candidates.duplicate()
	shuffled.shuffle()

	for candidate in shuffled:
		if _is_walkable_with_clearance(candidate):
			return candidate

	for candidate in shuffled:
		var grid_pos = navigation_grid.world_to_grid(candidate)
		if navigation_grid.is_valid_grid_pos(grid_pos) and navigation_grid.is_walkable(grid_pos):
			return candidate

	return fallback

func _order_tour_targets_by_distance(targets: Array) -> Array:
	if targets.size() <= 1:
		return targets

	var remaining = targets.duplicate()
	var ordered: Array = []
	var current_pos = position

	while not remaining.is_empty():
		var best_index = 0
		var best_distance = INF
		for i in range(remaining.size()):
			var candidate = remaining[i]
			var distance = current_pos.distance_to(candidate["pos"])
			if distance < best_distance:
				best_distance = distance
				best_index = i
		var next_target = remaining.pop_at(best_index)
		ordered.append(next_target)
		current_pos = next_target["pos"]

	return ordered

func start_furniture_tour(meeting_table_pos: Vector2 = Vector2.ZERO) -> void:
	"""Start a furniture tour visiting all furniture items."""
	_log_debug_event("TOUR", "Starting furniture tour")
	furniture_tour_active = true
	furniture_tour_index = 0

	var targets: Array = []

	var cooler_candidates = [
		water_cooler_position + Vector2(50, 0),
		water_cooler_position + Vector2(50, 30),
		water_cooler_position + Vector2(50, -30),
		water_cooler_position + Vector2(20, 50),
	]
	targets.append({
		"pos": _pick_tour_target(cooler_candidates, water_cooler_position + Vector2(50, 0)),
		"name": "Water Cooler",
		"status": "At water cooler..."
	})

	var plant_candidates = [
		plant_position + Vector2(50, 0),
		plant_position + Vector2(50, 30),
		plant_position + Vector2(50, -30),
		plant_position + Vector2(20, 50),
	]
	targets.append({
		"pos": _pick_tour_target(plant_candidates, plant_position + Vector2(50, 0)),
		"name": "Plant",
		"status": "Admiring plant..."
	})

	var filing_candidates = [
		filing_cabinet_position + Vector2(50, 0),
		filing_cabinet_position + Vector2(50, 30),
		filing_cabinet_position + Vector2(50, -30),
		filing_cabinet_position + Vector2(30, 50),
	]
	targets.append({
		"pos": _pick_tour_target(filing_candidates, filing_cabinet_position + Vector2(50, 0)),
		"name": "Filing Cabinet",
		"status": "Checking files..."
	})

	var shredder_candidates = [
		shredder_position + Vector2(-60, 0),
		shredder_position + Vector2(-60, 30),
		shredder_position + Vector2(-60, -30),
		shredder_position + Vector2(0, 50),
	]
	targets.append({
		"pos": _pick_tour_target(shredder_candidates, shredder_position + Vector2(-60, 0)),
		"name": "Shredder",
		"status": "At shredder..."
	})

	# Add meeting table if position provided
	if meeting_table_pos != Vector2.ZERO:
		var meeting_candidates = [
			meeting_table_pos + Vector2(-70, 40),
			meeting_table_pos + Vector2(70, 40),
			meeting_table_pos + Vector2(-70, -40),
			meeting_table_pos + Vector2(70, -40),
			meeting_table_pos + Vector2(0, 60),
		]
		targets.append({
			"pos": _pick_tour_target(meeting_candidates, meeting_table_pos + Vector2(0, 60)),
			"name": "Meeting Table",
			"status": "At meeting table..."
		})

	furniture_tour_targets = _order_tour_targets_by_distance(targets)

	# Start walking to first target
	state = State.FURNITURE_TOUR
	if visuals and visuals.status_label:
		visuals.status_label.text = "Starting tour..."
	var first_target = furniture_tour_targets[0]
	_build_path_to(first_target["pos"])

func _pick_post_work_action(allow_exit: bool = true) -> void:
	# Release any current interaction point before picking a new action
	_release_current_interaction_point()

	# After delivering, pick: socialize around the office, or exit
	var options = _get_social_spots()
	if allow_exit:
		options.append({"type": "exit", "pos": door_position, "name": "Heading out...", "furniture": ""})
		options.append({"type": "exit", "pos": door_position, "name": "Time to go...", "furniture": ""})
	var choice = _choose_social_spot(options)

	if choice["type"] == "exit":
		_start_leaving()
	else:
		_mark_social_spot_cooldown(choice)
		_start_socializing_at(choice["pos"], choice["name"], choice.get("furniture", ""), choice.get("offset", true))

func _get_social_spots() -> Array:
	return [
		{"type": "socialize", "pos": water_cooler_position, "name": "Water cooler chat...", "furniture": "water_cooler", "offset": true, "weight": 3.0, "cooldown_key": "water_cooler"},
		{"type": "socialize", "pos": water_cooler_position, "name": "Getting a drink...", "furniture": "water_cooler", "offset": true, "weight": 3.0, "cooldown_key": "water_cooler"},
		{"type": "socialize", "pos": plant_position, "name": "Admiring the plant...", "furniture": "plant", "offset": true, "weight": 3.0, "cooldown_key": "plant"},
		{"type": "socialize", "pos": plant_position, "name": "Watering the plant...", "furniture": "plant", "offset": true, "weight": 3.0, "cooldown_key": "plant"},
		{"type": "socialize", "pos": _get_random_filing_cabinet_approach(), "name": "Checking files...", "furniture": "filing_cabinet", "offset": false, "weight": 1.0, "cooldown_key": "filing_cabinet"},
		{"type": "socialize", "pos": _get_random_shredder_approach(), "name": "Shredding leftovers...", "furniture": "shredder", "offset": false, "weight": 1.0, "cooldown_key": "shredder"},
		{"type": "socialize", "pos": _get_random_taskboard_approach(), "name": "Reviewing tasks...", "furniture": "taskboard", "offset": false, "weight": 2.0, "cooldown_key": "taskboard"},
		{"type": "socialize", "pos": _get_random_meeting_table_approach(), "name": "Passing the table...", "furniture": "meeting_table", "offset": false, "weight": 2.0, "cooldown_key": "meeting_table"},
	]

func _choose_social_spot(options: Array) -> Dictionary:
	return social.choose_social_spot(options)

func _mark_social_spot_cooldown(option: Dictionary) -> void:
	social.mark_cooldown(option)

func _update_social_spot_cooldowns(delta: float) -> void:
	social.update_cooldowns(delta)

func _start_socializing_at(target_pos: Vector2, status_text: String, furniture_name: String = "", apply_offset: bool = true) -> void:
	# Release any previously held interaction point
	_release_current_interaction_point()

	# Check if this furniture uses interaction points
	if is_instance_valid(office_manager) and _is_tracked_furniture(furniture_name):
		var point_idx = office_manager.reserve_interaction_point(furniture_name, agent_id)
		if point_idx == -1:
			# All points occupied - start wandering
			_start_wandering()
			return

		# Use the reserved point position
		current_interaction_furniture = furniture_name
		current_interaction_point_idx = point_idx
		target_pos = office_manager.get_interaction_point_position(furniture_name, point_idx)
		apply_offset = false  # Position is exact, no offset needed
		wander_retries = 0  # Reset on successful reservation

	socialize_timer = randf_range(OfficeConstants.SOCIALIZE_TIME_MIN, OfficeConstants.SOCIALIZE_TIME_MAX)
	state = State.SOCIALIZING
	var spot_name = furniture_name if furniture_name else "spot"
	_log_debug_event("STATE", "Socializing at %s" % spot_name)
	var destination = target_pos
	if apply_offset:
		# Add some randomness to exact position
		destination += Vector2(randf_range(20, 50), randf_range(-20, 20))
	_build_path_to(destination, furniture_name)
	if visuals and visuals.status_label:
		visuals.status_label.text = status_text

func _is_tracked_furniture(furniture_name: String) -> bool:
	return social.is_tracked_furniture(furniture_name)

func _release_current_interaction_point() -> void:
	"""Release any interaction point we're currently holding."""
	if is_instance_valid(office_manager) and current_interaction_furniture:
		office_manager.release_interaction_point(agent_id)
		current_interaction_furniture = ""
		current_interaction_point_idx = -1

func _start_wandering() -> void:
	"""Start wandering when no interaction points are available."""
	state = State.WANDERING
	_log_debug_event("STATE", "Wandering (no spots available, attempt %d)" % (wander_retries + 1))

	# Pick a random position in the main aisle area
	var wander_pos = Vector2(
		randf_range(OfficeConstants.FLOOR_MIN_X + 150, OfficeConstants.FLOOR_MAX_X - 150),
		randf_range(OfficeConstants.MAIN_AISLE_Y - 30, OfficeConstants.FLOOR_MAX_Y - 50)
	)

	socialize_timer = randf_range(OfficeConstants.SOCIALIZE_TIME_MIN, OfficeConstants.SOCIALIZE_TIME_MAX)
	_build_path_to(wander_pos)

	if visuals and visuals.status_label:
		visuals.status_label.text = "Looking around..."

func _process_wandering(delta: float) -> void:
	"""Process wandering state - walk to random position, then retry finding a spot."""
	# If we have waypoints, keep walking
	if not path_waypoints.is_empty():
		_process_walking_path(delta)
		return

	# Idle animation while waiting (looking around)
	if visuals.body:
		visuals.body.position.y = -15 + sin(Time.get_ticks_msec() * 0.003) * 1.5
	if visuals.head:
		visuals.head.position.y = -35 + sin(Time.get_ticks_msec() * 0.003 + 0.5) * 1.5

	# Count down timer
	socialize_timer -= delta
	if socialize_timer <= 0:
		wander_retries += 1
		if wander_retries >= MAX_WANDER_RETRIES:
			# Give up, leave the office
			_log_debug_event("STATE", "Giving up after %d wander attempts" % MAX_WANDER_RETRIES)
			_start_leaving()
		else:
			# Try to find a social spot again
			_pick_post_work_action()

func _start_leaving() -> void:
	_log_debug_event("STATE", "Leaving office")

	# Release any interaction point before leaving
	_release_current_interaction_point()

	state = State.LEAVING
	# Release desk and turn off monitor before leaving
	if is_instance_valid(assigned_desk):
		if assigned_desk.has_method("hide_tool"):
			assigned_desk.hide_tool()
		assigned_desk.set_occupied(false)
	assigned_desk = null
	_build_path_to(door_position)
	if visuals and visuals.status_label:
		visuals.status_label.text = "Heading out..."

func start_leaving() -> void:
	# Public method for external callers (e.g., when session exits)
	_start_leaving()

func _process_socializing(delta: float) -> void:
	# Walk to water cooler if not there yet
	if not path_waypoints.is_empty():
		_process_walking_path(delta)
		return

	# Chat animation (slight sway)
	if visuals.body:
		visuals.body.position.y = -15 + sin(Time.get_ticks_msec() * 0.005) * 2
	if visuals.head:
		visuals.head.position.y = -35 + sin(Time.get_ticks_msec() * 0.005 + 0.5) * 2

	# Higher chance of spontaneous bubbles while socializing
	bubbles.process_spontaneous_bubble(delta, true, false, current_mood, current_tool, office_manager)

	socialize_timer -= delta
	if socialize_timer <= 0:
		# Pick next action: another spot or finally leave
		_pick_post_work_action()

func _process_chatting(delta: float) -> void:
	# Chat animation - agents face each other and sway slightly
	if visuals.body:
		visuals.body.position.y = -15 + sin(Time.get_ticks_msec() * 0.004) * 1.5
	if visuals.head:
		visuals.head.position.y = -35 + sin(Time.get_ticks_msec() * 0.004 + 0.3) * 1.5

	# Spontaneous bubbles during chat
	bubbles.process_spontaneous_bubble(delta, true, false, current_mood, current_tool, office_manager)

	chat_timer -= delta
	if chat_timer <= 0:
		end_chat()

# Called by OfficeManager when two idle agents are close enough
func start_chat_with(other_agent: Agent) -> void:
	if state != State.IDLE and state != State.SOCIALIZING:
		return
	if chat_cooldown > 0:
		return

	chatting_with = other_agent
	chat_timer = randf_range(CHAT_DURATION_MIN, CHAT_DURATION_MAX)
	state = State.CHATTING
	_log_debug_event("STATE", "Started chatting with %s" % other_agent.agent_id.substr(0, 8))

	# Stop walking
	path_waypoints.clear()
	current_waypoint_index = 0

	# Face the other agent
	if other_agent.global_position.x < global_position.x:
		_set_facing_direction(true)  # Face left
	else:
		_set_facing_direction(false)  # Face right

	# Show a greeting bubble
	_show_small_talk_bubble()

	if visuals and visuals.status_label:
		visuals.status_label.text = "Chatting..."

func end_chat() -> void:
	chat_cooldown = CHAT_COOLDOWN_TIME
	chatting_with = null

	# Reset head position after facing other agent
	if visuals.head:
		visuals.head.position.x = -9  # Default center position

	_start_post_chat_action()

func _start_post_chat_action() -> void:
	var exit_chance = POST_CHAT_EXIT_CHANCE
	if agent_type == "orchestrator":
		exit_chance = 0.0

	if randf() < exit_chance:
		_start_leaving()
		return

	var spots = _get_social_spots()
	var choice = _choose_social_spot(spots)
	_mark_social_spot_cooldown(choice)
	_start_socializing_at(choice["pos"], choice["name"], choice.get("furniture", ""), choice.get("offset", true))

func _show_small_talk_bubble() -> void:
	bubbles.show_small_talk_bubble()

# Called when near the office cat
func react_to_cat() -> void:
	if cat_reaction_cooldown > 0:
		return
	if state == State.COMPLETING or state == State.SPAWNING or state == State.LEAVING:
		return

	cat_reaction_cooldown = CAT_REACTION_COOLDOWN_TIME
	bubbles.show_cat_reaction()

func can_chat() -> bool:
	# Can this agent start a chat?
	return (state == State.IDLE or state == State.SOCIALIZING) and chat_cooldown <= 0 and chatting_with == null and path_waypoints.is_empty()

func can_react_to_cat() -> bool:
	return cat_reaction_cooldown <= 0 and state != State.COMPLETING and state != State.SPAWNING and state != State.LEAVING

func _process_meeting(delta: float) -> void:
	# Walk to meeting spot if not there yet
	if not path_waypoints.is_empty():
		_process_walking_path(delta)
		return

	# Track work time (meetings count as work)
	work_elapsed += delta

	# Subtle standing animation (shift weight)
	var t = Time.get_ticks_msec() * 0.003
	var body_bob = sin(t) * 1.5
	var head_bob = sin(t + 0.3) * 1.5
	if visuals.body:
		visuals.body.position.y = -15 + body_bob
	if visuals.head:
		visuals.head.position.y = -35 + head_bob

	# Meeting-specific spontaneous bubbles
	bubbles.process_spontaneous_bubble(delta, false, true, current_mood, current_tool, office_manager)

	# Check if we have a pending completion
	if pending_completion:
		if work_elapsed >= min_work_time:
			_log_debug_event("STATE", "Meeting complete, delivering")
			pending_completion = false
			is_in_meeting = false
			_start_delivering()

func start_meeting(spot: Vector2) -> void:
	is_in_meeting = true
	meeting_spot = spot
	state = State.MEETING
	_log_debug_event("STATE", "Joining meeting")
	_build_path_to(spot)
	if visuals and visuals.status_label:
		visuals.status_label.text = "Heading to meeting..."

func _process_working(delta: float) -> void:
	# Track work time
	work_elapsed += delta

	# Process fidget animations if one is active
	if mood_component.is_fidgeting():
		_process_fidget(delta)
	else:
		# Normal typing animation when not fidgeting
		var t = Time.get_ticks_msec() * 0.008
		var bob = sin(t) * 1.5
		if visuals.body:
			visuals.body.position.y = mood_component.base_body_y + bob
		if visuals.head:
			visuals.head.position.y = mood_component.base_head_y + bob

		# Typing sound
		typing_timer += delta
		if typing_timer >= TYPING_INTERVAL:
			typing_timer = 0.0
			if audio_manager and randf() < 0.3:  # 30% chance per interval to avoid constant sound
				audio_manager.play_typing()

		# Time-based fidget trigger
		if mood_component.update_fidget_timer(delta):
			_start_random_fidget()

	# Spontaneous voice bubble check
	bubbles.process_spontaneous_bubble(delta, false, false, current_mood, current_tool, office_manager)

	# Check if we have a pending completion and met minimum work time
	if pending_completion:
		if work_elapsed >= min_work_time:
			_log_debug_event("STATE", "Work complete after %.1fs" % work_elapsed)
			pending_completion = false
			complete_work()

func _build_path_to(destination: Vector2, furniture_name: String = "") -> bool:
	var had_waypoints = not path_waypoints.is_empty()
	var old_index = current_waypoint_index
	path_waypoints.clear()
	current_waypoint_index = 0
	current_destination = destination
	destination_furniture = furniture_name
	walk_stuck_timer = 0.0
	walk_last_position = position
	if nav_retry_target.distance_to(destination) > 1.0:
		nav_retry_target = destination
		nav_nudge_retries = 0

	# Use grid-based A* pathfinding if available
	if navigation_grid:
		var path = navigation_grid.find_path(position, destination)
		if path.is_empty():
			if _try_nudge_path(destination, furniture_name):
				_log_debug_event("PATH", "Nudge path to %s" % furniture_name)
				return true
			# Path is unreachable - give up and go idle
			_log_debug_event("PATH", "FAILED: Cannot reach %s" % destination)
			_handle_unreachable_destination()
			return false
		for waypoint in path:
			path_waypoints.append(waypoint)
		if had_waypoints and old_index > 0:
			_log_debug_event("PATH", "Rebuilt path (was at wp %d) -> %s" % [old_index, furniture_name if furniture_name else "pos"])
		else:
			_log_debug_event("PATH", "New path (%d wps) -> %s" % [path.size(), furniture_name if furniture_name else "pos"])
		return true

	# Fallback: direct path (shouldn't happen if grid is set up correctly)
	path_waypoints.append(destination)
	return true

func _try_nudge_path(destination: Vector2, furniture_name: String) -> bool:
	if nav_nudge_retries >= NAV_NUDGE_MAX_RETRIES:
		return false
	nav_nudge_retries += 1
	for i in range(NAV_NUDGE_SAMPLES):
		var offset = Vector2(randf_range(-NAV_NUDGE_RADIUS, NAV_NUDGE_RADIUS), randf_range(-NAV_NUDGE_RADIUS, NAV_NUDGE_RADIUS))
		var nudged = destination + offset
		var path = navigation_grid.find_path(position, nudged)
		if path.is_empty():
			continue
		path_waypoints.clear()
		current_waypoint_index = 0
		current_destination = nudged
		destination_furniture = furniture_name
		for waypoint in path:
			path_waypoints.append(waypoint)
		return true
	return false

func _handle_unreachable_destination() -> void:
	_log_debug_event("NAV", "Got lost - destination unreachable")
	destination_furniture = ""
	current_destination = Vector2.ZERO
	nav_nudge_retries = 0
	# Release any reserved resources to avoid blocking other agents.
	if state == State.WALKING_TO_DESK and is_instance_valid(assigned_desk):
		assigned_desk.set_occupied(false)
		assigned_desk = null
	elif state == State.MEETING:
		is_in_meeting = false
		if is_instance_valid(office_manager) and office_manager.has_method("_release_meeting_spot"):
			office_manager._release_meeting_spot(agent_id)
	# Transition to idle or leaving based on current state
	match state:
		State.FURNITURE_TOUR:
			# Skip to next tour target or finish tour
			furniture_tour_index += 1
			if furniture_tour_index < furniture_tour_targets.size():
				var next_target = furniture_tour_targets[furniture_tour_index]
				if visuals and visuals.status_label:
					visuals.status_label.text = "Skipping to " + next_target.get("name", "next")
				_build_path_to(next_target["pos"])
			else:
				furniture_tour_active = false
				_start_leaving()
		State.SOCIALIZING, State.DELIVERING:
			# Can't reach destination, just leave
			_start_leaving()
		_:
			state = State.IDLE
			if visuals and visuals.status_label:
				visuals.status_label.text = "Can't get there..."

func on_furniture_moved(furniture_name: String, new_position: Vector2) -> void:
	"""Called when furniture moves - recalculate path if we're heading there."""
	if destination_furniture != furniture_name:
		return

	if path_waypoints.is_empty():
		return

	_log_debug_event("NAV", "Furniture moved: %s -> recalc path" % furniture_name)

	# Recalculate path to new position (with some offset for approach)
	var approach_offset = Vector2(randf_range(30, 50), randf_range(-20, 20))
	_build_path_to(new_position + approach_offset, furniture_name)

func _process_completing(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = spawn_timer / OfficeConstants.AGENT_SPAWN_FADE_TIME
	if spawn_timer <= 0:
		work_completed.emit(self)

func complete_work() -> void:
	_log_debug_event("STATE", "Work completed (%.1fs)" % work_elapsed)
	# Record task duration for speed achievements
	last_task_duration = work_elapsed
	_create_document()
	# Clear personal items and tool display from desk
	_clear_personal_items_from_desk()
	if is_instance_valid(assigned_desk):
		if assigned_desk.has_method("hide_tool"):
			assigned_desk.hide_tool()
		assigned_desk.set_occupied(false)
	_start_delivering()

func _start_delivering() -> void:
	state = State.DELIVERING
	if not document:
		_create_document()
	# Randomly choose between shredder (destroy) or filing cabinet (archive)
	if randf() < 0.5:
		var delivery_pos = _get_random_shredder_approach()
		_build_path_to(delivery_pos, "shredder")
		if visuals and visuals.status_label:
			visuals.status_label.text = "Shredding docs..."
	else:
		var delivery_pos = _get_random_filing_cabinet_approach()
		_build_path_to(delivery_pos, "filing_cabinet")
		if visuals and visuals.status_label:
			visuals.status_label.text = "Filing away..."

func _get_random_shredder_approach() -> Vector2:
	# Pick a random position around the shredder (avoiding the obstacle itself)
	var approaches = [
		shredder_position + Vector2(0, 60),    # Below (south)
		shredder_position + Vector2(-50, 40),  # Bottom-left
		shredder_position + Vector2(-50, 0),   # Left (west)
		shredder_position + Vector2(-50, -30), # Top-left
	]
	return approaches[randi() % approaches.size()]

func _get_random_filing_cabinet_approach() -> Vector2:
	# Pick a random position around the filing cabinet
	var approaches = [
		filing_cabinet_position + Vector2(50, 0),   # Right (accessible from floor)
		filing_cabinet_position + Vector2(50, 30),  # Bottom-right
		filing_cabinet_position + Vector2(50, -30), # Top-right
		filing_cabinet_position + Vector2(30, 50),  # Below
	]
	return approaches[randi() % approaches.size()]

func _get_wall_item_approaches(top_left: Vector2, size: Vector2, front_offset: float = 20.0) -> Array[Vector2]:
	var front_y = top_left.y + size.y + front_offset
	var left_x = top_left.x + 20
	var center_x = top_left.x + size.x / 2
	var right_x = top_left.x + size.x - 20
	return [
		Vector2(left_x, front_y),
		Vector2(center_x, front_y),
		Vector2(right_x, front_y),
	]

func _get_random_taskboard_approach() -> Vector2:
	# Pick a random position in front of the taskboard (mounted on wall)
	var approaches = _get_wall_item_approaches(taskboard_position, OfficeConstants.TASKBOARD_SIZE, 20.0)
	return _pick_tour_target(approaches, approaches[1])

func _get_random_meeting_table_approach() -> Vector2:
	# Pick a random position around the meeting table
	var approaches = [
		meeting_table_position + Vector2(-70, 40),
		meeting_table_position + Vector2(70, 40),
		meeting_table_position + Vector2(0, 60),
	]
	return approaches[randi() % approaches.size()]

func _create_document() -> void:
	# Manila folder - positioned at chest/hand level for carrying
	document = ColorRect.new()
	document.size = Vector2(18, 24)
	document.position = Vector2(12, -20)  # Held at side, chest level
	document.color = OfficePalette.MANILA_FOLDER
	add_child(document)

	# Folder tab
	var tab = ColorRect.new()
	tab.size = Vector2(8, 4)
	tab.position = Vector2(5, -2)
	tab.color = OfficePalette.MANILA_FOLDER
	document.add_child(tab)

	# Paper sticking out
	var paper = ColorRect.new()
	paper.size = Vector2(14, 4)
	paper.position = Vector2(2, 2)
	paper.color = OfficePalette.PAPER_WHITE
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
	if is_instance_valid(assigned_desk):
		state = State.WALKING_TO_DESK
		_build_path_to(assigned_desk.get_work_position())
		if visuals and visuals.status_label:
			visuals.status_label.text = "Going to desk..."

func set_shredder_position(pos: Vector2) -> void:
	shredder_position = pos

func set_water_cooler_position(pos: Vector2) -> void:
	water_cooler_position = pos

func set_plant_position(pos: Vector2) -> void:
	plant_position = pos

func set_filing_cabinet_position(pos: Vector2) -> void:
	filing_cabinet_position = pos

func set_taskboard_position(pos: Vector2) -> void:
	taskboard_position = pos

func set_meeting_table_position(pos: Vector2) -> void:
	meeting_table_position = pos

func set_door_position(pos: Vector2) -> void:
	door_position = pos

func set_description(desc: String) -> void:
	description = desc
	if visuals and visuals.status_label:
		if desc.length() > 25:
			visuals.status_label.text = desc.substr(0, 22) + "..."
		else:
			visuals.status_label.text = desc

func set_result(res: String) -> void:
	result = res
	# Show a brief summary as a speech bubble when result is set
	if result:
		bubbles.show_result_bubble(agent_id)

func apply_profile_appearance(profile) -> void:
	if visuals:
		visuals.apply_profile_appearance(profile)
	else:
		# Store for later - will be applied in _ready() after visuals are created
		_pending_profile = profile

func force_complete(bypass_min_time: bool = false) -> void:
	match state:
		State.WORKING:
			# If we haven't worked long enough, delay completion (unless bypassed)
			if bypass_min_time or work_elapsed >= min_work_time:
				complete_work()
			else:
				pending_completion = true
				if visuals and visuals.status_label:
					visuals.status_label.text = "Wrapping up..."
		State.MEETING:
			# If we haven't met long enough, delay completion (unless bypassed)
			if bypass_min_time or work_elapsed >= min_work_time:
				is_in_meeting = false
				_start_delivering()
			else:
				pending_completion = true
				if visuals and visuals.status_label:
					visuals.status_label.text = "Wrapping up meeting..."
		State.SPAWNING, State.WALKING_TO_DESK:
			if bypass_min_time:
				# Skip to leaving immediately
				state = State.LEAVING
				spawn_timer = OfficeConstants.AGENT_EXIT_FADE_TIME
			else:
				pending_completion = true
				if visuals and visuals.status_label:
					visuals.status_label.text = "Finishing up..."
		State.IDLE:
			state = State.COMPLETING
			spawn_timer = OfficeConstants.AGENT_SPAWN_FADE_TIME
		State.DELIVERING, State.SOCIALIZING, State.LEAVING, State.COMPLETING:
			pass  # Already on their way out

func show_tool(tool_name: String) -> void:
	current_tool = tool_name
	# No timer - tool persists until changed

	var icon = OfficePalette.TOOL_ICONS.get(tool_name, "[" + tool_name.substr(0, 1) + "]")
	var color = OfficePalette.TOOL_COLORS.get(tool_name, OfficePalette.TOOL_DEFAULT)

	# Show on desk monitor if we have an assigned desk
	if is_instance_valid(assigned_desk) and assigned_desk.has_method("show_tool"):
		assigned_desk.show_tool(icon, color)
	else:
		# Fallback to floating label if no desk
		if visuals.tool_label and visuals.tool_bg:
			visuals.tool_label.text = icon
			visuals.tool_label.add_theme_color_override("font_color", color)
			visuals.tool_bg.color = OfficePalette.UI_BG_DARKER
			visuals.tool_label.visible = true
			visuals.tool_bg.visible = true
			visuals.tool_label.modulate.a = 1.0
			visuals.tool_bg.modulate.a = 1.0

func _hide_tool() -> void:
	current_tool = ""
	# Hide desk tool display
	if is_instance_valid(assigned_desk) and assigned_desk.has_method("hide_tool"):
		assigned_desk.hide_tool()
	# Also hide floating label if used
	if visuals.tool_label:
		visuals.tool_label.visible = false
	if visuals.tool_bg:
		visuals.tool_bg.visible = false

# Personal items functions (uses PersonalItemFactory for item creation)
func _generate_personal_items() -> void:
	personal_item_types.clear()
	personal_item_types.append(PersonalItemFactory.get_random_item_type())

func _place_personal_items_on_desk() -> void:
	if not is_instance_valid(assigned_desk):
		return

	# Clear any existing items first (defensive - in case previous agent didn't clean up)
	if assigned_desk.has_method("clear_personal_items"):
		assigned_desk.clear_personal_items()

	# Generate items if not already done
	if personal_item_types.is_empty():
		_generate_personal_items()

	# Place single item on desk
	if personal_item_types.size() > 0:
		var item = PersonalItemFactory.create_item(personal_item_types[0])
		if item:
			item.position = Vector2(0, 0)
			assigned_desk.add_personal_item(item)

func _clear_personal_items_from_desk() -> void:
	if is_instance_valid(assigned_desk):
		assigned_desk.clear_personal_items()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is on this agent
		var mouse_pos = get_local_mouse_position()
		var in_bounds = mouse_pos.x > -20 and mouse_pos.x < 20 and mouse_pos.y > -50 and mouse_pos.y < 35
		if in_bounds:
			bubbles.show_reaction()

# Set which direction the agent faces (for chatting)
func _set_facing_direction(face_left: bool) -> void:
	# This is a simple implementation - flip the head position slightly
	# In a more complex setup, you'd mirror sprites
	if visuals.head:
		if face_left:
			visuals.head.position.x = -4  # Slightly left of center
		else:
			visuals.head.position.x = 4   # Slightly right of center

func _update_mood() -> void:
	mood_component.time_on_floor = time_on_floor
	var new_mood_val = mood_component.update_mood()
	# Sync mood enum (AgentMood.Mood -> Agent.Mood)
	match new_mood_val:
		AgentMood.Mood.CONTENT: current_mood = Mood.CONTENT
		AgentMood.Mood.TIRED: current_mood = Mood.TIRED
		AgentMood.Mood.FRUSTRATED: current_mood = Mood.FRUSTRATED
		AgentMood.Mood.IRATE: current_mood = Mood.IRATE

func get_mood_text() -> String:
	return mood_component.get_mood_text()

func get_floor_time_text() -> String:
	mood_component.time_on_floor = time_on_floor
	return mood_component.get_floor_time_text()

func _start_random_fidget() -> void:
	mood_component.start_random_fidget()

func _process_fidget(delta: float) -> void:
	mood_component.process_fidget(delta, visuals)

func _end_fidget() -> void:
	mood_component.end_fidget(visuals)

func clear_spontaneous_bubble() -> void:
	# Called by manager when another agent wants to show a bubble
	bubbles.clear_spontaneous_bubble()
