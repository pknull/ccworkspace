extends Node2D
class_name OfficeManager

const AgentScene = preload("res://scenes/Agent.tscn")
const TranscriptWatcherScript = preload("res://scripts/TranscriptWatcher.gd")
const OfficeCatScript = preload("res://scripts/OfficeCat.gd")
const DraggableItemScript = preload("res://scripts/DraggableItem.gd")
const GamificationManagerScript = preload("res://scripts/GamificationManager.gd")
const PauseMenuScript = preload("res://scripts/PauseMenu.gd")
# Note: OfficeConstants, OfficePalette, OfficeVisualFactory are accessed via class_name (no preload needed)

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

# Gamification (achievements only - agent tracking handled by AgentRoster)
var gamification_manager: GamificationManager = null

# Agent Roster (named agents with XP/levels - replaces AgentStable)
var agent_roster: AgentRoster = null
var badge_system: BadgeSystem = null

# Agent tracking (orchestrators are just agents with agent_type="orchestrator")
var active_agents: Dictionary = {}  # agent_id -> Agent
var agent_by_type: Dictionary = {}  # agent_type -> Array of agent_ids
var agents_by_session: Dictionary = {}  # session_id -> [agent_ids]
var completed_count: int = 0

# UI elements
var status_label: Label
var taskboard: Node2D
var session_labels: Dictionary = {}  # session_path -> Label

# Visual elements
var connection_lines: Array[Line2D] = []
var window_clouds: Array = []
var office_cat: Node2D = null

# Wall decorations
var vip_photo: VIPPhoto = null
var roster_clipboard: RosterClipboard = null

# Popups
var roster_popup: RosterPopup = null
var profile_popup: ProfilePopup = null
var achievement_popup: AchievementsListPopup = null
var pause_menu: Node = null  # PauseMenuScript instance

# Spontaneous bubble coordination
var current_spontaneous_agent: Agent = null
var spontaneous_bubble_cooldown: float = 0.0
const GLOBAL_SPONTANEOUS_COOLDOWN: float = 5.0  # Minimum 5s between any spontaneous bubbles (was 8)

# Taskboard update throttling
var taskboard_update_timer: float = 0.0
const TASKBOARD_UPDATE_INTERVAL: float = 0.5  # Update taskboard every 0.5s instead of every frame

# Agent interaction check throttling
var interaction_check_timer: float = 0.0
const INTERACTION_CHECK_INTERVAL: float = 0.5  # Check for agent-agent and agent-cat interactions
const AGENT_CHAT_PROXIMITY: float = 50.0  # How close agents need to be to start chatting
const CAT_INTERACTION_PROXIMITY: float = 40.0  # How close to cat to trigger reaction

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
	# Reset static agent state (prevents stale color mappings on scene reload)
	Agent.reset_color_assignments()

	# Initialize navigation grid
	navigation_grid = NavigationGrid.new()

	# Initialize agent roster (replaces AgentStable)
	agent_roster = AgentRoster.new()
	add_child(agent_roster)
	agent_roster.agent_level_up.connect(_on_agent_level_up)
	agent_roster.roster_changed.connect(_on_roster_changed)

	# Initialize gamification system (achievements only)
	gamification_manager = GamificationManagerScript.new()
	add_child(gamification_manager)
	gamification_manager.set_agent_roster(agent_roster)

	# Initialize badge system
	badge_system = BadgeSystem.new()
	add_child(badge_system)
	badge_system.setup(agent_roster)

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

	# Initialize VIP photo with top agent (if any)
	_update_vip_photo()

	print("[OfficeManager] Ready. Desks: %d" % desks.size())

func _notification(what: int) -> void:
	# Save all data when the game window is closed
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[OfficeManager] Window close requested - saving data")
		_save_positions()
		if agent_roster:
			agent_roster.save_roster()
		if gamification_manager:
			gamification_manager.save_all()
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause_menu()
		# Debug keys (R=roster, P=profile)
		elif event.keycode == KEY_R:
			_show_roster_popup()
		elif event.keycode == KEY_P and agent_roster:
			var top = agent_roster.get_top_agent()
			if top:
				_show_agent_profile(top.id)

