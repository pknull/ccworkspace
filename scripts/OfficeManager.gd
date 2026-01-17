extends Node2D
class_name OfficeManager

const AgentScene = preload("res://scenes/Agent.tscn")
const TranscriptWatcherScript = preload("res://scripts/TranscriptWatcher.gd")
const OfficeCatScript = preload("res://scripts/OfficeCat.gd")
const DraggableItemScript = preload("res://scripts/DraggableItem.gd")
const OfficeConstantsScript = preload("res://scripts/OfficeConstants.gd")
const OfficePaletteScript = preload("res://scripts/OfficePalette.gd")
const OfficeVisualFactoryScript = preload("res://scripts/OfficeVisualFactory.gd")

@export var spawn_point: Vector2 = OfficeConstants.SPAWN_POINT

# Office furniture and layout
var desks: Array[Desk] = []
var water_cooler_position: Vector2 = OfficeConstants.WATER_COOLER_POSITION
var plant_position: Vector2 = OfficeConstants.PLANT_POSITION
var filing_cabinet_position: Vector2 = OfficeConstants.FILING_CABINET_POSITION
var door_position: Vector2 = OfficeConstants.DOOR_POSITION
var shredder_position: Vector2 = OfficeConstants.SHREDDER_POSITION
var taskboard_position: Vector2 = OfficeConstants.TASKBOARD_POSITION
var meeting_table_position: Vector2 = OfficeConstants.MEETING_TABLE_POSITION

# Meeting table overflow tracking
var meeting_table: Node2D = null
var meeting_spots_occupied: Array[bool] = []  # Track which spots are taken
var agents_in_meeting: Dictionary = {}  # agent_id -> spot_index

# Draggable furniture references
var draggable_water_cooler: Node2D = null
var draggable_plant: Node2D = null
var draggable_filing_cabinet: Node2D = null
var draggable_shredder: Node2D = null
var draggable_taskboard: Node2D = null

# Position persistence
const POSITIONS_FILE: String = "user://furniture_positions.json"
var reset_button: Button = null

# Agent tracking
var active_agents: Dictionary = {}  # agent_id -> Agent
var agent_by_type: Dictionary = {}  # agent_type -> Array of agent_ids
var agents_by_session: Dictionary = {}  # session_id -> [agent_ids]
var session_orchestrators: Dictionary = {}  # session_id -> Agent
var idle_orchestrators: Array[Agent] = []
var completed_count: int = 0

# UI elements
var status_label: Label
var taskboard: Node2D
var session_labels: Dictionary = {}  # session_path -> Label

# Visual elements
var connection_lines: Array[Line2D] = []
var window_clouds: Array = []
var office_cat: Node2D = null

# Spontaneous bubble coordination
var current_spontaneous_agent: Agent = null
var spontaneous_bubble_cooldown: float = 0.0
const GLOBAL_SPONTANEOUS_COOLDOWN: float = 5.0  # Minimum 5s between any spontaneous bubbles (was 8)

# Obstacles for agent pathfinding (legacy - kept for cat)
var office_obstacles: Array[Rect2] = []

# Grid-based navigation system
var navigation_grid: NavigationGrid = null

# Event sources
@onready var event_server: EventServer = $EventServer
var transcript_watcher: Node = null

# Table mapping item names to position setter method names
const POSITION_SETTERS = {
	"water_cooler": "set_water_cooler_position",
	"plant": "set_plant_position",
	"filing_cabinet": "set_filing_cabinet_position",
	"shredder": "set_shredder_position",
	"meeting_table": "set_meeting_table_position",
}

# Default positions for reset
const DEFAULT_POSITIONS = {
	"water_cooler": OfficeConstants.WATER_COOLER_POSITION,
	"plant": OfficeConstants.PLANT_POSITION,
	"filing_cabinet": OfficeConstants.FILING_CABINET_POSITION,
	"shredder": OfficeConstants.SHREDDER_POSITION,
	"taskboard": OfficeConstants.TASKBOARD_POSITION,
	"meeting_table": OfficeConstants.MEETING_TABLE_POSITION,
}

