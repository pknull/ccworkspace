extends Node2D
class_name McpManager

# =============================================================================
# MCP MANAGER
# =============================================================================
# A walking "Manager" entity that represents the MCP connection.
# Patrols the office, checks on agents, and reacts to MCP tool invocations.
# Follows OfficeCat pattern - state machine, NavigationGrid pathfinding.

enum State { INACTIVE, ENTERING, IDLE, PATROLLING, CHECKING_AGENT, REACTING, WALKING_TO, LEAVING }

var state: State = State.INACTIVE
var target_position: Vector2
var speed: float = 45.0  # Slightly slower than cat, more deliberate

# Visuals component
var visuals: McpManagerVisuals = null

# Timers
var state_timer: float = 0.0
var next_action_time: float = 3.0
var animation_timer: float = 0.0
var reaction_timer: float = 0.0

# Speech bubble
var speech_bubble: Node2D = null
var speech_timer: float = 0.0
const SPEECH_DURATION: float = 2.5

# Reaction queue (for handling MCP events)
var reaction_queue: Array = []  # [{type: String, data: Dictionary}, ...]

# Manager phrases
const PATROL_PHRASES = [
	"Checking in...", "All good here.", "Noted.", "Proceeding...",
	"Status: nominal", "Carry on.", "*scribbles*", "Hmm, interesting.",
]

const WEATHER_PHRASES = [
	"Weather update!", "Looks like %s.", "Adjusting conditions...",
	"*looks outside*", "Climate shift...",
]

const DISMISS_PHRASES = [
	"Time's up.", "Wrapping up.", "Completion logged.",
	"Good work.", "Next assignment...",
]

const EVENT_PHRASES = [
	"Event logged.", "*scribbles*", "Recording...", "Noted.",
]

const ENTERING_PHRASES = [
	"MCP Online.", "Manager present.", "Syncing...", "Connected.",
]

const LEAVING_PHRASES = [
	"Signing off.", "MCP Offline.", "Disconnecting...", "Until next time.",
]

# Boundaries
var bounds_min: Vector2 = Vector2(30, 100)
var bounds_max: Vector2 = Vector2(1250, 620)

# Navigation
var navigation_grid: NavigationGrid = null
var path_waypoints: Array[Vector2] = []
var current_waypoint_index: int = 0

# Pathfinding stuck detection
var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
const STUCK_TIMEOUT: float = 2.0
const STUCK_DISTANCE_EPS: float = 1.0
const WALL_MARGIN: float = 20.0

# References
var office_manager: Node = null
var target_agent: Node = null  # Agent being checked/dismissed

# Door position (for entering/leaving)
var door_position: Vector2 = OfficeConstants.DOOR_POSITION
var spawn_point: Vector2 = OfficeConstants.SPAWN_POINT

func _ready() -> void:
	visuals = McpManagerVisuals.new(self)
	visuals.create_visuals()
	visible = false  # Start invisible until activated
	position = spawn_point

func _process(delta: float) -> void:
	if state == State.INACTIVE:
		return

	state_timer += delta
	animation_timer += delta

	match state:
		State.ENTERING:
			_process_entering(delta)
		State.IDLE:
			_process_idle(delta)
		State.PATROLLING:
			_process_patrolling(delta)
		State.CHECKING_AGENT:
			_process_checking_agent(delta)
		State.REACTING:
			_process_reacting(delta)
		State.WALKING_TO:
			_process_walking_to(delta)
		State.LEAVING:
			_process_leaving(delta)

	# Update z-index for proper sorting
	z_index = int(position.y)

	# Process speech bubble
	_process_speech_bubble(delta)

	# Process reaction queue
	_process_reaction_queue()

# =============================================================================
# ACTIVATION / DEACTIVATION
# =============================================================================

func activate() -> void:
	if state != State.INACTIVE:
		return
	visible = true
	position = spawn_point
	state = State.ENTERING
	state_timer = 0.0
	target_position = _find_valid_position()
	_build_path_to(target_position)
	_show_speech(ENTERING_PHRASES[randi() % ENTERING_PHRASES.size()])

func deactivate() -> void:
	if state == State.INACTIVE:
		return
	state = State.LEAVING
	state_timer = 0.0
	target_position = door_position
	_build_path_to(target_position)
	_show_speech(LEAVING_PHRASES[randi() % LEAVING_PHRASES.size()])

# =============================================================================
# STATE PROCESSING
# =============================================================================

func _process_entering(delta: float) -> void:
	_move_along_path(delta)
	visuals.animate_walk(animation_timer)

	if path_waypoints.is_empty() or _reached_destination():
		state = State.IDLE
		state_timer = 0.0
		next_action_time = randf_range(2.0, 4.0)
		visuals.reset_animations()

func _process_idle(delta: float) -> void:
	visuals.animate_idle(animation_timer)

	if state_timer >= next_action_time:
		_pick_next_action()