func _process(delta: float) -> void:
	# Throttle taskboard updates (doesn't need to run every frame)
	taskboard_update_timer += delta
	if taskboard_update_timer >= TASKBOARD_UPDATE_INTERVAL:
		taskboard_update_timer = 0.0
		_update_taskboard()

	_animate_clouds(delta)
	_update_spontaneous_cooldown(delta)

	# Throttle agent interaction checks (small talk, cat reactions)
	interaction_check_timer += delta
	if interaction_check_timer >= INTERACTION_CHECK_INTERVAL:
		interaction_check_timer = 0.0
		_check_agent_interactions()

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

	# Wall decorations (between windows and title sign)
	vip_photo = OfficeVisualFactory.create_vip_photo()
	add_child(vip_photo)
	vip_photo.clicked.connect(_on_vip_photo_clicked)

	roster_clipboard = OfficeVisualFactory.create_roster_clipboard()
	add_child(roster_clipboard)
	roster_clipboard.setup(agent_roster)
	roster_clipboard.clicked.connect(_on_roster_clipboard_clicked)

	# Taskboard (now draggable)
	draggable_taskboard = OfficeVisualFactory.create_taskboard(DraggableItemScript)
	draggable_taskboard.position = taskboard_position
	draggable_taskboard.position_changed.connect(_on_item_position_changed)
	add_child(draggable_taskboard)
	taskboard = draggable_taskboard  # Keep reference for session labels

	# Status bar
	status_label = OfficeVisualFactory.create_status_bar(self)

	# Reset button and achievement board removed - access via pause menu (Escape key)

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
	office_cat.set_bounds(Vector2(30, 100), Vector2(OfficeConstants.FLOOR_MAX_X - 30, 620))
	_update_cat_obstacles()
	office_cat.z_index = OfficeConstants.Z_CAT
	add_child(office_cat)