func _ready() -> void:
	# Initialize navigation grid
	navigation_grid = NavigationGrid.new()

	# Load saved positions before creating furniture
	_load_positions()

	_setup_office()
	_create_desks()
	_create_furniture()
	_create_office_cat()

	# Register desks and furniture with navigation grid
	_register_with_navigation_grid()

	# Connect event sources
	event_server.event_received.connect(_on_event_received)
	transcript_watcher = TranscriptWatcherScript.new()
	add_child(transcript_watcher)
	transcript_watcher.event_received.connect(_on_event_received)

	navigation_grid.print_grid_summary()
	print("[OfficeManager] Ready. Desks: %d" % desks.size())

func _process(delta: float) -> void:
	_update_taskboard()
	_animate_clouds(delta)
	_update_spontaneous_cooldown(delta)

# =============================================================================
# OFFICE SETUP - Uses OfficeVisualFactory
# =============================================================================

func _setup_office() -> void:
	# Floor and walls
	OfficeVisualFactory.create_floor(self)
	OfficeVisualFactory.create_walls(self)

	# Windows
	var window_positions = [140, 380, 900, 1140]
	for wx in window_positions:
		OfficeVisualFactory.create_window(self, wx, window_clouds)

	# Door
	OfficeVisualFactory.create_door(self, Vector2(640, 632))

	# Title sign
	OfficeVisualFactory.create_title_sign(self)

	# Taskboard (now draggable)
	draggable_taskboard = OfficeVisualFactory.create_taskboard(DraggableItemScript)
	draggable_taskboard.position = taskboard_position
	draggable_taskboard.position_changed.connect(_on_item_position_changed)
	add_child(draggable_taskboard)
	taskboard = draggable_taskboard  # Keep reference for session labels

	# Status bar
	status_label = OfficeVisualFactory.create_status_bar(self)

	# Reset button
	reset_button = OfficeVisualFactory.create_reset_button()
	reset_button.pressed.connect(_on_reset_button_pressed)
	add_child(reset_button)

func _create_furniture() -> void:
	# Water cooler
	draggable_water_cooler = OfficeVisualFactory.create_water_cooler(DraggableItemScript)
	draggable_water_cooler.position = water_cooler_position
	draggable_water_cooler.navigation_grid = navigation_grid
	draggable_water_cooler.obstacle_size = OfficeConstants.WATER_COOLER_OBSTACLE
	draggable_water_cooler.position_changed.connect(_on_item_position_changed)
	add_child(draggable_water_cooler)
	office_obstacles.append(Rect2(water_cooler_position.x - 20, water_cooler_position.y - 40, 40, 60))

	# Plant
	draggable_plant = OfficeVisualFactory.create_potted_plant(DraggableItemScript)
	draggable_plant.position = plant_position
	draggable_plant.navigation_grid = navigation_grid
	draggable_plant.obstacle_size = OfficeConstants.PLANT_OBSTACLE
	draggable_plant.position_changed.connect(_on_item_position_changed)
	add_child(draggable_plant)
	office_obstacles.append(Rect2(plant_position.x - 20, plant_position.y - 20, 40, 50))

	# Filing cabinet
	draggable_filing_cabinet = OfficeVisualFactory.create_filing_cabinet(DraggableItemScript)
	draggable_filing_cabinet.position = filing_cabinet_position
	draggable_filing_cabinet.navigation_grid = navigation_grid
	draggable_filing_cabinet.obstacle_size = OfficeConstants.FILING_CABINET_OBSTACLE
	draggable_filing_cabinet.position_changed.connect(_on_item_position_changed)
	add_child(draggable_filing_cabinet)
	office_obstacles.append(Rect2(filing_cabinet_position.x - 20, filing_cabinet_position.y - 30, 40, 80))

	# Shredder
	draggable_shredder = OfficeVisualFactory.create_shredder(DraggableItemScript)
	draggable_shredder.position = shredder_position
	draggable_shredder.navigation_grid = navigation_grid
	draggable_shredder.obstacle_size = OfficeConstants.SHREDDER_OBSTACLE
	draggable_shredder.position_changed.connect(_on_item_position_changed)
	add_child(draggable_shredder)
	office_obstacles.append(Rect2(shredder_position.x - 15, shredder_position.y - 20, 30, 40))

	# Meeting table (overflow area - draggable)
	meeting_table = OfficeVisualFactory.create_meeting_table(DraggableItemScript)
	meeting_table.position = meeting_table_position
	meeting_table.navigation_grid = navigation_grid
	meeting_table.obstacle_size = OfficeConstants.MEETING_TABLE_OBSTACLE
	meeting_table.position_changed.connect(_on_item_position_changed)
	add_child(meeting_table)
	# Register as obstacle
	var table_size = OfficeConstants.MEETING_TABLE_OBSTACLE
	office_obstacles.append(Rect2(meeting_table_position.x - table_size.x / 2, meeting_table_position.y - table_size.y / 2, table_size.x, table_size.y))
	# Initialize meeting spots (8 spots around the table)
	meeting_spots_occupied.resize(OfficeConstants.MEETING_SPOTS.size())
	meeting_spots_occupied.fill(false)