func _process_patrolling(delta: float) -> void:
	_move_along_path(delta)
	visuals.animate_walk(animation_timer)

	if path_waypoints.is_empty() or _reached_destination():
		# Arrived at patrol destination
		state = State.IDLE
		state_timer = 0.0
		next_action_time = randf_range(2.0, 5.0)
		visuals.reset_animations()
		# Small chance to say something
		if randf() < 0.25:
			_show_speech(PATROL_PHRASES[randi() % PATROL_PHRASES.size()])

func _process_checking_agent(delta: float) -> void:
	visuals.animate_checking(animation_timer)

	if state_timer >= 2.0:
		state = State.IDLE
		state_timer = 0.0
		next_action_time = randf_range(3.0, 6.0)
		target_agent = null
		visuals.reset_animations()

func _process_reacting(delta: float) -> void:
	reaction_timer -= delta

	if reaction_timer <= 0:
		state = State.IDLE
		state_timer = 0.0
		next_action_time = randf_range(2.0, 4.0)
		visuals.reset_animations()

func _process_walking_to(delta: float) -> void:
	_move_along_path(delta)
	visuals.animate_walk(animation_timer)

	if path_waypoints.is_empty() or _reached_destination():
		# Arrived at target
		if target_agent and is_instance_valid(target_agent):
			state = State.CHECKING_AGENT
			state_timer = 0.0
			visuals.reset_animations()
		else:
			state = State.IDLE
			state_timer = 0.0
			next_action_time = randf_range(2.0, 4.0)
			visuals.reset_animations()

func _process_leaving(delta: float) -> void:
	_move_along_path(delta)
	visuals.animate_walk(animation_timer)

	if path_waypoints.is_empty() or position.distance_to(door_position) < 15:
		# Reached door - deactivate
		state = State.INACTIVE
		visible = false
		reaction_queue.clear()
		visuals.reset_animations()

# =============================================================================
# ACTIONS
# =============================================================================

func _pick_next_action() -> void:
	state_timer = 0.0

	var roll = randf()

	if roll < 0.30 and office_manager:
		# Walk to an agent (30%)
		var agents = office_manager.active_agents.values()
		if agents.size() > 0:
			target_agent = agents[randi() % agents.size()]
			if is_instance_valid(target_agent):
				state = State.WALKING_TO
				target_position = target_agent.position + Vector2(randf_range(-30, 30), randf_range(10, 20))
				target_position = _clamp_to_bounds(target_position)
				_build_path_to(target_position)
				return

	if roll < 0.60:
		# Walk to furniture (30%)
		state = State.PATROLLING
		target_position = _pick_furniture_target()
		_build_path_to(target_position)
	else:
		# Walk to random spot (40%)
		state = State.PATROLLING
		target_position = _find_valid_position()
		_build_path_to(target_position)

func _pick_furniture_target() -> Vector2:
	if not office_manager:
		return _find_valid_position()

	var targets: Array[Vector2] = []

	# Add furniture positions
	if office_manager.water_cooler_position != Vector2.ZERO:
		targets.append(office_manager.water_cooler_position + Vector2(0, 25))
	if office_manager.plant_position != Vector2.ZERO:
		targets.append(office_manager.plant_position + Vector2(0, 20))
	if office_manager.filing_cabinet_position != Vector2.ZERO:
		targets.append(office_manager.filing_cabinet_position + Vector2(0, 25))
	if office_manager.shredder_position != Vector2.ZERO:
		targets.append(office_manager.shredder_position + Vector2(0, 20))

	if targets.is_empty():
		return _find_valid_position()

	var target = targets[randi() % targets.size()]
	return _clamp_to_bounds(target)

# =============================================================================
# EVENT REACTIONS (Called by OfficeManager when MCP tools invoked)
# =============================================================================

func on_weather_changed(weather_state: String) -> void:
	if state == State.INACTIVE:
		return
	reaction_queue.append({
		"type": "weather",
		"data": {"state": weather_state}
	})

func on_agent_dismissed(agent_id: String, agent_node: Node) -> void:
	if state == State.INACTIVE:
		return
	reaction_queue.append({
		"type": "dismiss",
		"data": {"agent_id": agent_id, "agent": agent_node}
	})

func on_event_posted(event_data: Dictionary) -> void:
	if state == State.INACTIVE:
		return
	reaction_queue.append({
		"type": "event",
		"data": event_data
	})

func on_cat_petted() -> void:
	if state == State.INACTIVE:
		return
	reaction_queue.append({
		"type": "cat_petted",
		"data": {}
	})

func _process_reaction_queue() -> void:
	if reaction_queue.is_empty():
		return
	if state == State.REACTING or state == State.LEAVING or state == State.ENTERING:
		return

	var reaction = reaction_queue.pop_front()
	_handle_reaction(reaction)