func _update_cat_obstacles() -> void:
	if not office_cat:
		return
	office_cat.clear_obstacles()

	# Add desk obstacles
	for desk in desks:
		var rect = Rect2(desk.position - Vector2(50, 40), Vector2(100, 80))
		office_cat.add_obstacle(rect)

	# Add furniture obstacles
	office_cat.add_obstacle(_get_furniture_rect(water_cooler_position, OfficeConstants.WATER_COOLER_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(plant_position, OfficeConstants.PLANT_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(filing_cabinet_position, OfficeConstants.FILING_CABINET_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(shredder_position, OfficeConstants.SHREDDER_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(meeting_table_position, OfficeConstants.MEETING_TABLE_OBSTACLE))

func _get_furniture_rect(pos: Vector2, size: Vector2) -> Rect2:
	return Rect2(pos.x - size.x / 2, pos.y - size.y / 2, size.x, size.y)

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

	# Update cat's obstacles (desks + furniture)
	_update_cat_obstacles()

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
	if OfficeConstants.DEBUG_EVENTS:
		print("[OfficeManager] EVENT: %s | agent_id=%s" % [event_type, event_data.get("agent_id", "?")])
	match event_type:
		"agent_spawn":
			_handle_agent_spawn(event_data)
		"agent_complete":
			if OfficeConstants.DEBUG_EVENTS:
				print("[OfficeManager] → active_agents keys: %s" % str(active_agents.keys()))
			_handle_agent_complete(event_data)
		# Note: "tool_use" events don't exist - tools are tracked in "waiting_for_input"
		"furniture_tour":
			_handle_furniture_tour(event_data)
		"waiting_for_input":
			_handle_waiting_for_input(event_data)
		"input_received":
			_handle_input_received(event_data)

func _handle_session_start(data: Dictionary) -> void:
	var session_id = data.get("session_id", "")
	var session_path = data.get("session_path", "")
	if session_id:
		print("[OfficeManager] Session started: %s" % session_id.substr(0, 8))
		# Spawn orchestrator as a regular agent (they'll stay until session ends)
		var orch_data = {
			"agent_id": "orch_" + session_id.substr(0, 8),
			"agent_type": "orchestrator",
			"description": "Session: " + session_id.substr(0, 8),
			"session_path": session_path,
			"is_orchestrator": true
		}
		_handle_agent_spawn(orch_data)
		_update_taskboard()

func _handle_session_end(data: Dictionary) -> void:
	var session_id = data.get("session_id", "")
	if not session_id:
		return

	# Find the orchestrator for this session (agent_id starts with "orch_")
	var orch_id = "orch_" + session_id.substr(0, 8)
	if active_agents.has(orch_id):
		var orchestrator = active_agents[orch_id] as Agent
		if orchestrator and is_instance_valid(orchestrator):
			print("[OfficeManager] Session ended: %s" % session_id.substr(0, 8))
			# Record orchestrator session completion for XP/stats
			if agent_roster and orchestrator.profile_id >= 0:
				agent_roster.record_orchestrator_session(orchestrator.profile_id)
			# Complete like any other agent (goes to shredder, then leaves)
			orchestrator.force_complete()
	_update_taskboard()

func _handle_session_exit(data: Dictionary) -> void:
	# User ran /exit or /quit - orchestrator should leave the office
	var session_id = data.get("session_id", "")
	if not session_id:
		return

	var orch_id = "orch_" + session_id.substr(0, 8)
	if active_agents.has(orch_id):
		var orchestrator = active_agents[orch_id] as Agent
		if orchestrator and is_instance_valid(orchestrator):
			print("[OfficeManager] Session exit - orchestrator leaving: %s" % session_id.substr(0, 8))
			orchestrator.force_complete()
		_update_taskboard()

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

	# Assign agent profile from roster (orchestrators get the best/highest level agent)
	var is_orchestrator = agent_type == "orchestrator" or data.get("is_orchestrator", false)
	if agent_roster:
		var profile = agent_roster.assign_agent_for_task(is_orchestrator)
		if profile:
			agent.profile_id = profile.id
			# Apply persistent appearance from profile
			agent.apply_profile_appearance(profile)
			# Optionally use the profile's name for display
			if agent.description.is_empty():
				agent.set_description(profile.agent_name)

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
			if agent.state == Agent.State.MEETING:
				if agent.path_waypoints.is_empty():
					# Already at the table - teleport to new position
					agent.position = new_spot
				else:
					# Still walking to table - recalculate path to new destination
					agent._build_path_to(new_spot)

func get_meeting_spot_position(spot_idx: int) -> Vector2:
	# Get meeting spot position adjusted for current table position
	if spot_idx < 0 or spot_idx >= OfficeConstants.MEETING_SPOTS.size():
		return meeting_table_position
	var default_pos = OfficeConstants.MEETING_TABLE_POSITION
	var offset = meeting_table_position - default_pos
	return OfficeConstants.MEETING_SPOTS[spot_idx] + offset

func _handle_agent_complete(data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "")
	var result = data.get("result", "")

	if OfficeConstants.DEBUG_EVENTS:
		print("[OfficeManager] _handle_agent_complete: looking for '%s'" % agent_id)
	if active_agents.has(agent_id):
		var agent = active_agents[agent_id]
		if OfficeConstants.DEBUG_EVENTS:
			print("[OfficeManager] Found agent '%s' in state %s" % [agent_id, Agent.State.keys()[agent.state]])
		if result:
			agent.set_result(result)
		agent.force_complete()
		print("[OfficeManager] Completed agent: %s" % agent_id)
	else:
		# Fallback: complete any active agent
		print("[OfficeManager] Agent '%s' NOT in active_agents, using fallback" % agent_id)
		for aid in active_agents.keys():
			var agent = active_agents[aid] as Agent
			if agent.state != Agent.State.COMPLETING and agent.state != Agent.State.DELIVERING:
				if result:
					agent.set_result(result)
				agent.force_complete()
				print("[OfficeManager] Completed agent (fallback): %s" % aid)
				break

func _handle_waiting_for_input(data: Dictionary) -> void:
	var tool_name = data.get("tool", "")
	var session_path = data.get("session_path", "")
	var session_id = session_path.get_file().get_basename() if session_path else ""

	print("[OfficeManager] Waiting for input: %s (session: %s)" % [tool_name, session_id.substr(0, 8) if session_id else "unknown"])
	status_label.text = "Tool: %s" % tool_name if tool_name else "Waiting..."

	# Find the best agent for this session - prefer working sub-agents over orchestrator
	var target_agent: Agent = _find_working_agent_for_session(session_id)

	if target_agent:
		# Show the tool being used
		if tool_name:
			target_agent.show_tool(tool_name)
		# Track tool usage on agent profile
		if agent_roster and tool_name and target_agent.profile_id >= 0:
			if OfficeConstants.DEBUG_TOOL_TRACKING:
				print("[OfficeManager] TOOL TRACK: '%s' for profile %d" % [tool_name, target_agent.profile_id])
			agent_roster.record_tool_use(target_agent.profile_id, tool_name)
		elif OfficeConstants.DEBUG_TOOL_TRACKING and not target_agent.profile_id >= 0:
			print("[OfficeManager] TOOL TRACK SKIPPED: agent has no profile (id=%d)" % target_agent.profile_id)
		# Turn monitor red (waiting)
		if target_agent.assigned_desk:
			target_agent.assigned_desk.set_monitor_waiting(true)

func _find_working_agent_for_session(session_id: String) -> Agent:
	# Priority 1: Find a working agent belonging to this session (includes orchestrators)
	if session_id and agents_by_session.has(session_id):
		for agent_id in agents_by_session[session_id]:
			if active_agents.has(agent_id):
				var agent = active_agents[agent_id] as Agent
				if agent.state == Agent.State.WORKING and agent.assigned_desk:
					if OfficeConstants.DEBUG_AGENT_LOOKUP:
						print("[OfficeManager] Found agent by session: %s (profile=%d)" % [agent_id, agent.profile_id])
					return agent

	# Priority 2: Any working agent (fallback for unknown sessions)
	for aid in active_agents.keys():
		var agent = active_agents[aid] as Agent
		if agent.state == Agent.State.WORKING and agent.assigned_desk:
			if OfficeConstants.DEBUG_AGENT_LOOKUP:
				print("[OfficeManager] Found agent by fallback: %s (profile=%d, state=%s)" % [aid, agent.profile_id, Agent.State.keys()[agent.state]])
			return agent

	if OfficeConstants.DEBUG_AGENT_LOOKUP:
		print("[OfficeManager] No working agent found for session '%s' (agents_by_session keys: %s, active: %s)" % [session_id.substr(0, 8) if session_id else "?", str(agents_by_session.keys()).substr(0, 50), str(active_agents.size())])
	return null

func _handle_input_received(data: Dictionary) -> void:
	var session_path = data.get("session_path", "")
	var session_id = session_path.get_file().get_basename() if session_path else ""

	print("[OfficeManager] Input received (session: %s)" % [session_id.substr(0, 8) if session_id else "unknown"])
	status_label.text = "Working..."

	# Clear waiting state on all agents belonging to this session
	if session_id and agents_by_session.has(session_id):
		for agent_id in agents_by_session[session_id]:
			if active_agents.has(agent_id):
				var agent = active_agents[agent_id] as Agent
				if agent.assigned_desk:
					agent.assigned_desk.set_monitor_waiting(false)
	else:
		# Unknown session - clear all (fallback)
		for agent in active_agents.values():
			if agent.assigned_desk:
				agent.assigned_desk.set_monitor_waiting(false)

func _handle_furniture_tour(data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "tour_%d" % Time.get_ticks_msec())
	var agent_type = data.get("agent_type", "smoke-test")

	print("[OfficeManager] Starting furniture tour with agent: %s" % agent_id)

	# Create a tour agent at spawn point
	var agent = AgentScene.instantiate() as Agent
	agent.agent_id = agent_id
	agent.agent_type = agent_type
	agent.description = "Furniture Tour"
	agent.set_obstacles(office_obstacles)
	agent.navigation_grid = navigation_grid
	_configure_agent_positions(agent)

	# Set spawn position at door, skip spawn animation
	agent.position = spawn_point
	agent.modulate.a = 1.0  # Fully visible immediately
	agent.state = Agent.State.IDLE

	add_child(agent)
	active_agents[agent_id] = agent

	# Start the tour immediately
	agent.start_furniture_tour(meeting_table_position)

# =============================================================================
# AGENT MANAGEMENT
# =============================================================================

func _check_agent_interactions() -> void:
	# Check for agent-agent small talk opportunities
	_check_agent_small_talk()
	# Check for agent-cat interactions
	_check_agent_cat_interactions()

func _check_agent_small_talk() -> void:
	# Get all agents that can chat
	var chattable_agents: Array[Agent] = []
	for agent_id in active_agents:
		var agent = active_agents[agent_id] as Agent
		if is_instance_valid(agent) and agent.can_chat():
			chattable_agents.append(agent)

	# Check pairs for proximity
	for i in range(chattable_agents.size()):
		for j in range(i + 1, chattable_agents.size()):
			var agent_a = chattable_agents[i]
			var agent_b = chattable_agents[j]

			# Skip if either is already chatting (might have started this frame)
			if agent_a.state == Agent.State.CHATTING or agent_b.state == Agent.State.CHATTING:
				continue

			var distance = agent_a.global_position.distance_to(agent_b.global_position)
			if distance < AGENT_CHAT_PROXIMITY:
				# Start chat between these two agents
				_start_agent_chat(agent_a, agent_b)
				# Only one chat per check to avoid overwhelming
				return

func _start_agent_chat(agent_a: Agent, agent_b: Agent) -> void:
	print("[OfficeManager] Small talk: %s and %s" % [agent_a.agent_id.substr(0, 8), agent_b.agent_id.substr(0, 8)])
	agent_a.start_chat_with(agent_b)
	agent_b.start_chat_with(agent_a)

	# Track chat on agent profiles
	if agent_roster and agent_a.profile_id >= 0 and agent_b.profile_id >= 0:
		agent_roster.record_chat(agent_a.profile_id, agent_b.profile_id)

func _check_agent_cat_interactions() -> void:
	if not is_instance_valid(office_cat):
		return

	var cat_pos = office_cat.global_position

	for agent_id in active_agents:
		var agent = active_agents[agent_id] as Agent
		if not is_instance_valid(agent):
			continue
		if not agent.can_react_to_cat():
			continue

		var distance = agent.global_position.distance_to(cat_pos)
		if distance < CAT_INTERACTION_PROXIMITY:
			# Agent reacts to cat
			agent.react_to_cat()
			# Make the cat meow back sometimes
			if randf() < 0.5 and office_cat.has_method("_show_meow"):
				office_cat._show_meow()

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

	# Record task completion on agent profile (this also triggers roster_changed for achievements)
	if agent_roster and agent.profile_id >= 0:
		agent_roster.record_task_completed(agent.profile_id, agent.agent_type, agent.work_elapsed)
		agent_roster.release_agent(agent.profile_id)

	active_agents.erase(aid)
	if agent_by_type.has(agent.agent_type):
		agent_by_type[agent.agent_type].erase(aid)
	if agent.session_id and agents_by_session.has(agent.session_id):
		agents_by_session[agent.session_id].erase(aid)

	# Release meeting spot if this agent was in a meeting
	_release_meeting_spot(aid)

	# Disconnect signal before freeing to prevent stale callbacks
	if agent.work_completed.is_connected(_on_agent_completed):
		agent.work_completed.disconnect(_on_agent_completed)

	agent.queue_free()

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

	# Update cat obstacles (desks + furniture)
	_update_cat_obstacles()

	# Save positions whenever furniture moves
	_save_positions()

func _update_all_agents_position(item_name: String, new_position: Vector2) -> void:
	var method_name = POSITION_SETTERS.get(item_name, "")
	if method_name.is_empty():
		return

	# Update all agents (orchestrators are now in active_agents)
	for agent in active_agents.values():
		if agent.has_method(method_name):
			agent.call(method_name, new_position)
		# Recalculate path if agent is heading to this furniture
		if agent.has_method("on_furniture_moved"):
			agent.on_furniture_moved(item_name, new_position)

func _update_obstacle(index: int, new_rect: Rect2) -> void:
	if index < office_obstacles.size():
		office_obstacles[index] = new_rect

	# Update all agents (orchestrators are now in active_agents)
	for agent in active_agents.values():
		agent.set_obstacles(office_obstacles)

# =============================================================================
# UI UPDATES
# =============================================================================

func _update_taskboard() -> void:
	if not transcript_watcher or not taskboard:
		return

	var watched = transcript_watcher.watched_sessions
	var y_offset = 28

	# Clear old labels
	var to_remove: Array[String] = []
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
	line.default_color = Agent.get_agent_color(agent_type)
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
	if data.has("meeting_table"):
		meeting_table_position = Vector2(data["meeting_table"]["x"], data["meeting_table"]["y"])

	print("[OfficeManager] Loaded saved furniture positions")

func _save_positions() -> void:
	var data = {
		"water_cooler": {"x": water_cooler_position.x, "y": water_cooler_position.y},
		"plant": {"x": plant_position.x, "y": plant_position.y},
		"filing_cabinet": {"x": filing_cabinet_position.x, "y": filing_cabinet_position.y},
		"shredder": {"x": shredder_position.x, "y": shredder_position.y},
		"taskboard": {"x": taskboard_position.x, "y": taskboard_position.y},
		"meeting_table": {"x": meeting_table_position.x, "y": meeting_table_position.y},
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
	meeting_table_position = DEFAULT_POSITIONS["meeting_table"]

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
	if meeting_table:
		meeting_table.position = meeting_table_position
		_on_item_position_changed("meeting_table", meeting_table_position)

	# Delete saved positions file
	if FileAccess.file_exists(POSITIONS_FILE):
		DirAccess.remove_absolute(POSITIONS_FILE)
		print("[OfficeManager] Removed saved positions file")

# =============================================================================
# GAMIFICATION & ROSTER EVENTS
# =============================================================================

func _on_roster_changed() -> void:
	# Update VIP photo when roster changes (agent hired, stats updated, etc.)
	_update_vip_photo()

func _on_agent_level_up(profile: AgentProfile, new_level: int) -> void:
	print("[OfficeManager] Agent %s leveled up to %d (%s)" % [profile.agent_name, new_level, profile.get_title()])

	# Show level-up popup notification
	var popup = LevelUpPopup.new()
	popup.z_index = OfficeConstants.Z_UI
	add_child(popup)
	popup.setup(profile.agent_name, new_level, profile.get_title())
	popup.popup_finished.connect(func(): popup.queue_free())

	# Update VIP photo if this agent is now the top XP agent
	_update_vip_photo()

func _update_vip_photo() -> void:
	if not vip_photo or not agent_roster:
		return
	var top_agent = agent_roster.get_top_agent()
	vip_photo.update_display(top_agent)

func _on_vip_photo_clicked(agent_id: int) -> void:
	print("[OfficeManager] VIP photo clicked for agent: %d" % agent_id)
	_show_agent_profile(agent_id)

func _on_roster_clipboard_clicked() -> void:
	print("[OfficeManager] Roster clipboard clicked - open full roster")
	_show_roster_popup()

func _show_roster_popup() -> void:
	if roster_popup != null:
		return  # Already showing

	roster_popup = RosterPopup.new()
	add_child(roster_popup)
	roster_popup.show_roster(agent_roster)
	roster_popup.close_requested.connect(_on_roster_popup_closed)
	roster_popup.agent_selected.connect(_on_roster_popup_agent_selected)

func _on_roster_popup_closed() -> void:
	if roster_popup:
		roster_popup.queue_free()
		roster_popup = null

func _on_roster_popup_agent_selected(agent_id: int) -> void:
	_on_roster_popup_closed()
	_show_agent_profile(agent_id)

func _show_agent_profile(agent_id: int) -> void:
	if profile_popup != null:
		return  # Already showing

	if not agent_roster:
		return

	var profile = agent_roster.get_agent(agent_id)
	if not profile:
		return

	profile_popup = ProfilePopup.new()
	add_child(profile_popup)
	profile_popup.setup(agent_roster, badge_system)  # Pass roster for colleague names, badge_system for badge info
	profile_popup.show_profile(profile)
	profile_popup.close_requested.connect(_on_profile_popup_closed)

func _on_profile_popup_closed() -> void:
	if profile_popup:
		profile_popup.queue_free()
		profile_popup = null

func _show_achievement_popup() -> void:
	if achievement_popup != null:
		return  # Already showing

	achievement_popup = AchievementsListPopup.new()
	add_child(achievement_popup)
	achievement_popup.show_achievements(gamification_manager.achievement_system)
	achievement_popup.close_requested.connect(_on_achievement_popup_closed)

func _on_achievement_popup_closed() -> void:
	if achievement_popup:
		achievement_popup.queue_free()
		achievement_popup = null

# =============================================================================
# PAUSE MENU
# =============================================================================

func _toggle_pause_menu() -> void:
	if pause_menu != null:
		_close_pause_menu()
	else:
		_show_pause_menu()

func _show_pause_menu() -> void:
	if pause_menu != null:
		return

	pause_menu = PauseMenuScript.new()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_on_pause_resume)
	pause_menu.roster_requested.connect(_on_pause_roster)
	pause_menu.reset_layout_requested.connect(_on_pause_reset_layout)
	pause_menu.achievements_requested.connect(_on_pause_achievements)
	pause_menu.quit_requested.connect(_on_pause_quit)

func _close_pause_menu() -> void:
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null

func _on_pause_resume() -> void:
	_close_pause_menu()

func _on_pause_roster() -> void:
	_close_pause_menu()
	_show_roster_popup()

func _on_pause_reset_layout() -> void:
	_close_pause_menu()
	_on_reset_button_pressed()

func _on_pause_achievements() -> void:
	_close_pause_menu()
	_show_achievement_popup()

func _on_pause_quit() -> void:
	# Save data before quitting
	_save_positions()
	if agent_roster:
		agent_roster.save_roster()
	if gamification_manager:
		gamification_manager.save_all()
	get_tree().quit()