func _create_desks() -> void:
	var desk_x_positions = OfficeConstants.DESK_POSITIONS_X
	var desk_y_positions = [
		OfficeConstants.ROW1_DESK_Y,
		OfficeConstants.ROW2_DESK_Y,
		OfficeConstants.ROW3_DESK_Y,
		OfficeConstants.ROW4_DESK_Y,
	]

	var desk_positions: Array[Vector2] = []
	for y in desk_y_positions:
		for x in desk_x_positions:
			desk_positions.append(Vector2(x, y))

	for pos in desk_positions:
		var desk = Desk.new()
		desk.position = pos
		desk.navigation_grid = navigation_grid
		desk.position_changed.connect(_on_desk_position_changed)
		add_child(desk)
		desks.append(desk)

func _create_office_cat() -> void:
	office_cat = OfficeCatScript.new()
	office_cat.set_bounds(Vector2(30, 100), Vector2(780, 620))
	var desk_positions_array = []
	for desk in desks:
		desk_positions_array.append(desk.position)
	office_cat.set_desk_positions(desk_positions_array)
	office_cat.z_index = OfficeConstants.Z_CAT
	add_child(office_cat)

func _register_with_navigation_grid() -> void:
	# Register desks - each desk blocks cells and has a work position
	for desk in desks:
		var desk_rect = Rect2(
			desk.position.x - OfficeConstants.DESK_WIDTH / 2,
			desk.position.y,
			OfficeConstants.DESK_WIDTH,
			OfficeConstants.DESK_DEPTH
		)
		navigation_grid.register_obstacle(desk_rect, "desk_%d" % desk.get_instance_id())
		# Work position is in front of the desk
		var work_pos = desk.get_work_position()
		navigation_grid.register_work_position(work_pos, desk)

	# Register furniture
	_register_furniture_obstacle("water_cooler", water_cooler_position, OfficeConstants.WATER_COOLER_OBSTACLE)
	_register_furniture_obstacle("plant", plant_position, OfficeConstants.PLANT_OBSTACLE)
	_register_furniture_obstacle("filing_cabinet", filing_cabinet_position, OfficeConstants.FILING_CABINET_OBSTACLE)
	_register_furniture_obstacle("shredder", shredder_position, OfficeConstants.SHREDDER_OBSTACLE)
	_register_furniture_obstacle("meeting_table", meeting_table_position, OfficeConstants.MEETING_TABLE_OBSTACLE)

func _register_furniture_obstacle(obstacle_id: String, pos: Vector2, size: Vector2) -> void:
	var rect = Rect2(pos.x - size.x / 2, pos.y - size.y / 2, size.x, size.y)
	navigation_grid.register_obstacle(rect, obstacle_id)

func _on_desk_position_changed(desk: Desk, new_position: Vector2) -> void:
	print("[OfficeManager] Desk moved to %s" % new_position)

	# Update navigation grid - remove old position, add new
	var desk_id = "desk_%d" % desk.get_instance_id()
	navigation_grid.unregister_obstacle(desk_id)
	navigation_grid.unregister_work_position(desk)

	# Register at new position
	var desk_rect = Rect2(
		new_position.x - OfficeConstants.DESK_WIDTH / 2,
		new_position.y,
		OfficeConstants.DESK_WIDTH,
		OfficeConstants.DESK_DEPTH
	)
	navigation_grid.register_obstacle(desk_rect, desk_id)
	navigation_grid.register_work_position(desk.get_work_position(), desk)

	# Update cat's desk positions
	if office_cat and office_cat.has_method("set_desk_positions"):
		var desk_positions_for_cat = []
		for d in desks:
			desk_positions_for_cat.append(d.global_position)
		office_cat.set_desk_positions(desk_positions_for_cat)

# =============================================================================
# ANIMATION
# =============================================================================