func _handle_reaction(reaction: Dictionary) -> void:
	var type = reaction.get("type", "")
	var data = reaction.get("data", {})

	match type:
		"weather":
			# Look up and show weather bubble
			state = State.REACTING
			reaction_timer = 2.5
			visuals.animate_looking_up(animation_timer)
			var weather = data.get("state", "clear")
			var phrase = WEATHER_PHRASES[randi() % WEATHER_PHRASES.size()]
			if phrase.contains("%s"):
				phrase = phrase % weather
			_show_speech(phrase)

		"dismiss":
			# Walk to agent if still valid, show dismiss phrase
			var agent = data.get("agent", null)
			if agent and is_instance_valid(agent):
				target_agent = agent
				state = State.WALKING_TO
				target_position = agent.position + Vector2(0, 15)
				target_position = _clamp_to_bounds(target_position)
				_build_path_to(target_position)
				_show_speech(DISMISS_PHRASES[randi() % DISMISS_PHRASES.size()])
			else:
				# Agent already gone, just react in place
				state = State.REACTING
				reaction_timer = 1.5
				visuals.animate_scribbling(animation_timer)
				_show_speech("Noted.")

		"event":
			# Scribble on clipboard
			state = State.REACTING
			reaction_timer = 2.0
			visuals.animate_scribbling(animation_timer)
			_show_speech(EVENT_PHRASES[randi() % EVENT_PHRASES.size()])

		"cat_petted":
			# Walk to cat and react
			if office_manager and office_manager.office_cat:
				var cat = office_manager.office_cat
				state = State.WALKING_TO
				target_position = cat.position + Vector2(randf_range(-20, 20), 20)
				target_position = _clamp_to_bounds(target_position)
				_build_path_to(target_position)
				_show_speech("Good kitty!")
			else:
				state = State.REACTING
				reaction_timer = 1.5
				_show_speech("Meow?")

# =============================================================================
# NAVIGATION
# =============================================================================

func _move_along_path(delta: float) -> void:
	if path_waypoints.is_empty() or current_waypoint_index >= path_waypoints.size():
		return

	var current_waypoint = path_waypoints[current_waypoint_index]
	var direction = current_waypoint - position

	# Reached waypoint?
	if direction.length() < 8:
		current_waypoint_index += 1
		if current_waypoint_index >= path_waypoints.size():
			path_waypoints.clear()
			current_waypoint_index = 0
		return

	# Move toward waypoint
	var move_dir = direction.normalized()
	position += move_dir * speed * delta

	# Face direction
	if abs(direction.x) > 1:
		visuals.set_facing(direction.x < 0)

	# Stuck detection
	if position.distance_to(last_position) < STUCK_DISTANCE_EPS:
		stuck_timer += delta
		if stuck_timer >= STUCK_TIMEOUT:
			# Reroute
			target_position = _find_valid_position()
			_build_path_to(target_position)
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	last_position = position

func _build_path_to(destination: Vector2) -> void:
	path_waypoints.clear()
	current_waypoint_index = 0
	stuck_timer = 0.0
	last_position = position

	if navigation_grid:
		var path = navigation_grid.find_path(position, destination)
		if path.size() > 0:
			for point in path:
				path_waypoints.append(point)
			return

	# Fallback: direct path
	path_waypoints.append(destination)

func _reached_destination() -> bool:
	return position.distance_to(target_position) < 15

func _find_valid_position() -> Vector2:
	for _i in range(20):
		var test_pos = Vector2(
			randf_range(bounds_min.x + WALL_MARGIN, bounds_max.x - WALL_MARGIN),
			randf_range(bounds_min.y + WALL_MARGIN, bounds_max.y - WALL_MARGIN)
		)
		if navigation_grid and navigation_grid.is_walkable(test_pos):
			return test_pos

	# Fallback
	return Vector2(200, 400)

func _clamp_to_bounds(pos: Vector2) -> Vector2:
	pos.x = clamp(pos.x, bounds_min.x + WALL_MARGIN, bounds_max.x - WALL_MARGIN)
	pos.y = clamp(pos.y, bounds_min.y + WALL_MARGIN, bounds_max.y - WALL_MARGIN)
	return pos

func set_bounds(min_pos: Vector2, max_pos: Vector2) -> void:
	bounds_min = min_pos
	bounds_max = max_pos

func set_navigation_grid(grid: NavigationGrid) -> void:
	navigation_grid = grid

# =============================================================================
# SPEECH BUBBLES
# =============================================================================

func _show_speech(text: String) -> void:
	if speech_bubble:
		speech_bubble.queue_free()
	speech_bubble = visuals.show_speech_bubble(text)
	speech_timer = SPEECH_DURATION

func _process_speech_bubble(delta: float) -> void:
	if not speech_bubble:
		return

	speech_timer -= delta
	if speech_timer < 0.4:
		speech_bubble.modulate.a = speech_timer / 0.4
	if speech_timer <= 0:
		speech_bubble.queue_free()
		speech_bubble = null

# =============================================================================
# CLEANUP
# =============================================================================

func _exit_tree() -> void:
	if speech_bubble:
		speech_bubble.queue_free()
		speech_bubble = null
	reaction_queue.clear()