func _animate_clouds(delta: float) -> void:
	for data in window_clouds:
		var cloud = data["cloud"] as ColorRect
		if not is_instance_valid(cloud):
			continue
		cloud.position.x += data["speed"] * delta
		if cloud.position.x > 40:
			cloud.position.x = -40 - cloud.size.x

# =============================================================================
# SPONTANEOUS BUBBLE COORDINATION
# =============================================================================

func _update_spontaneous_cooldown(delta: float) -> void:
	if spontaneous_bubble_cooldown > 0:
		spontaneous_bubble_cooldown -= delta
	# Clear stale reference
	if current_spontaneous_agent and not is_instance_valid(current_spontaneous_agent):
		current_spontaneous_agent = null

func can_show_spontaneous_bubble() -> bool:
	# Only allow one spontaneous bubble at a time, with global cooldown
	if spontaneous_bubble_cooldown > 0:
		return false
	if current_spontaneous_agent and is_instance_valid(current_spontaneous_agent):
		if current_spontaneous_agent.reaction_timer > 0:
			return false
	return true

func register_spontaneous_bubble(agent: Agent) -> void:
	# Clear previous bubble if still showing
	if current_spontaneous_agent and is_instance_valid(current_spontaneous_agent):
		if current_spontaneous_agent != agent:
			current_spontaneous_agent.clear_spontaneous_bubble()
	current_spontaneous_agent = agent
	spontaneous_bubble_cooldown = GLOBAL_SPONTANEOUS_COOLDOWN

# =============================================================================
# EVENT HANDLING
# =============================================================================

func _on_event_received(event_data: Dictionary) -> void:
	var event_type = event_data.get("event", "")

	# Session lifecycle
	if event_type == "session_start":
		_handle_session_start(event_data)
		return
	if event_type == "session_end":
		_handle_session_end(event_data)
		return
	if event_type == "session_exit":
		_handle_session_exit(event_data)
		return

	# Update status
	var tool_name = event_data.get("tool", "")
	status_label.text = "Tool: %s" % tool_name if tool_name else "Event: %s" % event_type

	# Route to handler
	match event_type:
		"agent_spawn":
			_handle_agent_spawn(event_data)
		"agent_complete":
			_handle_agent_complete(event_data)
		"tool_use":
			_handle_tool_use(event_data)

func _handle_session_start(data: Dictionary) -> void:
	var session_id = data.get("session_id", "")
	var session_path = data.get("session_path", "")
	if session_id:
		print("[OfficeManager] Session started: %s" % session_id.substr(0, 8))
		_get_or_create_session_orchestrator(session_id, session_path)
		_update_taskboard()

func _handle_session_end(data: Dictionary) -> void:
	var session_id = data.get("session_id", "")
	if session_id and session_orchestrators.has(session_id):
		var orchestrator = session_orchestrators[session_id] as Agent
		session_orchestrators.erase(session_id)
		if orchestrator and is_instance_valid(orchestrator):
			print("[OfficeManager] Session ended: %s" % session_id.substr(0, 8))
			_send_orchestrator_to_cooler(orchestrator)
		_update_taskboard()

func _handle_session_exit(data: Dictionary) -> void:
	# User ran /exit or /quit - orchestrator should leave the office
	var session_id = data.get("session_id", "")
	if session_id and session_orchestrators.has(session_id):
		var orchestrator = session_orchestrators[session_id] as Agent
		session_orchestrators.erase(session_id)
		if orchestrator and is_instance_valid(orchestrator):
			print("[OfficeManager] Session exit (/exit or /quit): %s" % session_id.substr(0, 8))
			_make_orchestrator_leave(orchestrator)
		_update_taskboard()
	# Also remove from idle orchestrators if present
	for i in range(idle_orchestrators.size() - 1, -1, -1):
		var orch = idle_orchestrators[i]
		if orch.session_id == session_id:
			idle_orchestrators.remove_at(i)
			if is_instance_valid(orch):
				_make_orchestrator_leave(orch)

func _make_orchestrator_leave(orchestrator: Agent) -> void:
	# Free up desk if occupied
	if orchestrator.assigned_desk:
		orchestrator.assigned_desk.set_occupied(false)
		orchestrator.assigned_desk = null
	# Make orchestrator walk to the door and exit
	orchestrator.set_door_position(spawn_point)
	if orchestrator.has_method("start_leaving"):
		orchestrator.start_leaving()
	else:
		# Fallback: directly set leaving state
		orchestrator.state = Agent.State.LEAVING
		orchestrator._build_path_to(spawn_point)

func _handle_agent_spawn(data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "agent_%d" % Time.get_ticks_msec())
	var parent_id = data.get("parent_id", "main")
	var agent_type = data.get("agent_type", "default")
	var description = data.get("description", "")
	var session_path = data.get("session_path", "")
	var session_id = session_path.get_file().get_basename() if session_path else "unknown"

	print("[OfficeManager] Spawning agent: %s (%s)" % [agent_type, agent_id])

	# Try to find a desk first
	var desk = _find_available_desk()
	var meeting_spot_idx = -1

	if desk == null:
		# No desk - try meeting table overflow
		meeting_spot_idx = _find_available_meeting_spot()
		if meeting_spot_idx == -1:
			push_warning("No available desks or meeting spots!")
			return
		print("[OfficeManager] No desk available, using meeting table spot %d" % meeting_spot_idx)

	# Track by session
	if not agents_by_session.has(session_id):
		agents_by_session[session_id] = []
	agents_by_session[session_id].append(agent_id)

	# All agents spawn at the door and walk in
	var spawn_pos = spawn_point

	# Create and configure agent
	var agent = AgentScene.instantiate() as Agent
	agent.agent_id = agent_id
	agent.parent_id = parent_id
	agent.agent_type = agent_type
	agent.session_id = session_id
	agent.position = spawn_pos
	agent.set_description(description)
	_configure_agent_positions(agent)
	agent.set_obstacles(office_obstacles)
	agent.navigation_grid = navigation_grid  # Use grid-based pathfinding
	agent.office_manager = self  # For spontaneous bubble coordination
	agent.work_completed.connect(_on_agent_completed)
	add_child(agent)

	if desk != null:
		# Normal desk assignment
		agent.assign_desk(desk)
		_draw_spawn_connection(spawn_pos, desk.get_work_position(), agent_type)
	else:
		# Meeting table overflow
		var meeting_spot = get_meeting_spot_position(meeting_spot_idx)
		meeting_spots_occupied[meeting_spot_idx] = true
		agents_in_meeting[agent_id] = meeting_spot_idx
		agent.start_meeting(meeting_spot)
		_draw_spawn_connection(spawn_pos, meeting_spot, agent_type)

	# Track agent
	active_agents[agent_id] = agent
	if not agent_by_type.has(agent_type):
		agent_by_type[agent_type] = []
	agent_by_type[agent_type].append(agent_id)

	# Visual feedback
	status_label.text = "Spawned: %s" % agent_type

func _find_available_meeting_spot() -> int:
	for i in range(meeting_spots_occupied.size()):
		if not meeting_spots_occupied[i]:
			return i
	return -1

func _release_meeting_spot(agent_id: String) -> void:
	if agents_in_meeting.has(agent_id):
		var spot_idx = agents_in_meeting[agent_id]
		if spot_idx >= 0 and spot_idx < meeting_spots_occupied.size():
			meeting_spots_occupied[spot_idx] = false
		agents_in_meeting.erase(agent_id)

func _update_meeting_spots() -> void:
	# Recalculate meeting spot positions based on current table position
	# The spots are defined relative to the default table position
	var default_pos = OfficeConstants.MEETING_TABLE_POSITION
	var offset = meeting_table_position - default_pos

	# Update any agents currently in meeting with new positions
	for agent_id in agents_in_meeting.keys():
		var spot_idx = agents_in_meeting[agent_id]
		if active_agents.has(agent_id):
			var agent = active_agents[agent_id]
			var new_spot = get_meeting_spot_position(spot_idx)
			agent.meeting_spot = new_spot
			# If they're standing at the table, move them
			if agent.state == Agent.State.MEETING and agent.path_waypoints.is_empty():
				agent.position = new_spot

func get_meeting_spot_position(spot_idx: int) -> Vector2:
	# Get meeting spot position adjusted for current table position
	if spot_idx < 0 or spot_idx >= OfficeConstants.MEETING_SPOTS.size():
		return meeting_table_position
	var default_pos = OfficeConstants.MEETING_TABLE_POSITION
	var offset = meeting_table_position - default_pos
	return OfficeConstants.MEETING_SPOTS[spot_idx] + offset

func _handle_agent_complete(data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "")

	if active_agents.has(agent_id):
		active_agents[agent_id].force_complete()
		print("[OfficeManager] Completed agent: %s" % agent_id)
	else:
		# Fallback: complete any active agent
		print("[OfficeManager] Agent %s not found, using fallback" % agent_id)
		for aid in active_agents.keys():
			var agent = active_agents[aid] as Agent
			if agent.state != Agent.State.COMPLETING and agent.state != Agent.State.DELIVERING:
				agent.force_complete()
				print("[OfficeManager] Completed agent (fallback): %s" % aid)
				break

func _handle_tool_use(data: Dictionary) -> void:
	var tool_name = data.get("tool", "")
	var agent_id = data.get("agent_id", "main")
	var session_path = data.get("session_path", "")
	var session_id = session_path.get_file().get_basename() if session_path else ""

	if active_agents.has(agent_id):
		active_agents[agent_id].show_tool(tool_name)
	elif session_id and session_orchestrators.has(session_id):
		session_orchestrators[session_id].show_tool(tool_name)
	else:
		# Fallback: show on first working agent
		for aid in active_agents.keys():
			var agent = active_agents[aid] as Agent
			if agent.state == Agent.State.WORKING:
				agent.show_tool(tool_name)
				break

# =============================================================================
# AGENT MANAGEMENT
# =============================================================================

func _get_or_create_session_orchestrator(session_id: String, _session_path: String) -> Agent:
	if session_orchestrators.has(session_id):
		return session_orchestrators[session_id]

	# Reuse idle orchestrator if available
	if not idle_orchestrators.is_empty():
		var orchestrator = idle_orchestrators.pop_back()
		if is_instance_valid(orchestrator):
			var desk = _find_available_desk()
			if desk:
				orchestrator.agent_id = "orch_" + session_id.substr(0, 8)
				orchestrator.session_id = session_id
				orchestrator.description = "Session: " + session_id.substr(0, 8)
				orchestrator.assign_desk(desk)
				orchestrator.start_walking_to_desk()  # This builds the path
				session_orchestrators[session_id] = orchestrator
				print("[OfficeManager] Reusing idle orchestrator: %s" % session_id.substr(0, 8))
				return orchestrator

	var desk = _find_available_desk()
	if desk == null:
		push_warning("No desk available for session orchestrator!")
		return null

	var orchestrator = AgentScene.instantiate() as Agent
	orchestrator.agent_type = "orchestrator"
	orchestrator.agent_id = "orch_" + session_id.substr(0, 8)
	orchestrator.session_id = session_id
	orchestrator.description = "Session: " + session_id.substr(0, 8)
	orchestrator.position = spawn_point
	_configure_agent_positions(orchestrator)
	orchestrator.set_obstacles(office_obstacles)
	orchestrator.navigation_grid = navigation_grid  # Use grid-based pathfinding
	orchestrator.office_manager = self  # For spontaneous bubble coordination
	orchestrator.assign_desk(desk)
	orchestrator.is_waiting_for_completion = false
	orchestrator.min_work_time = 999999
	orchestrator.work_completed.connect(_on_orchestrator_completed)
	add_child(orchestrator)

	session_orchestrators[session_id] = orchestrator
	print("[OfficeManager] Created session orchestrator: %s" % session_id.substr(0, 8))
	return orchestrator

func _send_orchestrator_to_cooler(orchestrator: Agent) -> void:
	if orchestrator.assigned_desk:
		orchestrator.assigned_desk.set_occupied(false)
		orchestrator.assigned_desk = null
	orchestrator.state = Agent.State.IDLE
	orchestrator.position = water_cooler_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
	idle_orchestrators.append(orchestrator)

func _configure_agent_positions(agent: Agent) -> void:
	agent.set_shredder_position(shredder_position)
	agent.set_water_cooler_position(water_cooler_position)
	agent.set_plant_position(plant_position)
	agent.set_filing_cabinet_position(filing_cabinet_position)

func _find_available_desk() -> Desk:
	for desk in desks:
		if desk.is_available():
			return desk
	return null

func _on_agent_completed(agent: Agent) -> void:
	completed_count += 1
	var aid = agent.agent_id

	active_agents.erase(aid)
	if agent_by_type.has(agent.agent_type):
		agent_by_type[agent.agent_type].erase(aid)
	if agent.session_id and agents_by_session.has(agent.session_id):
		agents_by_session[agent.session_id].erase(aid)

	# Release meeting spot if this agent was in a meeting
	_release_meeting_spot(aid)

	agent.queue_free()

func _on_orchestrator_completed(orchestrator: Agent) -> void:
	# Orchestrator has finished leaving (walked out the door)
	print("[OfficeManager] Orchestrator left: %s" % orchestrator.agent_id)

	# Clean up from tracking
	if orchestrator.session_id and session_orchestrators.has(orchestrator.session_id):
		session_orchestrators.erase(orchestrator.session_id)

	# Remove from idle list if present
	idle_orchestrators.erase(orchestrator)

	orchestrator.queue_free()
	_update_taskboard()

# =============================================================================
# FURNITURE POSITION UPDATES
# =============================================================================

func _on_item_position_changed(item_name: String, new_position: Vector2) -> void:
	print("[OfficeManager] %s moved to %s" % [item_name, new_position])

	# Get obstacle size for this item
	var obstacle_size: Vector2 = Vector2.ZERO
	match item_name:
		"water_cooler":
			water_cooler_position = new_position
			obstacle_size = OfficeConstants.WATER_COOLER_OBSTACLE
			_update_obstacle(0, Rect2(new_position.x - 20, new_position.y - 40, 40, 60))
		"plant":
			plant_position = new_position
			obstacle_size = OfficeConstants.PLANT_OBSTACLE
			_update_obstacle(1, Rect2(new_position.x - 20, new_position.y - 20, 40, 50))
		"filing_cabinet":
			filing_cabinet_position = new_position
			obstacle_size = OfficeConstants.FILING_CABINET_OBSTACLE
			_update_obstacle(2, Rect2(new_position.x - 20, new_position.y - 30, 40, 80))
		"shredder":
			shredder_position = new_position
			obstacle_size = OfficeConstants.SHREDDER_OBSTACLE
			_update_obstacle(3, Rect2(new_position.x - 15, new_position.y - 20, 30, 40))
		"meeting_table":
			meeting_table_position = new_position
			obstacle_size = OfficeConstants.MEETING_TABLE_OBSTACLE
			var ts = OfficeConstants.MEETING_TABLE_OBSTACLE
			_update_obstacle(4, Rect2(new_position.x - ts.x / 2, new_position.y - ts.y / 2, ts.x, ts.y))
			# Update meeting spots relative to new table position
			_update_meeting_spots()
		"taskboard":
			taskboard_position = new_position
			# Taskboard is on the wall, no floor navigation impact

	# Update navigation grid (skip for taskboard which is on the wall)
	if navigation_grid and obstacle_size != Vector2.ZERO:
		var new_rect = Rect2(new_position.x - obstacle_size.x / 2, new_position.y - obstacle_size.y / 2, obstacle_size.x, obstacle_size.y)
		navigation_grid.update_obstacle(item_name, new_rect)

	_update_all_agents_position(item_name, new_position)

	# Update cat obstacles
	if office_cat and office_cat.has_method("set_desk_positions"):
		var desk_positions_for_cat = []
		for desk in desks:
			desk_positions_for_cat.append(desk.global_position)
		office_cat.set_desk_positions(desk_positions_for_cat)

	# Save positions whenever furniture moves
	_save_positions()

func _update_all_agents_position(item_name: String, new_position: Vector2) -> void:
	var method_name = POSITION_SETTERS.get(item_name, "")
	if method_name.is_empty():
		return

	for agent in active_agents.values():
		if agent.has_method(method_name):
			agent.call(method_name, new_position)

	for orch in session_orchestrators.values():
		if orch.has_method(method_name):
			orch.call(method_name, new_position)

func _update_obstacle(index: int, new_rect: Rect2) -> void:
	if index < office_obstacles.size():
		office_obstacles[index] = new_rect

	for agent in active_agents.values():
		agent.set_obstacles(office_obstacles)
	for orch in session_orchestrators.values():
		orch.set_obstacles(office_obstacles)

# =============================================================================
# UI UPDATES
# =============================================================================

func _update_taskboard() -> void:
	if not transcript_watcher:
		return

	var watched = transcript_watcher.watched_sessions
	var y_offset = 28

	# Clear old labels
	var to_remove = []
	for path in session_labels.keys():
		if not watched.has(path):
			session_labels[path].queue_free()
			to_remove.append(path)
	for path in to_remove:
		session_labels.erase(path)

	# Update/create labels (max 8)
	var count = 0
	for path in watched.keys():
		if count >= 8:
			break
		var session_id = path.get_file().get_basename()
		var agent_count = agents_by_session.get(session_id, []).size()
		var text = "• %s [%d]" % [session_id.substr(0, 8), agent_count]

		if session_labels.has(path):
			session_labels[path].text = text
			session_labels[path].position = Vector2(10, y_offset)
		else:
			var label = Label.new()
			label.text = text
			label.position = Vector2(10, y_offset)
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
			taskboard.add_child(label)
			session_labels[path] = label

		y_offset += 12
		count += 1

func _draw_spawn_connection(from_pos: Vector2, to_pos: Vector2, agent_type: String) -> void:
	var line = Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 2.0
	line.default_color = Agent.AGENT_COLORS.get(agent_type, Color(0.5, 0.5, 0.5))
	line.default_color.a = 0.5
	add_child(line)
	connection_lines.append(line)

	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func():
		line.queue_free()
		connection_lines.erase(line)
	)

# =============================================================================
# POSITION PERSISTENCE
# =============================================================================

func _load_positions() -> void:
	if not FileAccess.file_exists(POSITIONS_FILE):
		print("[OfficeManager] No saved positions found, using defaults")
		return

	var file = FileAccess.open(POSITIONS_FILE, FileAccess.READ)
	if file == null:
		push_warning("Failed to open positions file: %s" % FileAccess.get_open_error())
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_warning("Failed to parse positions JSON: %s" % json.get_error_message())
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Positions file has invalid format")
		return

	# Apply saved positions
	if data.has("water_cooler"):
		water_cooler_position = Vector2(data["water_cooler"]["x"], data["water_cooler"]["y"])
	if data.has("plant"):
		plant_position = Vector2(data["plant"]["x"], data["plant"]["y"])
	if data.has("filing_cabinet"):
		filing_cabinet_position = Vector2(data["filing_cabinet"]["x"], data["filing_cabinet"]["y"])
	if data.has("shredder"):
		shredder_position = Vector2(data["shredder"]["x"], data["shredder"]["y"])
	if data.has("taskboard"):
		taskboard_position = Vector2(data["taskboard"]["x"], data["taskboard"]["y"])

	print("[OfficeManager] Loaded saved furniture positions")

func _save_positions() -> void:
	var data = {
		"water_cooler": {"x": water_cooler_position.x, "y": water_cooler_position.y},
		"plant": {"x": plant_position.x, "y": plant_position.y},
		"filing_cabinet": {"x": filing_cabinet_position.x, "y": filing_cabinet_position.y},
		"shredder": {"x": shredder_position.x, "y": shredder_position.y},
		"taskboard": {"x": taskboard_position.x, "y": taskboard_position.y},
	}

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(POSITIONS_FILE, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to save positions: %s" % FileAccess.get_open_error())
		return

	file.store_string(json_string)
	file.close()
	print("[OfficeManager] Saved furniture positions")

func _on_reset_button_pressed() -> void:
	print("[OfficeManager] Resetting furniture positions to defaults")

	# Reset all positions to defaults
	water_cooler_position = DEFAULT_POSITIONS["water_cooler"]
	plant_position = DEFAULT_POSITIONS["plant"]
	filing_cabinet_position = DEFAULT_POSITIONS["filing_cabinet"]
	shredder_position = DEFAULT_POSITIONS["shredder"]
	taskboard_position = DEFAULT_POSITIONS["taskboard"]

	# Update draggable furniture positions
	if draggable_water_cooler:
		draggable_water_cooler.position = water_cooler_position
		_on_item_position_changed("water_cooler", water_cooler_position)
	if draggable_plant:
		draggable_plant.position = plant_position
		_on_item_position_changed("plant", plant_position)
	if draggable_filing_cabinet:
		draggable_filing_cabinet.position = filing_cabinet_position
		_on_item_position_changed("filing_cabinet", filing_cabinet_position)
	if draggable_shredder:
		draggable_shredder.position = shredder_position
		_on_item_position_changed("shredder", shredder_position)
	if draggable_taskboard:
		draggable_taskboard.position = taskboard_position

	# Delete saved positions file
	if FileAccess.file_exists(POSITIONS_FILE):
		DirAccess.remove_absolute(POSITIONS_FILE)
		print("[OfficeManager] Removed saved positions file")
