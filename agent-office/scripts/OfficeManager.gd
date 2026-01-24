extends Node2D
class_name OfficeManager

const AgentScene = preload("res://scenes/Agent.tscn")
const TranscriptWatcherScript = preload("res://scripts/TranscriptWatcher.gd")
const OfficeCatScript = preload("res://scripts/OfficeCat.gd")
const DraggableItemScript = preload("res://scripts/DraggableItem.gd")
const GamificationManagerScript = preload("res://scripts/GamificationManager.gd")
const PauseMenuScript = preload("res://scripts/PauseMenu.gd")
const WatcherConfigPopupScript = preload("res://scripts/WatcherConfigPopup.gd")
const AudioManagerScript = preload("res://scripts/AudioManager.gd")
const WallClockScript = preload("res://scripts/WallClock.gd")
const DebugEventLogScript = preload("res://scripts/DebugEventLog.gd")
const WeatherServiceScript = preload("res://scripts/WeatherService.gd")
const VolumeSettingsPopupScript = preload("res://scripts/VolumeSettingsPopup.gd")
const WeatherSettingsPopupScript = preload("res://scripts/WeatherSettingsPopup.gd")
const McpManagerScript = preload("res://scripts/McpManager.gd")
# Note: OfficeConstants, OfficePalette, OfficeVisualFactory are accessed via class_name (no preload needed)

@export var spawn_point: Vector2 = OfficeConstants.SPAWN_POINT

# Office furniture and layout
var desks: Array = []  # Array of FurnitureDesk (was Desk)
var water_cooler_position: Vector2 = OfficeConstants.WATER_COOLER_POSITION
var plant_position: Vector2 = OfficeConstants.PLANT_POSITION
var filing_cabinet_position: Vector2 = OfficeConstants.FILING_CABINET_POSITION
var door_position: Vector2 = OfficeConstants.DOOR_POSITION
var shredder_position: Vector2 = OfficeConstants.SHREDDER_POSITION
var taskboard_position: Vector2 = OfficeConstants.TASKBOARD_POSITION
var meeting_table_position: Vector2 = OfficeConstants.MEETING_TABLE_POSITION
var cat_bed_position: Vector2 = OfficeConstants.CAT_BED_POSITION

# Meeting table overflow tracking
var meeting_table: Node2D = null
var meeting_spots_occupied: Array[bool] = []  # Track which spots are taken
var agents_in_meeting: Dictionary = {}  # agent_id -> spot_index

# Interaction points - standing positions at furniture
# furniture_name -> Array[bool] (true = occupied)
var interaction_points_occupied: Dictionary = {}
# agent_id -> { "furniture": String, "point_idx": int }
var agents_at_interaction_points: Dictionary = {}

# Draggable furniture references
var draggable_water_cooler: Node2D = null
var draggable_plant: Node2D = null
var draggable_filing_cabinet: Node2D = null
var draggable_shredder: Node2D = null
var draggable_taskboard: Node2D = null
var draggable_cat_bed: Node2D = null

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
var known_agent_ids: Dictionary = {}  # agent_id -> true
var completed_agent_ids: Dictionary = {}  # agent_id -> true

# UI elements
var status_label: Label
var taskboard: Node2D
var taskboard_labels: Dictionary = {}  # key -> Label
var profiler_label: Label
var profiler_enabled: bool = false
var profiler_update_timer: float = 0.0
var debug_overlay_enabled: bool = false

# Visual elements
var connection_lines: Array[Line2D] = []
var window_clouds: Array = []
var cloud_layer: Node2D = null
var window_skies: Array = []  # Sky ColorRects for day/night cycle
var celestial_layer: Node2D = null  # Sun/moon layer
var ambient_overlay: ColorRect = null  # Lighting overlay for day/night
var weather_system: WeatherSystem = null  # Rain/snow particles
var office_cat: Node2D = null
var mcp_manager: Node2D = null  # McpManager instance
var mcp_activity_timer: float = 0.0  # Time since last MCP activity
const MCP_IDLE_TIMEOUT: float = 30.0  # Manager leaves after 30s of no MCP activity

# Wall decorations
var vip_photo: VIPPhoto = null
var roster_clipboard: RosterClipboard = null
var wall_clock = null  # WallClock instance
var temperature_display = null
var weather_service = null
var weather_smoke_timer: Timer = null
var weather_smoke_active: bool = false
var weather_smoke_loop: bool = true
var weather_smoke_states: Array[int] = []
var weather_smoke_index: int = 0
const WEATHER_SMOKE_DEFAULT_INTERVAL: float = 4.0

# Popups
var roster_popup: RosterPopup = null
var profile_popup: ProfilePopup = null
var achievement_popup: AchievementsListPopup = null
var pause_menu: Node = null  # PauseMenuScript instance
var event_log: Node = null  # DebugEventLogScript instance
var watcher_config_popup: Node = null
var furniture_shelf_popup: FurnitureShelfPopup = null
var volume_settings_popup: Node = null
var weather_settings_popup: Node = null

# Dynamic furniture tracking (beyond defaults)
var placed_furniture: Array = []  # [{id: String, type: String, position: Vector2, node: Node2D}, ...]
var furniture_id_counter: int = 0
var removed_default_furniture: Array[String] = []  # IDs of removed default furniture
var pending_dynamic_furniture: Array = []  # Loaded from save, created after defaults

# Trait-based furniture system (new)
var furniture_registry: FurnitureRegistry = null
var trait_furniture: Array = []  # Array of FurnitureBase instances

# Spontaneous bubble coordination
var current_spontaneous_agent: Agent = null
var spontaneous_bubble_cooldown: float = 0.0
const GLOBAL_SPONTANEOUS_COOLDOWN: float = 5.0  # Minimum 5s between any spontaneous bubbles (was 8)

# Audio
var audio_manager = null  # AudioManager instance

# Taskboard update throttling
var taskboard_update_timer: float = 0.0
const TASKBOARD_UPDATE_INTERVAL: float = 0.5  # Update taskboard every 0.5s instead of every frame

# Auto-save safety
var autosave_timer: float = 0.0
var is_quitting: bool = false

# Agent interaction check throttling
var interaction_check_timer: float = 0.0
const INTERACTION_CHECK_INTERVAL: float = 0.5  # Check for agent-agent and agent-cat interactions
const AGENT_CHAT_PROXIMITY: float = 80.0  # How close agents need to be to start chatting
const CAT_INTERACTION_PROXIMITY: float = 40.0  # How close to cat to trigger reaction
const PROFILER_UPDATE_INTERVAL: float = 0.5  # Update profiler every 0.5s
const AUTO_SAVE_INTERVAL: float = 60.0  # Periodic safety save

# Obstacles for agent pathfinding (legacy - kept for cat)
var office_obstacles: Array[Rect2] = []

# Grid-based navigation system
var navigation_grid: NavigationGrid = null

# Event sources
@onready var mcp_server: McpServer = $McpServer
var transcript_watcher: Node = null

# Table mapping item names to position setter method names
const POSITION_SETTERS = {
	"water_cooler": "set_water_cooler_position",
	"plant": "set_plant_position",
	"filing_cabinet": "set_filing_cabinet_position",
	"shredder": "set_shredder_position",
	"taskboard": "set_taskboard_position",
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
	"cat_bed": OfficeConstants.CAT_BED_POSITION,
}

func _ready() -> void:
	# Reset static agent state (prevents stale color mappings on scene reload)
	Agent.reset_color_assignments()

	# Initialize navigation grid
	navigation_grid = NavigationGrid.new()

	# Initialize furniture registry
	furniture_registry = FurnitureRegistry.new()
	furniture_registry.navigation_grid = navigation_grid

	# Initialize agent roster (replaces AgentStable)
	agent_roster = AgentRoster.new()
	add_child(agent_roster)
	agent_roster.agent_level_up.connect(_on_agent_level_up)
	agent_roster.roster_changed.connect(_on_roster_changed)

	# Initialize gamification system (achievements only)
	gamification_manager = GamificationManagerScript.new()
	add_child(gamification_manager)
	gamification_manager.set_agent_roster(agent_roster)

	# Initialize audio manager
	audio_manager = AudioManagerScript.new()
	add_child(audio_manager)
	gamification_manager.audio_manager = audio_manager

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
	_create_mcp_manager()
	_init_interaction_points()

	# Register desks and furniture with navigation grid
	_register_with_navigation_grid()

	# Connect event sources
	transcript_watcher = TranscriptWatcherScript.new()
	add_child(transcript_watcher)
	transcript_watcher.event_received.connect(_on_event_received)
	if mcp_server:
		mcp_server.set_office_manager(self)
		mcp_server.event_received.connect(_on_event_received)
		mcp_server.client_connected.connect(_on_mcp_client_connected)
		mcp_server.client_disconnected.connect(_on_mcp_client_disconnected)
		mcp_server.tool_called.connect(_on_mcp_tool_called)

	navigation_grid.print_grid_summary()

	# Initialize VIP photo with top agent (if any)
	_update_vip_photo()

	print("[OfficeManager] Ready. Desks: %d" % desks.size())

func _notification(what: int) -> void:
	# Save all data when the game window is closed
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()

func _request_quit() -> void:
	if is_quitting:
		return
	is_quitting = true
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
		# Keyboard shortcuts (R=roster, P=profile, F=furniture)
		elif event.keycode == KEY_R:
			_show_roster_popup()
		elif event.keycode == KEY_F:
			_show_furniture_shelf()
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
		_update_day_night_cycle()  # Check time changes (throttled with taskboard)

	_animate_clouds(delta)
	_update_spontaneous_cooldown(delta)

	# Throttle agent interaction checks (small talk, cat reactions)
	interaction_check_timer += delta
	if interaction_check_timer >= INTERACTION_CHECK_INTERVAL:
		interaction_check_timer = 0.0
		_check_agent_interactions()

	# Auto-save safety
	autosave_timer += delta
	if autosave_timer >= AUTO_SAVE_INTERVAL:
		autosave_timer = 0.0
		_perform_autosave()

	# Check if MCP manager should leave due to inactivity
	_check_mcp_manager_timeout(delta)

	# Profiler overlay updates
	if profiler_enabled:
		profiler_update_timer += delta
		if profiler_update_timer >= PROFILER_UPDATE_INTERVAL:
			profiler_update_timer = 0.0
			_update_profiler_overlay()

	# Debug: show agent paths and interaction points
	if OfficeConstants.DEBUG_INTERACTION_POINTS or debug_overlay_enabled:
		_update_debug_visualizations()
	elif debug_layer:
		# Clear debug layer when disabled
		for child in debug_layer.get_children():
			child.queue_free()

# =============================================================================
# OFFICE SETUP - Uses OfficeVisualFactory
# =============================================================================

func _setup_office() -> void:
	var window_positions = [140, 380, 900, 1140]

	# Floor (bottom layer)
	OfficeVisualFactory.create_floor(self)

	# Sky layers (behind wall, visible through window holes)
	OfficeVisualFactory.create_sky_layer(self, window_skies)
	celestial_layer = OfficeVisualFactory.create_celestial_layer(self)
	cloud_layer = OfficeVisualFactory.create_cloud_layer(self, window_clouds)
	weather_system = OfficeVisualFactory.create_weather_system()
	add_child(weather_system)
	OfficeVisualFactory.create_foliage_layer(self)

	# Walls (with transparent holes where windows are)
	OfficeVisualFactory.create_walls(self, window_positions)

	# Window frames (around the holes)
	for wx in window_positions:
		OfficeVisualFactory.create_window_frame(self, wx)

	# Ambient lighting overlay (for day/night cycle)
	ambient_overlay = ColorRect.new()
	ambient_overlay.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	ambient_overlay.position = Vector2.ZERO
	ambient_overlay.color = OfficePalette.AMBIENT_DAY
	ambient_overlay.z_index = OfficeConstants.Z_AMBIENT_OVERLAY
	ambient_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Click-through
	add_child(ambient_overlay)

	# Door
	OfficeVisualFactory.create_door(self, Vector2(640, 632))

	# Title sign
	OfficeVisualFactory.create_title_sign(self)

	# Wall decorations (between windows and title sign)
	temperature_display = OfficeVisualFactory.create_temperature_display()
	temperature_display.position = OfficeConstants.TEMPERATURE_DISPLAY_POSITION
	add_child(temperature_display)

	wall_clock = OfficeVisualFactory.create_wall_clock()
	wall_clock.position = OfficeConstants.WALL_CLOCK_POSITION
	add_child(wall_clock)

	vip_photo = OfficeVisualFactory.create_vip_photo()
	add_child(vip_photo)
	vip_photo.clicked.connect(_on_vip_photo_clicked)

	roster_clipboard = OfficeVisualFactory.create_roster_clipboard()
	add_child(roster_clipboard)
	roster_clipboard.setup(agent_roster)
	roster_clipboard.clicked.connect(_on_roster_clipboard_clicked)

	weather_service = WeatherServiceScript.new()
	weather_service.configure(weather_system, temperature_display)
	weather_service.weather_updated.connect(_on_weather_updated)
	add_child(weather_service)

	# Taskboard (now draggable, using new furniture system)
	if not "taskboard" in removed_default_furniture:
		draggable_taskboard = _spawn_default_furniture("taskboard", taskboard_position)
		taskboard = draggable_taskboard  # Keep reference for session labels

	# Status bar
	status_label = OfficeVisualFactory.create_status_bar(self)
	_create_profiler_overlay()

	# Reset button and achievement board removed - access via pause menu (Escape key)

func _create_furniture() -> void:
	# Create furniture using new trait-based system
	# Old variable references kept for backward compatibility

	# Water cooler
	if not "water_cooler" in removed_default_furniture:
		draggable_water_cooler = _spawn_default_furniture("water_cooler", water_cooler_position)

	# Plant
	if not "plant" in removed_default_furniture:
		draggable_plant = _spawn_default_furniture("plant", plant_position)

	# Filing cabinet
	if not "filing_cabinet" in removed_default_furniture:
		draggable_filing_cabinet = _spawn_default_furniture("filing_cabinet", filing_cabinet_position)

	# Shredder
	if not "shredder" in removed_default_furniture:
		draggable_shredder = _spawn_default_furniture("shredder", shredder_position)

	# Meeting table (overflow area)
	if not "meeting_table" in removed_default_furniture:
		meeting_table = _spawn_default_furniture("meeting_table", meeting_table_position)

	# Cat bed
	if not "cat_bed" in removed_default_furniture:
		draggable_cat_bed = _spawn_default_furniture("cat_bed", cat_bed_position)

	# Initialize meeting spots (8 spots around the table)
	meeting_spots_occupied.resize(OfficeConstants.MEETING_SPOT_OFFSETS.size())
	meeting_spots_occupied.fill(false)

	# Create any pending dynamic furniture from save file
	_create_pending_dynamic_furniture()

func _spawn_default_furniture(furniture_type: String, pos: Vector2) -> FurnitureBase:
	## Spawn furniture using the new trait-based system and register it.
	var furniture := furniture_registry.spawn(furniture_type, pos)
	if not furniture:
		push_warning("Failed to spawn default furniture: %s" % furniture_type)
		return null

	# Set up common properties
	furniture.furniture_id = furniture_type  # Default furniture uses type as ID
	furniture.position_changed.connect(_on_item_position_changed)
	add_child(furniture)

	# Register with trait system
	register_trait_furniture(furniture)

	# Add to obstacles for legacy pathfinding
	var obs_size := furniture.obstacle_size
	office_obstacles.append(Rect2(
		pos.x - obs_size.x / 2,
		pos.y - obs_size.y / 2,
		obs_size.x,
		obs_size.y
	))

	return furniture

func _create_pending_dynamic_furniture() -> void:
	for item in pending_dynamic_furniture:
		var fid = item.get("id", "")
		var ftype = item.get("type", "")
		var pos = item.get("position", Vector2.ZERO)
		if fid.is_empty() or ftype.is_empty():
			continue
		# Extract the counter from the ID to ensure we don't reuse it
		if fid.begins_with("furniture_"):
			var num_str = fid.substr(10)
			var num = int(num_str)
			if num >= furniture_id_counter:
				furniture_id_counter = num + 1
		_add_furniture_with_id(ftype, pos, fid)
	pending_dynamic_furniture.clear()

func _add_furniture_with_id(furniture_type: String, pos: Vector2, fid: String) -> void:
	# Map legacy type names to registry names
	var registry_type := furniture_type
	if furniture_type == "potted_plant":
		registry_type = "plant"

	var furniture: FurnitureBase = furniture_registry.spawn_with_id(registry_type, pos, fid)
	if not furniture:
		push_warning("[OfficeManager] Failed to spawn furniture: %s" % furniture_type)
		return

	furniture.navigation_grid = navigation_grid
	furniture.office_manager = self
	furniture.position_changed.connect(_on_dynamic_furniture_moved.bind(fid))
	add_child(furniture)

	# Register with trait system
	register_trait_furniture(furniture)

	placed_furniture.append({
		"id": fid,
		"type": furniture_type,  # Keep original type for save/load compatibility
		"position": pos,
		"node": furniture,
		"obstacle_size": furniture.obstacle_size
	})

	# Register obstacle with navigation grid
	var obstacle_rect = Rect2(pos - furniture.obstacle_size / 2, furniture.obstacle_size)
	navigation_grid.register_obstacle(obstacle_rect, fid)

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

	var desk_index := 0
	for pos in desk_positions:
		var desk := furniture_registry.spawn("desk", pos) as FurnitureDesk
		if not desk:
			push_warning("Failed to spawn desk at %s" % pos)
			continue

		desk.furniture_id = "desk_%d" % desk_index
		desk.navigation_grid = navigation_grid
		desk.office_manager = self
		desk.position_changed.connect(_on_desk_position_changed)
		add_child(desk)

		# Register with both old and new systems for backward compatibility
		desks.append(desk)
		register_trait_furniture(desk)

		desk_index += 1

func _create_office_cat() -> void:
	office_cat = OfficeCatScript.new()
	office_cat.set_bounds(Vector2(30, 100), Vector2(OfficeConstants.FLOOR_MAX_X - 30, 620))
	if office_cat.has_method("set_cat_bed_position"):
		office_cat.set_cat_bed_position(cat_bed_position)
	if office_cat.has_method("set_navigation_grid"):
		office_cat.set_navigation_grid(navigation_grid)
	office_cat.audio_manager = audio_manager
	_update_cat_obstacles()
	office_cat.z_index = OfficeConstants.Z_CAT
	add_child(office_cat)
	# Connect cat petted signal for MCP petting
	if office_cat.has_signal("cat_petted"):
		office_cat.cat_petted.connect(_on_cat_petted)

func _create_mcp_manager() -> void:
	mcp_manager = McpManagerScript.new()
	mcp_manager.set_bounds(Vector2(30, 100), Vector2(OfficeConstants.FLOOR_MAX_X - 30, 620))
	mcp_manager.set_navigation_grid(navigation_grid)
	mcp_manager.office_manager = self
	add_child(mcp_manager)

func _on_cat_petted() -> void:
	# Record cat interaction for achievements
	if gamification_manager:
		gamification_manager.record_cat_interaction()

func _on_mcp_client_connected(_peer_id: int) -> void:
	# Reset activity timer on any MCP connection
	mcp_activity_timer = 0.0
	# Activate manager if not already active
	if mcp_manager and mcp_manager.state == mcp_manager.State.INACTIVE:
		mcp_manager.activate()

func _on_mcp_client_disconnected(_peer_id: int) -> void:
	# Don't deactivate immediately - HTTP connections are short-lived
	# Manager will deactivate via timeout in _process if no activity
	pass

func _check_mcp_manager_timeout(delta: float) -> void:
	if not mcp_manager:
		return
	if mcp_manager.state == mcp_manager.State.INACTIVE:
		return

	mcp_activity_timer += delta
	if mcp_activity_timer >= MCP_IDLE_TIMEOUT:
		mcp_manager.deactivate()
		mcp_activity_timer = 0.0

func _on_mcp_tool_called(tool_name: String, args: Dictionary) -> void:
	# Reset activity timer on any tool call
	mcp_activity_timer = 0.0

	if not mcp_manager:
		return
	# Route specific tool calls to manager for reactions
	match tool_name:
		"set_weather":
			var state = str(args.get("state", "clear"))
			mcp_manager.on_weather_changed(state)
		"post_event":
			mcp_manager.on_event_posted(args)
		"pet_cat":
			mcp_manager.on_cat_petted()
		# dismiss_agent is handled in _handle_agent_complete

func _update_cat_obstacles() -> void:
	if not office_cat:
		return
	office_cat.clear_obstacles()

	# Add desk obstacles (same dimensions as navigation grid)
	for desk in desks:
		var desk_rect = Rect2(
			desk.position.x - OfficeConstants.DESK_WIDTH / 2,
			desk.position.y,
			OfficeConstants.DESK_WIDTH,
			OfficeConstants.DESK_DEPTH
		)
		office_cat.add_obstacle(desk_rect)

	# Add furniture obstacles (same as navigation grid registrations)
	office_cat.add_obstacle(_get_furniture_rect(water_cooler_position, OfficeConstants.WATER_COOLER_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(plant_position, OfficeConstants.PLANT_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(filing_cabinet_position, OfficeConstants.FILING_CABINET_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(shredder_position, OfficeConstants.SHREDDER_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(meeting_table_position, OfficeConstants.MEETING_TABLE_OBSTACLE))
	office_cat.add_obstacle(_get_furniture_rect(cat_bed_position, OfficeConstants.CAT_BED_OBSTACLE))

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
	_register_furniture_obstacle("cat_bed", cat_bed_position, OfficeConstants.CAT_BED_OBSTACLE)

func _register_furniture_obstacle(obstacle_id: String, pos: Vector2, size: Vector2) -> void:
	var rect = Rect2(pos.x - size.x / 2, pos.y - size.y / 2, size.x, size.y)
	navigation_grid.register_obstacle(rect, obstacle_id)

# =============================================================================
# INTERACTION POINTS - Standing positions at furniture
# =============================================================================

func _init_interaction_points() -> void:
	# Initialize occupancy tracking for each furniture type
	interaction_points_occupied["water_cooler"] = []
	interaction_points_occupied["water_cooler"].resize(OfficeConstants.WATER_COOLER_POINTS.size())
	interaction_points_occupied["water_cooler"].fill(false)

	interaction_points_occupied["plant"] = []
	interaction_points_occupied["plant"].resize(OfficeConstants.PLANT_POINTS.size())
	interaction_points_occupied["plant"].fill(false)

	interaction_points_occupied["filing_cabinet"] = []
	interaction_points_occupied["filing_cabinet"].resize(OfficeConstants.FILING_CABINET_POINTS.size())
	interaction_points_occupied["filing_cabinet"].fill(false)

	interaction_points_occupied["shredder"] = []
	interaction_points_occupied["shredder"].resize(OfficeConstants.SHREDDER_POINTS.size())
	interaction_points_occupied["shredder"].fill(false)

	interaction_points_occupied["taskboard"] = []
	interaction_points_occupied["taskboard"].resize(OfficeConstants.TASKBOARD_POINTS.size())
	interaction_points_occupied["taskboard"].fill(false)

	# Debug markers are now drawn in _process to track furniture movement

var debug_layer: Node2D = null

func _update_debug_visualizations() -> void:
	"""Draw debug markers for interaction points, desk positions, and agent paths."""
	# Clear and recreate debug layer each frame
	if debug_layer:
		for child in debug_layer.get_children():
			child.queue_free()
	else:
		debug_layer = Node2D.new()
		debug_layer.name = "DebugLayer"
		debug_layer.z_index = OfficeConstants.Z_UI - 1
		add_child(debug_layer)

	# Screen bounds for offscreen check
	var screen_rect = Rect2(0, 0, OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)

	# === OBSTACLE BOUNDING BOXES ===
	for obstacle in office_obstacles:
		var obs_rect = ColorRect.new()
		obs_rect.size = obstacle.size
		obs_rect.position = obstacle.position
		obs_rect.color = Color(1.0, 0.0, 0.0, 0.15)  # Semi-transparent red
		obs_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		debug_layer.add_child(obs_rect)

		# Border outline
		var border = Line2D.new()
		border.add_point(obstacle.position)
		border.add_point(obstacle.position + Vector2(obstacle.size.x, 0))
		border.add_point(obstacle.position + obstacle.size)
		border.add_point(obstacle.position + Vector2(0, obstacle.size.y))
		border.add_point(obstacle.position)
		border.width = 1.0
		border.default_color = Color(1.0, 0.3, 0.3, 0.4)
		debug_layer.add_child(border)

	# === FURNITURE INTERACTION POINTS ===
	# Use actual draggable node positions (not the position variables which may be stale)
	var furniture_points = {
		"water_cooler": {"node": draggable_water_cooler, "points": OfficeConstants.WATER_COOLER_POINTS, "color": Color.CYAN},
		"plant": {"node": draggable_plant, "points": OfficeConstants.PLANT_POINTS, "color": Color.GREEN},
		"filing_cabinet": {"node": draggable_filing_cabinet, "points": OfficeConstants.FILING_CABINET_POINTS, "color": Color.GRAY},
		"shredder": {"node": draggable_shredder, "points": OfficeConstants.SHREDDER_POINTS, "color": Color.RED},
		"taskboard": {"node": draggable_taskboard, "points": OfficeConstants.TASKBOARD_POINTS, "color": Color.YELLOW},
	}

	for furniture_name in furniture_points:
		var data = furniture_points[furniture_name]
		var node = data["node"]
		if not node:
			continue
		var base_pos: Vector2 = node.position
		var points: Array = data["points"]
		var point_color: Color = data["color"]

		# Draw line from furniture center to each point
		for i in range(points.size()):
			var offset: Vector2 = points[i]
			var world_pos: Vector2 = base_pos + offset

			# Check if endpoint is offscreen or collides with obstacle
			var is_problem = _debug_point_has_problem(world_pos, screen_rect)
			var alpha = 0.1 if is_problem else 0.5

			# Connector line
			var line = Line2D.new()
			line.add_point(base_pos)
			line.add_point(world_pos)
			line.width = 1.0 if not is_problem else 2.0
			line.default_color = point_color if not is_problem else Color.RED
			line.default_color.a = alpha
			debug_layer.add_child(line)

			# Marker at standing position
			var marker = ColorRect.new()
			marker.size = Vector2(8, 8)
			marker.position = world_pos - Vector2(4, 4)
			marker.color = point_color if not is_problem else Color.RED
			marker.color.a = 0.7 if not is_problem else 0.3
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			debug_layer.add_child(marker)

			# Label
			var label = Label.new()
			label.text = "%s[%d]%s" % [furniture_name.substr(0, 3), i, "!" if is_problem else ""]
			label.position = world_pos + Vector2(5, -5)
			label.add_theme_font_size_override("font_size", 8)
			label.add_theme_color_override("font_color", Color.RED if is_problem else point_color)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			debug_layer.add_child(label)

	# === MEETING SPOTS ===
	# Use actual meeting table node position + relative offsets
	var mtg_base = meeting_table.position if meeting_table else meeting_table_position
	for i in range(OfficeConstants.MEETING_SPOT_OFFSETS.size()):
		var offset: Vector2 = OfficeConstants.MEETING_SPOT_OFFSETS[i]
		var spot: Vector2 = mtg_base + offset

		var is_problem = _debug_point_has_problem(spot, screen_rect)
		var alpha = 0.1 if is_problem else 0.5

		# Line from meeting table center
		var line = Line2D.new()
		line.add_point(mtg_base)
		line.add_point(spot)
		line.width = 1.0 if not is_problem else 2.0
		line.default_color = Color.MAGENTA if not is_problem else Color.RED
		line.default_color.a = alpha
		debug_layer.add_child(line)

		var marker = ColorRect.new()
		marker.size = Vector2(8, 8)
		marker.position = spot - Vector2(4, 4)
		marker.color = Color.MAGENTA if not is_problem else Color.RED
		marker.color.a = 0.7 if not is_problem else 0.3
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		debug_layer.add_child(marker)

		var label = Label.new()
		label.text = "mtg[%d]%s" % [i, "!" if is_problem else ""]
		label.position = spot + Vector2(5, -5)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color.RED if is_problem else Color.MAGENTA)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		debug_layer.add_child(label)

	# === DESK WORK POSITIONS ===
	for i in range(desks.size()):
		var desk: FurnitureDesk = desks[i]
		var desk_pos = desk.position
		var work_pos = desk.get_work_position()

		var is_problem = _debug_point_has_problem(work_pos, screen_rect)
		var alpha = 0.1 if is_problem else 0.3

		# Line from desk to work position
		var line = Line2D.new()
		line.add_point(desk_pos)
		line.add_point(work_pos)
		line.width = 1.0
		line.default_color = Color.WHITE if not is_problem else Color.RED
		line.default_color.a = alpha
		debug_layer.add_child(line)

		var marker = ColorRect.new()
		marker.size = Vector2(6, 6)
		marker.position = work_pos - Vector2(3, 3)
		marker.color = Color.WHITE if not is_problem else Color.RED
		marker.color.a = 0.5 if not is_problem else 0.3
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		debug_layer.add_child(marker)

	# Draw agent and cat paths
	_draw_debug_paths()

func _debug_point_has_problem(pos: Vector2, screen_rect: Rect2) -> bool:
	"""Check if a standing position is offscreen or inside an obstacle."""
	# Offscreen check
	if not screen_rect.has_point(pos):
		return true
	# Obstacle collision check
	for obstacle in office_obstacles:
		if obstacle.has_point(pos):
			return true
	return false

func _draw_debug_paths() -> void:
	"""Draw agent and cat pathfinding lines."""
	if not debug_layer:
		return

	# === AGENT PATHS ===
	for agent_id in active_agents:
		var agent: Agent = active_agents[agent_id]
		if agent and agent.path_waypoints.size() > 0:
			var line = Line2D.new()
			line.width = 2.0
			line.default_color = Agent.get_agent_color(agent.agent_type)
			line.default_color.a = 0.4

			line.add_point(agent.position)
			for j in range(agent.current_waypoint_index, agent.path_waypoints.size()):
				line.add_point(agent.path_waypoints[j])
			debug_layer.add_child(line)

	# === CAT PATH ===
	if office_cat and office_cat.path_waypoints.size() > 0:
		var cat_line = Line2D.new()
		cat_line.width = 2.0
		cat_line.default_color = Color.ORANGE
		cat_line.default_color.a = 0.4

		cat_line.add_point(office_cat.position)
		for j in range(office_cat.current_waypoint_index, office_cat.path_waypoints.size()):
			cat_line.add_point(office_cat.path_waypoints[j])
		debug_layer.add_child(cat_line)

func reserve_interaction_point(furniture_name: String, agent_id: String) -> int:
	"""Reserve an available interaction point at furniture. Returns point index, or -1 if all occupied."""
	if not interaction_points_occupied.has(furniture_name):
		return -1

	var points: Array = interaction_points_occupied[furniture_name]
	for i in range(points.size()):
		if not points[i]:
			points[i] = true
			agents_at_interaction_points[agent_id] = {
				"furniture": furniture_name,
				"point_idx": i
			}
			return i

	# All points occupied
	return -1

func release_interaction_point(agent_id: String) -> void:
	"""Release any interaction point held by this agent."""
	if not agents_at_interaction_points.has(agent_id):
		return

	var info: Dictionary = agents_at_interaction_points[agent_id]
	var furniture_name: String = info["furniture"]
	var point_idx: int = info["point_idx"]

	if interaction_points_occupied.has(furniture_name):
		var points: Array = interaction_points_occupied[furniture_name]
		if point_idx >= 0 and point_idx < points.size():
			points[point_idx] = false

	agents_at_interaction_points.erase(agent_id)

func get_interaction_point_position(furniture_name: String, point_idx: int) -> Vector2:
	"""Get world position for interaction point (furniture position + offset)."""
	var base_position: Vector2 = _get_furniture_position(furniture_name)
	var offset: Vector2 = _get_interaction_point_offset(furniture_name, point_idx)
	return base_position + offset

func has_available_interaction_point(furniture_name: String) -> bool:
	"""Check if any interaction point is available at furniture."""
	if not interaction_points_occupied.has(furniture_name):
		return false

	var points: Array = interaction_points_occupied[furniture_name]
	for occupied in points:
		if not occupied:
			return true
	return false

func _get_furniture_position(furniture_name: String) -> Vector2:
	match furniture_name:
		"water_cooler": return water_cooler_position
		"plant": return plant_position
		"filing_cabinet": return filing_cabinet_position
		"shredder": return shredder_position
		"taskboard": return taskboard_position
		"meeting_table": return meeting_table_position
	return Vector2.ZERO

func _get_interaction_point_offset(furniture_name: String, point_idx: int) -> Vector2:
	var points: Array[Vector2]
	match furniture_name:
		"water_cooler": points = OfficeConstants.WATER_COOLER_POINTS
		"plant": points = OfficeConstants.PLANT_POINTS
		"filing_cabinet": points = OfficeConstants.FILING_CABINET_POINTS
		"shredder": points = OfficeConstants.SHREDDER_POINTS
		"taskboard": points = OfficeConstants.TASKBOARD_POINTS
		_: return Vector2.ZERO

	if point_idx >= 0 and point_idx < points.size():
		return points[point_idx]
	return Vector2.ZERO

# =============================================================================
# TRAIT-BASED FURNITURE QUERIES (new system)
# =============================================================================

func find_furniture_by_trait(trait_name: String) -> FurnitureBase:
	## Find first furniture with available slot that has the given trait.
	for furniture in trait_furniture:
		if furniture.has_trait(trait_name) and not furniture.is_full():
			return furniture
	return null

func find_available_by_trait(trait_name: String) -> Dictionary:
	## Find furniture with available slot by trait. Returns {furniture, slot_index} or empty dict.
	for furniture in trait_furniture:
		if furniture.has_trait(trait_name):
			var slot_idx: int = furniture.get_available_slot()
			if slot_idx >= 0:
				return {"furniture": furniture, "slot_index": slot_idx}
	return {}

func find_all_with_trait(trait_name: String) -> Array:
	## Get all furniture with the given trait (for weighted random selection).
	var result: Array = []
	for furniture in trait_furniture:
		if furniture.has_trait(trait_name):
			result.append(furniture)
	return result

func find_available_with_trait_weighted(trait_name: String, weights = null) -> Dictionary:
	## Find available furniture by trait with weighted random selection.
	## weights is optional Dictionary: {furniture_type: weight}. Default weight is 1.0.
	if weights == null:
		weights = {}
	var candidates: Array = []
	var total_weight: float = 0.0

	for furniture in trait_furniture:
		if furniture.has_trait(trait_name) and not furniture.is_full():
			var weight: float = weights.get(furniture.furniture_type, 1.0) if weights else 1.0
			candidates.append({"furniture": furniture, "weight": weight})
			total_weight += weight

	if candidates.is_empty():
		return {}

	# Weighted random selection
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for candidate in candidates:
		cumulative += candidate.weight
		if roll <= cumulative:
			var slot_idx: int = candidate.furniture.get_available_slot()
			if slot_idx >= 0:
				return {"furniture": candidate.furniture, "slot_index": slot_idx}

	# Fallback to first available
	return find_available_by_trait(trait_name)

func register_trait_furniture(furniture: FurnitureBase) -> void:
	## Register furniture with the trait system.
	if furniture not in trait_furniture:
		trait_furniture.append(furniture)
		furniture.navigation_grid = navigation_grid
		furniture.office_manager = self

func unregister_trait_furniture(furniture: FurnitureBase) -> void:
	## Remove furniture from the trait system.
	trait_furniture.erase(furniture)

func _on_desk_position_changed(desk: FurnitureDesk, new_position: Vector2) -> void:
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
		# Wrap at screen edges (clouds span full width now)
		if cloud.position.x > OfficeConstants.SCREEN_WIDTH:
			cloud.position.x = -cloud.size.x

func _update_weather_visibility() -> void:
	if not is_instance_valid(weather_system):
		return
	var weather_state = weather_system.get_weather_state()
	var is_fog = weather_state == WeatherSystem.WeatherState.FOG

	if cloud_layer:
		cloud_layer.visible = not is_fog

		# Adjust cloud opacity based on weather
		var cloud_alpha: float = 0.85  # Default (CLOUD_WHITE has 0.85 alpha)
		match weather_state:
			WeatherSystem.WeatherState.CLEAR:
				cloud_alpha = 0.3  # Lighter, fewer visible clouds
			WeatherSystem.WeatherState.RAIN:
				cloud_alpha = 0.8  # Denser clouds during rain
			WeatherSystem.WeatherState.SNOW:
				cloud_alpha = 0.7  # Medium clouds during snow
			WeatherSystem.WeatherState.FOG:
				cloud_alpha = 0.0  # Hidden (layer also hidden)
			_:
				cloud_alpha = 0.6  # Medium fallback

		for data in window_clouds:
			var cloud = data["cloud"] as ColorRect
			if is_instance_valid(cloud):
				cloud.color.a = cloud_alpha

func _update_day_night_cycle() -> void:
	# Get current time
	var time_dict = Time.get_time_dict_from_system()
	var hour = time_dict["hour"]
	var minute = time_dict["minute"]
	var time_of_day = hour + minute / 60.0  # e.g., 14.5 = 2:30pm

	# Determine sky color based on time
	var sky_color: Color
	var ambient_color: Color

	if time_of_day < 5.0:
		# Night (midnight to 5am)
		sky_color = OfficePalette.SKY_NIGHT
		ambient_color = OfficePalette.AMBIENT_NIGHT
	elif time_of_day < 6.0:
		# Early dawn (5-6am) - transition night to dawn
		var t = time_of_day - 5.0  # 0.0 to 1.0
		sky_color = OfficePalette.SKY_NIGHT.lerp(OfficePalette.SKY_DAWN, t)
		ambient_color = OfficePalette.AMBIENT_NIGHT.lerp(OfficePalette.AMBIENT_DAWN, t)
	elif time_of_day < 7.0:
		# Dawn (6-7am) - transition dawn to morning
		var t = time_of_day - 6.0
		sky_color = OfficePalette.SKY_DAWN.lerp(OfficePalette.SKY_MORNING, t)
		ambient_color = OfficePalette.AMBIENT_DAWN.lerp(OfficePalette.AMBIENT_DAY, t)
	elif time_of_day < 9.0:
		# Morning (7-9am) - transition to full day
		var t = (time_of_day - 7.0) / 2.0
		sky_color = OfficePalette.SKY_MORNING.lerp(OfficePalette.SKY_DAY, t)
		ambient_color = OfficePalette.AMBIENT_DAY
	elif time_of_day < 16.0:
		# Day (9am-4pm)
		sky_color = OfficePalette.SKY_DAY
		ambient_color = OfficePalette.AMBIENT_DAY
	elif time_of_day < 17.0:
		# Late afternoon (4-5pm) - transition to afternoon
		var t = time_of_day - 16.0
		sky_color = OfficePalette.SKY_DAY.lerp(OfficePalette.SKY_AFTERNOON, t)
		ambient_color = OfficePalette.AMBIENT_DAY
	elif time_of_day < 18.5:
		# Dusk (5-6:30pm) - transition to sunset
		var t = (time_of_day - 17.0) / 1.5
		sky_color = OfficePalette.SKY_AFTERNOON.lerp(OfficePalette.SKY_DUSK, t)
		ambient_color = OfficePalette.AMBIENT_DAY.lerp(OfficePalette.AMBIENT_DUSK, t)
	elif time_of_day < 20.0:
		# Evening (6:30-8pm) - transition to twilight
		var t = (time_of_day - 18.5) / 1.5
		sky_color = OfficePalette.SKY_DUSK.lerp(OfficePalette.SKY_EVENING, t)
		ambient_color = OfficePalette.AMBIENT_DUSK.lerp(OfficePalette.AMBIENT_NIGHT, t)
	elif time_of_day < 21.0:
		# Twilight (8-9pm) - transition to night
		var t = time_of_day - 20.0
		sky_color = OfficePalette.SKY_EVENING.lerp(OfficePalette.SKY_NIGHT, t)
		ambient_color = OfficePalette.AMBIENT_NIGHT
	else:
		# Night (9pm-midnight)
		sky_color = OfficePalette.SKY_NIGHT
		ambient_color = OfficePalette.AMBIENT_NIGHT

	# Update all window sky backgrounds
	for sky in window_skies:
		if is_instance_valid(sky):
			sky.color = sky_color

	# Update ambient overlay
	if ambient_overlay:
		ambient_overlay.color = ambient_color

	_update_weather_visibility()

	# Update sun/moon visibility and position
	if celestial_layer:
		var sun = celestial_layer.get_node_or_null("Sun")
		var moon = celestial_layer.get_node_or_null("Moon")
		var is_day = time_of_day >= 6.0 and time_of_day < 20.0

		if sun:
			sun.visible = is_day
			if is_day:
				# Sun position based on time (rises from left, sets to right)
				var sun_progress = (time_of_day - 6.0) / 14.0  # 6am-8pm = 14 hours
				sun.position.x = 100 + sun_progress * 1000
				# Arc: higher at noon
				var arc = sin(sun_progress * PI)
				sun.position.y = 30 - arc * 20

		if moon:
			moon.visible = not is_day
			if not is_day:
				# Moon position (simple, mostly static)
				moon.position = Vector2(900, 20)

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
		# reaction_timer is now on the bubbles component
		if current_spontaneous_agent.bubbles and current_spontaneous_agent.bubbles.reaction_timer > 0:
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
	if mcp_server and mcp_server.has_method("record_event"):
		mcp_server.record_event(event_data)

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
		"weather_set":
			_handle_weather_set(event_data)
		"weather_smoke_test":
			_handle_weather_smoke_test(event_data)
		"weather_smoke_stop":
			_handle_weather_smoke_stop(event_data)
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
	var harness_id = data.get("harness_id", "")
	var harness_label = data.get("harness_label", "")
	if session_id:
		var short_id = _get_session_short_id(session_id)
		print("[OfficeManager] Session started: %s" % short_id)
		# Spawn orchestrator as a regular agent (they'll stay until session ends)
		var orch_data = {
			"agent_id": "orch_" + short_id,
			"agent_type": "orchestrator",
			"description": "Session: " + short_id,
			"session_path": session_path,
			"harness_id": harness_id,
			"harness_label": harness_label,
			"is_orchestrator": true
		}
		_handle_agent_spawn(orch_data)
		_update_taskboard()

func _handle_session_end(data: Dictionary) -> void:
	var session_id = data.get("session_id", "")
	var session_path = data.get("session_path", "")
	if not session_id:
		return

	# Find the orchestrator for this session (agent_id starts with "orch_")
	var orch_id = "orch_" + _get_session_short_id(session_id)
	if active_agents.has(orch_id):
		var orchestrator = active_agents[orch_id] as Agent
		if orchestrator and is_instance_valid(orchestrator):
			print("[OfficeManager] Session ended: %s" % _get_session_short_id(session_id))
			# Record orchestrator session completion for XP/stats
			if agent_roster and orchestrator.profile_id >= 0:
				agent_roster.record_orchestrator_session(orchestrator.profile_id)
			# Complete like any other agent (goes to shredder, then leaves)
			orchestrator.force_complete()
	_update_taskboard()
	_prune_session_agent_ids(session_path.get_file().get_basename() if session_path else session_id)

func _handle_session_exit(data: Dictionary) -> void:
	# User ran /exit or /quit - orchestrator should leave the office
	var session_id = data.get("session_id", "")
	var session_path = data.get("session_path", "")
	if not session_id:
		return

	var orch_id = "orch_" + _get_session_short_id(session_id)
	if active_agents.has(orch_id):
		var orchestrator = active_agents[orch_id] as Agent
		if orchestrator and is_instance_valid(orchestrator):
			print("[OfficeManager] Session exit - orchestrator leaving: %s" % _get_session_short_id(session_id))
			orchestrator.force_complete()
		_update_taskboard()
	_prune_session_agent_ids(session_path.get_file().get_basename() if session_path else session_id)

func _on_weather_updated(temperature: float, condition: String, location: String) -> void:
	# Weather service fetched new data - update display if not overridden
	if weather_system and weather_system.live_weather_enabled:
		print("[OfficeManager] Weather updated: %.1f° %s (%s)" % [temperature, condition, location])

func _handle_weather_set(data: Dictionary) -> void:
	if not is_instance_valid(weather_system):
		return
	_stop_weather_smoke_test(false)
	var state_value = data.get("state", data.get("weather", ""))
	var state = _parse_weather_state(state_value)
	if state == -1:
		push_warning("[OfficeManager] Unknown weather state: %s" % str(state_value))
		return
	var mode = str(data.get("mode", "lock")).to_lower()
	var duration = float(data.get("duration", 60.0))
	if mode == "timed":
		weather_system.live_weather_enabled = false
		weather_system.set_weather(state, max(duration, 0.1))
	elif mode == "random":
		weather_system.clear_live_weather()
	else:
		weather_system.set_live_weather(state)
	_apply_weather_display_override(data, state)

func _handle_weather_smoke_test(data: Dictionary) -> void:
	if not is_instance_valid(weather_system):
		return
	var interval = float(data.get("interval", data.get("duration", WEATHER_SMOKE_DEFAULT_INTERVAL)))
	var loop = data.get("loop", true)
	var loop_enabled = loop if loop is bool else true
	var states: Array[int] = []
	var raw_states = data.get("states", null)
	if raw_states is Array:
		for entry in raw_states:
			var parsed = _parse_weather_state(entry)
			if parsed != -1 and not states.has(parsed):
				states.append(parsed)
	if states.is_empty():
		states = _get_all_weather_states()
	_start_weather_smoke_test(interval, loop_enabled, states)

func _handle_weather_smoke_stop(data: Dictionary) -> void:
	var keep = data.get("keep", false)
	_stop_weather_smoke_test(not keep)

func _start_weather_smoke_test(interval: float, loop_enabled: bool, states: Array[int]) -> void:
	weather_smoke_active = true
	weather_smoke_loop = loop_enabled
	weather_smoke_states = states
	weather_smoke_index = 0
	_apply_weather_smoke_state()

	if weather_smoke_timer == null:
		weather_smoke_timer = Timer.new()
		weather_smoke_timer.one_shot = false
		weather_smoke_timer.timeout.connect(_on_weather_smoke_timeout)
		add_child(weather_smoke_timer)
	weather_smoke_timer.wait_time = max(interval, 0.5)
	weather_smoke_timer.start()

func _stop_weather_smoke_test(restore_random: bool) -> void:
	weather_smoke_active = false
	if weather_smoke_timer:
		weather_smoke_timer.stop()
	if restore_random and is_instance_valid(weather_system):
		weather_system.clear_live_weather()

func _on_weather_smoke_timeout() -> void:
	if not weather_smoke_active:
		return
	weather_smoke_index += 1
	if weather_smoke_index >= weather_smoke_states.size():
		if weather_smoke_loop:
			weather_smoke_index = 0
		else:
			_stop_weather_smoke_test(true)
			return
	_apply_weather_smoke_state()

func _apply_weather_smoke_state() -> void:
	if weather_smoke_states.is_empty():
		return
	var state = weather_smoke_states[weather_smoke_index]
	weather_system.set_live_weather(state)

func _apply_weather_display_override(data: Dictionary, _state: int) -> void:
	if not is_instance_valid(temperature_display):
		return
	if not temperature_display.has_method("set_readout"):
		return
	if not data.has("temperature"):
		return
	var temp_value = data.get("temperature", NAN)
	if (temp_value is float and is_nan(temp_value)) or temp_value == null:
		return
	var unit = str(data.get("unit", "C")).to_upper()
	var condition = str(data.get("condition", weather_system.get_weather_name())).strip_edges()
	if not (temp_value is float or temp_value is int):
		return
	var unit_label = "F" if unit == "F" else "C"
	temperature_display.set_readout(float(temp_value), unit_label, condition)

func _parse_weather_state(value) -> int:
	if value is int or value is float:
		var numeric = int(value)
		if _get_all_weather_states().has(numeric):
			return numeric
	var text = str(value).strip_edges().to_lower()
	if text.is_valid_int():
		var numeric_text = int(text)
		if _get_all_weather_states().has(numeric_text):
			return numeric_text
	match text:
		"clear", "sunny":
			return WeatherSystem.WeatherState.CLEAR
		"rain", "rainy", "drizzle", "showers", "storm", "thunder", "thunderstorm":
			return WeatherSystem.WeatherState.RAIN
		"snow", "snowy", "snowing":
			return WeatherSystem.WeatherState.SNOW
		"fog", "foggy", "mist", "cloudy":
			return WeatherSystem.WeatherState.FOG
	return -1

func _get_all_weather_states() -> Array[int]:
	return [
		WeatherSystem.WeatherState.CLEAR,
		WeatherSystem.WeatherState.RAIN,
		WeatherSystem.WeatherState.SNOW,
		WeatherSystem.WeatherState.FOG,
	]

func _handle_agent_spawn(data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "agent_%d" % Time.get_ticks_msec())
	var parent_id = data.get("parent_id", "main")
	var agent_type = data.get("agent_type", "default")
	var description = data.get("description", "")
	var session_path = data.get("session_path", "")
	var harness_id = data.get("harness_id", "")
	var harness_label = data.get("harness_label", "")
	var session_id = session_path.get_file().get_basename() if session_path else "unknown"

	print("[OfficeManager] Spawning agent: %s (%s)" % [agent_type, agent_id])
	known_agent_ids[agent_id] = true

	# Credit the orchestrator for delegating work to subagents
	var is_orchestrator = agent_type == "orchestrator" or data.get("is_orchestrator", false)
	if not is_orchestrator and session_id != "unknown":
		var orch_id = "orch_" + _get_session_short_id(session_id)
		if active_agents.has(orch_id):
			var orchestrator = active_agents[orch_id] as Agent
			if orchestrator and is_instance_valid(orchestrator) and orchestrator.profile_id >= 0:
				if OfficeConstants.DEBUG_TOOL_TRACKING:
					print("[OfficeManager] DELEGATE: orchestrator %s spawned %s" % [orch_id, agent_id])
				agent_roster.record_tool_use(orchestrator.profile_id, "Delegate")

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
	agent.harness_id = harness_id
	agent.harness_label = harness_label
	agent.position = spawn_pos
	agent.set_description(description)
	_configure_agent_positions(agent)
	agent.set_obstacles(office_obstacles)
	agent.navigation_grid = navigation_grid  # Use grid-based pathfinding
	agent.office_manager = self  # For spontaneous bubble coordination
	agent.audio_manager = audio_manager  # For typing sounds
	agent.work_completed.connect(_on_agent_completed)

	# Assign agent profile from roster (orchestrators get the best/highest level agent)
	# Note: is_orchestrator already defined above for Task tool tracking
	if agent_roster:
		var profile = agent_roster.assign_agent_for_task(is_orchestrator)
		if profile:
			agent.profile_id = profile.id
			agent.profile_name = profile.agent_name
			agent.profile_level = profile.level
			agent.profile_badges = profile.badges.duplicate()
			# Apply persistent appearance from profile
			agent.apply_profile_appearance(profile)
			# Optionally use the profile's name for display
			if agent.description.is_empty():
				agent.set_description(profile.agent_name)

	add_child(agent)

	if desk != null:
		# Normal desk assignment
		agent.assign_desk(desk)
		if OfficeConstants.DEBUG_INTERACTION_POINTS or debug_overlay_enabled:
			_draw_spawn_connection(spawn_pos, desk.get_work_position(), agent_type)
	else:
		# Meeting table overflow
		var meeting_spot = get_meeting_spot_position(meeting_spot_idx)
		meeting_spots_occupied[meeting_spot_idx] = true
		agents_in_meeting[agent_id] = meeting_spot_idx
		agent.start_meeting(meeting_spot)
		if OfficeConstants.DEBUG_INTERACTION_POINTS or debug_overlay_enabled:
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
	# Get meeting spot position: table position + relative offset
	if spot_idx < 0 or spot_idx >= OfficeConstants.MEETING_SPOT_OFFSETS.size():
		return meeting_table_position
	return meeting_table_position + OfficeConstants.MEETING_SPOT_OFFSETS[spot_idx]

func _find_agent_for_completion(agent_id: String) -> Agent:
	if agent_id.is_empty():
		return null
	if active_agents.has(agent_id):
		return active_agents[agent_id]

	var matches: Array[String] = []
	for key in active_agents.keys():
		if agent_id.begins_with(key) or key.begins_with(agent_id):
			matches.append(key)

	if matches.size() == 1:
		return active_agents[matches[0]]

	if matches.size() > 1:
		push_warning("[OfficeManager] Multiple agent matches for completion id '%s': %s" % [agent_id, str(matches)])
	return null

func _handle_agent_complete(data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "")
	var result = data.get("result", "")
	var force_immediate = data.get("force", false)  # Bypass MIN_WORK_TIME when true

	if OfficeConstants.DEBUG_EVENTS:
		print("[OfficeManager] _handle_agent_complete: looking for '%s'" % agent_id)
	var agent = _find_agent_for_completion(agent_id)
	if agent == null:
		if completed_agent_ids.has(agent_id) or known_agent_ids.has(agent_id):
			if OfficeConstants.DEBUG_EVENTS:
				print("[OfficeManager] Completion for '%s' ignored (agent not active)" % agent_id)
			return
		push_warning("[OfficeManager] Agent '%s' not found for completion, skipping" % agent_id)
		return

	if OfficeConstants.DEBUG_EVENTS:
		print("[OfficeManager] Found agent '%s' in state %s" % [agent_id, Agent.State.keys()[agent.state]])

	# Notify MCP Manager of dismissal (if source is MCP)
	var source = data.get("source", "")
	if mcp_manager and source == "mcp":
		mcp_manager.on_agent_dismissed(agent_id, agent)

	if result:
		agent.set_result(result)
	agent.force_complete(force_immediate)
	completed_agent_ids[agent_id] = true
	print("[OfficeManager] Completed agent: %s%s" % [agent_id, " (forced)" if force_immediate else ""])

func _handle_waiting_for_input(data: Dictionary) -> void:
	var tool_name = data.get("tool", "")
	var session_path = data.get("session_path", "")
	var session_id = session_path.get_file().get_basename() if session_path else ""

	print("[OfficeManager] Waiting for input: %s (session: %s)" % [tool_name, _get_session_short_id(session_id) if session_id else "unknown"])
	status_label.text = "Tool: %s" % tool_name if tool_name else "Waiting..."

	# Find the best agent for this session - prefer working sub-agents over orchestrator
	var target_agent: Agent = _find_working_agent_for_session(session_id)

	# If no working agent found, try to recall idle agents from this session
	if not target_agent:
		target_agent = _recall_idle_agent_for_session(session_id)

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
		print("[OfficeManager] No working agent found for session '%s' (agents_by_session keys: %s, active: %s)" % [_get_session_short_id(session_id) if session_id else "?", str(agents_by_session.keys()).substr(0, 50), str(active_agents.size())])
	return null

func _recall_idle_agent_for_session(session_id: String) -> Agent:
	# Look for idle agents belonging to this session and recall them to work
	if not session_id or not agents_by_session.has(session_id):
		return null

	for agent_id in agents_by_session[session_id]:
		if not active_agents.has(agent_id):
			continue
		var agent = active_agents[agent_id] as Agent
		if agent.can_resume_work():
			if agent.resume_work():
				print("[OfficeManager] Recalled idle agent: %s" % agent_id)
				return agent

	# Fallback: check all active agents
	for aid in active_agents.keys():
		var agent = active_agents[aid] as Agent
		if agent.can_resume_work():
			if agent.resume_work():
				print("[OfficeManager] Recalled idle agent (fallback): %s" % aid)
				return agent

	return null

func _handle_input_received(data: Dictionary) -> void:
	var session_path = data.get("session_path", "")
	var session_id = session_path.get_file().get_basename() if session_path else ""

	print("[OfficeManager] Input received (session: %s)" % [_get_session_short_id(session_id) if session_id else "unknown"])
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
			# Track for cat achievements
			if gamification_manager:
				gamification_manager.record_cat_interaction()

func _configure_agent_positions(agent: Agent) -> void:
	agent.set_shredder_position(shredder_position)
	agent.set_water_cooler_position(water_cooler_position)
	agent.set_plant_position(plant_position)
	agent.set_filing_cabinet_position(filing_cabinet_position)
	agent.set_taskboard_position(taskboard_position)
	agent.set_meeting_table_position(meeting_table_position)

func _find_available_desk() -> FurnitureDesk:
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

	# Record task duration for speed achievements
	if gamification_manager and agent.last_task_duration > 0:
		gamification_manager.record_task_completed(agent.last_task_duration)

	active_agents.erase(aid)
	completed_agent_ids[aid] = true
	if agent_by_type.has(agent.agent_type):
		agent_by_type[agent.agent_type].erase(aid)
	if agent.session_id and agents_by_session.has(agent.session_id):
		agents_by_session[agent.session_id].erase(aid)
		if agents_by_session[agent.session_id].is_empty():
			agents_by_session.erase(agent.session_id)

	# Safety: ensure desk is released before agent is freed
	if agent.assigned_desk:
		agent.assigned_desk.set_occupied(false, agent.agent_id)
		agent.assigned_desk = null

	# Release meeting spot if this agent was in a meeting
	_release_meeting_spot(aid)

	# Release any interaction point held by this agent
	release_interaction_point(aid)

	# Disconnect signal before freeing to prevent stale callbacks
	if agent.work_completed.is_connected(_on_agent_completed):
		agent.work_completed.disconnect(_on_agent_completed)

	agent.queue_free()

func _prune_session_agent_ids(session_id: String) -> void:
	if session_id.is_empty():
		return
	if not agents_by_session.has(session_id):
		return

	var remaining: Array[String] = []
	for aid in agents_by_session[session_id]:
		if active_agents.has(aid):
			remaining.append(aid)
		else:
			known_agent_ids.erase(aid)
			completed_agent_ids.erase(aid)

	if remaining.is_empty():
		agents_by_session.erase(session_id)
	else:
		agents_by_session[session_id] = remaining

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
		"cat_bed":
			cat_bed_position = new_position
			obstacle_size = OfficeConstants.CAT_BED_OBSTACLE
			var bs = OfficeConstants.CAT_BED_OBSTACLE
			_update_obstacle(5, Rect2(new_position.x - bs.x / 2, new_position.y - bs.y / 2, bs.x, bs.y))
			if office_cat and office_cat.has_method("set_cat_bed_position"):
				office_cat.set_cat_bed_position(new_position)
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

func _create_profiler_overlay() -> void:
	profiler_label = Label.new()
	profiler_label.position = Vector2(10, 10)
	profiler_label.add_theme_font_size_override("font_size", 12)
	profiler_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	profiler_label.z_index = OfficeConstants.Z_UI
	profiler_label.visible = false
	add_child(profiler_label)

func _update_profiler_overlay() -> void:
	if not profiler_label:
		return
	var fps = Engine.get_frames_per_second()
	var agent_count = active_agents.size()
	var session_count = 0
	if transcript_watcher and transcript_watcher.has_method("get_watched_count"):
		session_count = transcript_watcher.get_watched_count()
	profiler_label.text = "FPS: %d | Agents: %d | Sessions: %d" % [fps, agent_count, session_count]

func _update_taskboard() -> void:
	if not transcript_watcher or not taskboard:
		return

	var y_offset = 28

	var harnesses: Array = []
	if transcript_watcher.has_method("get_harness_summary"):
		harnesses = transcript_watcher.get_harness_summary()

	var active_keys: Dictionary = {}
	for harness in harnesses:
		var harness_id = harness.get("id", "")
		if harness_id.is_empty():
			continue
		active_keys[harness_id] = true
		var label_text = harness.get("label", harness_id)
		var session_count = int(harness.get("session_count", 0))
		var configured = bool(harness.get("configured", false))
		var enabled = bool(harness.get("enabled", true))
		var count_text = "off" if not enabled else (str(session_count) if configured else "--")
		var text = "%s [%s]" % [label_text, count_text]

		if taskboard_labels.has(harness_id):
			taskboard_labels[harness_id].text = text
			taskboard_labels[harness_id].position = Vector2(10, y_offset)
		else:
			var label = Label.new()
			label.text = text
			label.position = Vector2(10, y_offset)
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
			taskboard.add_child(label)
			taskboard_labels[harness_id] = label

		y_offset += 12

	var to_remove: Array[String] = []
	for key in taskboard_labels.keys():
		if not active_keys.has(key):
			taskboard_labels[key].queue_free()
			to_remove.append(key)
	for key in to_remove:
		taskboard_labels.erase(key)

func _get_session_short_id(session_id: String) -> String:
	if session_id.is_empty():
		return "unknown"
	if session_id.length() <= 8:
		return session_id
	return session_id.substr(session_id.length() - 8)

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
# DATA HYGIENE
# =============================================================================

func _perform_autosave() -> void:
	if is_quitting:
		return
	if agent_roster:
		agent_roster.save_roster()
	if gamification_manager:
		gamification_manager.save_all()

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
	if data.has("cat_bed"):
		cat_bed_position = Vector2(data["cat_bed"]["x"], data["cat_bed"]["y"])

	# Load removed defaults
	if data.has("removed_defaults"):
		removed_default_furniture.clear()
		for item in data["removed_defaults"]:
			removed_default_furniture.append(str(item))

	# Load dynamic furniture (will be created after defaults)
	if data.has("dynamic_furniture"):
		pending_dynamic_furniture.clear()
		for item in data["dynamic_furniture"]:
			pending_dynamic_furniture.append({
				"id": str(item.get("id", "")),
				"type": str(item.get("type", "")),
				"position": Vector2(item.get("x", 0), item.get("y", 0))
			})

	# Load furniture ID counter
	if data.has("furniture_id_counter"):
		furniture_id_counter = int(data["furniture_id_counter"])

	print("[OfficeManager] Loaded saved furniture positions")

func _save_positions() -> void:
	var data = {
		"water_cooler": {"x": water_cooler_position.x, "y": water_cooler_position.y},
		"plant": {"x": plant_position.x, "y": plant_position.y},
		"filing_cabinet": {"x": filing_cabinet_position.x, "y": filing_cabinet_position.y},
		"shredder": {"x": shredder_position.x, "y": shredder_position.y},
		"taskboard": {"x": taskboard_position.x, "y": taskboard_position.y},
		"meeting_table": {"x": meeting_table_position.x, "y": meeting_table_position.y},
		"cat_bed": {"x": cat_bed_position.x, "y": cat_bed_position.y},
	}

	# Track which default furniture has been removed
	var removed_defaults: Array[String] = []
	if draggable_water_cooler == null:
		removed_defaults.append("water_cooler")
	if draggable_plant == null:
		removed_defaults.append("plant")
	if draggable_filing_cabinet == null:
		removed_defaults.append("filing_cabinet")
	if draggable_shredder == null:
		removed_defaults.append("shredder")
	if draggable_cat_bed == null:
		removed_defaults.append("cat_bed")
	if draggable_taskboard == null:
		removed_defaults.append("taskboard")
	if meeting_table == null:
		removed_defaults.append("meeting_table")
	data["removed_defaults"] = removed_defaults

	# Save dynamic furniture
	var dynamic_items: Array = []
	for f in placed_furniture:
		dynamic_items.append({
			"id": f.id,
			"type": f.type,
			"x": f.position.x,
			"y": f.position.y
		})
	data["dynamic_furniture"] = dynamic_items
	data["furniture_id_counter"] = furniture_id_counter

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(POSITIONS_FILE, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to save positions: %s" % FileAccess.get_open_error())
		return

	file.store_string(json_string)
	file.close()

func _on_reset_button_pressed() -> void:
	print("[OfficeManager] Resetting furniture positions to defaults")

	# Reset all positions to defaults
	water_cooler_position = DEFAULT_POSITIONS["water_cooler"]
	plant_position = DEFAULT_POSITIONS["plant"]
	filing_cabinet_position = DEFAULT_POSITIONS["filing_cabinet"]
	shredder_position = DEFAULT_POSITIONS["shredder"]
	taskboard_position = DEFAULT_POSITIONS["taskboard"]
	meeting_table_position = DEFAULT_POSITIONS["meeting_table"]
	cat_bed_position = DEFAULT_POSITIONS["cat_bed"]

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
	if draggable_cat_bed:
		draggable_cat_bed.position = cat_bed_position
		_on_item_position_changed("cat_bed", cat_bed_position)

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
	roster_popup.agent_fired.connect(_on_roster_popup_agent_fired)

func _on_roster_popup_closed() -> void:
	if roster_popup:
		roster_popup.queue_free()
		roster_popup = null

func _on_roster_popup_agent_selected(agent_id: int) -> void:
	_on_roster_popup_closed()
	_show_agent_profile(agent_id)

func _on_roster_popup_agent_fired(agent_id: int) -> void:
	if not agent_roster:
		return
	var success = agent_roster.fire_agent(agent_id)
	if not success:
		print("[OfficeManager] Failed to fire agent %d (busy or missing)" % agent_id)
	if roster_popup:
		roster_popup.show_roster(agent_roster)

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
	profile_popup.profile_updated.connect(_on_profile_updated)

func _on_profile_popup_closed() -> void:
	if profile_popup:
		profile_popup.queue_free()
		profile_popup = null

func _on_profile_updated(profile: AgentProfile) -> void:
	if not profile:
		return
	# Save the updated profile to disk
	if agent_roster:
		agent_roster.save_profile(profile)
	# Refresh any active agent with this profile
	for agent_id in active_agents.keys():
		var agent = active_agents[agent_id] as Agent
		if agent and is_instance_valid(agent) and agent.profile_id == profile.id:
			agent.refresh_appearance(profile)
			# Update the agent's display name if it changed
			if agent.visuals:
				agent.visuals.update_tooltip()
			break  # Only one agent can have this profile at a time

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

func _show_watcher_config_popup() -> void:
	if watcher_config_popup != null:
		return
	if not transcript_watcher:
		return
	watcher_config_popup = WatcherConfigPopupScript.new()
	add_child(watcher_config_popup)
	watcher_config_popup.show_config(transcript_watcher, mcp_server)
	watcher_config_popup.close_requested.connect(_on_watcher_config_popup_closed)

func _on_watcher_config_popup_closed() -> void:
	if watcher_config_popup:
		watcher_config_popup.queue_free()
		watcher_config_popup = null

# =============================================================================
# FURNITURE SHELF
# =============================================================================

func _show_furniture_shelf() -> void:
	if furniture_shelf_popup != null:
		return
	furniture_shelf_popup = FurnitureShelfPopup.new()
	add_child(furniture_shelf_popup)
	furniture_shelf_popup.show_shelf(_get_placed_furniture_list())
	furniture_shelf_popup.close_requested.connect(_on_furniture_shelf_closed)
	furniture_shelf_popup.furniture_add_requested.connect(_on_furniture_add_requested)
	furniture_shelf_popup.furniture_remove_requested.connect(_on_furniture_remove_requested)

func _on_furniture_shelf_closed() -> void:
	if furniture_shelf_popup:
		furniture_shelf_popup.queue_free()
		furniture_shelf_popup = null

func _get_placed_furniture_list() -> Array:
	var result: Array = []
	# Add default furniture (the original single instances)
	if draggable_water_cooler and is_instance_valid(draggable_water_cooler):
		result.append({"id": "default_water_cooler", "type": "water_cooler", "position": water_cooler_position})
	if draggable_plant and is_instance_valid(draggable_plant):
		result.append({"id": "default_plant", "type": "potted_plant", "position": plant_position})
	if draggable_filing_cabinet and is_instance_valid(draggable_filing_cabinet):
		result.append({"id": "default_filing_cabinet", "type": "filing_cabinet", "position": filing_cabinet_position})
	if draggable_shredder and is_instance_valid(draggable_shredder):
		result.append({"id": "default_shredder", "type": "shredder", "position": shredder_position})
	if draggable_cat_bed and is_instance_valid(draggable_cat_bed):
		result.append({"id": "default_cat_bed", "type": "cat_bed", "position": cat_bed_position})
	if draggable_taskboard and is_instance_valid(draggable_taskboard):
		result.append({"id": "default_taskboard", "type": "taskboard", "position": taskboard_position})
	if meeting_table and is_instance_valid(meeting_table):
		result.append({"id": "default_meeting_table", "type": "meeting_table", "position": meeting_table_position})
	# Add dynamically placed furniture
	for f in placed_furniture:
		result.append({"id": f.id, "type": f.type, "position": f.position})
	return result

func _on_furniture_add_requested(furniture_type: String) -> void:
	# Find a suitable spawn position (center of the floor)
	var spawn_pos = Vector2(640, 400)
	_add_furniture(furniture_type, spawn_pos)
	# Refresh the shelf display
	if furniture_shelf_popup:
		furniture_shelf_popup.show_shelf(_get_placed_furniture_list())

func _on_furniture_remove_requested(furniture_id: String) -> void:
	_remove_furniture(furniture_id)
	# Refresh the shelf display
	if furniture_shelf_popup:
		furniture_shelf_popup.show_shelf(_get_placed_furniture_list())

func _add_furniture(furniture_type: String, pos: Vector2) -> void:
	furniture_id_counter += 1
	var fid = "furniture_%d" % furniture_id_counter

	# Map legacy type names to registry names
	var registry_type := furniture_type
	if furniture_type == "potted_plant":
		registry_type = "plant"

	var furniture: FurnitureBase = furniture_registry.spawn_with_id(registry_type, pos, fid)
	if not furniture:
		push_warning("[OfficeManager] Unknown furniture type: %s" % furniture_type)
		return

	furniture.navigation_grid = navigation_grid
	furniture.office_manager = self
	furniture.position_changed.connect(_on_dynamic_furniture_moved.bind(fid))
	add_child(furniture)

	# Register with trait system
	register_trait_furniture(furniture)

	placed_furniture.append({
		"id": fid,
		"type": furniture_type,  # Keep original type for save/load compatibility
		"position": pos,
		"node": furniture,
		"obstacle_size": furniture.obstacle_size
	})

	# Register obstacle with navigation grid
	var obstacle_rect = Rect2(pos - furniture.obstacle_size / 2, furniture.obstacle_size)
	navigation_grid.register_obstacle(obstacle_rect, fid)

	_save_positions()
	print("[OfficeManager] Added furniture: %s at %s" % [furniture_type, position])

func _on_dynamic_furniture_moved(item_name: String, new_position: Vector2, furniture_id: String) -> void:
	for f in placed_furniture:
		if f.id == furniture_id:
			f.position = new_position
			break
	_save_positions()

func _remove_furniture(furniture_id: String) -> void:
	# Check if it's a default furniture piece
	if furniture_id.begins_with("default_"):
		_remove_default_furniture(furniture_id)
		return

	# Find and remove dynamic furniture
	for i in range(placed_furniture.size()):
		if placed_furniture[i].id == furniture_id:
			var f = placed_furniture[i]
			if f.node and is_instance_valid(f.node):
				# Remove obstacle from navigation
				navigation_grid.unregister_obstacle(furniture_id)
				f.node.queue_free()
			placed_furniture.remove_at(i)
			_save_positions()
			print("[OfficeManager] Removed furniture: %s" % furniture_id)
			return

func _remove_default_furniture(furniture_id: String) -> void:
	var node: Node2D = null
	var obstacle_id: String = ""

	match furniture_id:
		"default_water_cooler":
			node = draggable_water_cooler
			obstacle_id = "water_cooler"
			draggable_water_cooler = null
		"default_plant":
			node = draggable_plant
			obstacle_id = "plant"
			draggable_plant = null
		"default_filing_cabinet":
			node = draggable_filing_cabinet
			obstacle_id = "filing_cabinet"
			draggable_filing_cabinet = null
		"default_shredder":
			node = draggable_shredder
			obstacle_id = "shredder"
			draggable_shredder = null
		"default_cat_bed":
			node = draggable_cat_bed
			obstacle_id = "cat_bed"
			draggable_cat_bed = null
		"default_taskboard":
			node = draggable_taskboard
			obstacle_id = "taskboard"
			draggable_taskboard = null
			taskboard = null
		"default_meeting_table":
			node = meeting_table
			obstacle_id = "meeting_table"
			meeting_table = null
		_:
			return

	if node and is_instance_valid(node):
		if not obstacle_id.is_empty():
			navigation_grid.unregister_obstacle(obstacle_id)
		node.queue_free()
		_save_positions()
		print("[OfficeManager] Removed default furniture: %s" % furniture_id)

# =============================================================================
# VOLUME SETTINGS POPUP
# =============================================================================

func _show_volume_settings_popup() -> void:
	if volume_settings_popup != null:
		return
	volume_settings_popup = VolumeSettingsPopupScript.new()
	add_child(volume_settings_popup)
	volume_settings_popup.setup(audio_manager)
	volume_settings_popup.close_requested.connect(_on_volume_settings_closed)

func _on_volume_settings_closed() -> void:
	if volume_settings_popup:
		volume_settings_popup.queue_free()
		volume_settings_popup = null

# =============================================================================
# WEATHER SETTINGS POPUP
# =============================================================================

func _show_weather_settings_popup() -> void:
	if weather_settings_popup != null:
		return
	weather_settings_popup = WeatherSettingsPopupScript.new()
	add_child(weather_settings_popup)
	weather_settings_popup.setup(weather_service)
	weather_settings_popup.close_requested.connect(_on_weather_settings_closed)

func _on_weather_settings_closed() -> void:
	if weather_settings_popup:
		weather_settings_popup.queue_free()
		weather_settings_popup = null

func is_any_popup_open() -> bool:
	return roster_popup != null or profile_popup != null or achievement_popup != null or pause_menu != null or watcher_config_popup != null or furniture_shelf_popup != null or volume_settings_popup != null or weather_settings_popup != null

func is_draggable_on_top(item: Node2D, global_pos: Vector2) -> bool:
	# Check if the given draggable item is the topmost one at the given position
	# Returns true if no other draggable with higher z_index contains the point
	var item_z = item.z_index
	var draggables = _get_all_draggables()

	for other in draggables:
		if other == item:
			continue
		if not is_instance_valid(other):
			continue
		if other.z_index <= item_z:
			continue  # This item is at or below our z-index
		# Check if the point is within the other item's click area
		var other_local = other.to_local(global_pos)
		if other.click_area.has_point(other_local):
			return false  # Another item with higher z-index is at this position

	return true  # No higher z-index item found

func _get_all_draggables() -> Array:
	var result: Array = []
	# Default furniture
	if draggable_water_cooler and is_instance_valid(draggable_water_cooler):
		result.append(draggable_water_cooler)
	if draggable_plant and is_instance_valid(draggable_plant):
		result.append(draggable_plant)
	if draggable_filing_cabinet and is_instance_valid(draggable_filing_cabinet):
		result.append(draggable_filing_cabinet)
	if draggable_shredder and is_instance_valid(draggable_shredder):
		result.append(draggable_shredder)
	if draggable_cat_bed and is_instance_valid(draggable_cat_bed):
		result.append(draggable_cat_bed)
	if draggable_taskboard and is_instance_valid(draggable_taskboard):
		result.append(draggable_taskboard)
	if meeting_table and is_instance_valid(meeting_table):
		result.append(meeting_table)
	# Dynamic furniture
	for f in placed_furniture:
		if f.node and is_instance_valid(f.node):
			result.append(f.node)
	# Desks
	for desk in desks:
		if desk and is_instance_valid(desk):
			result.append(desk)
	return result

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
	pause_menu.profiler_enabled = profiler_enabled
	pause_menu.debug_enabled = debug_overlay_enabled
	pause_menu.audio_manager = audio_manager
	pause_menu.weather_service = weather_service
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_on_pause_resume)
	pause_menu.roster_requested.connect(_on_pause_roster)
	pause_menu.reset_layout_requested.connect(_on_pause_reset_layout)
	pause_menu.achievements_requested.connect(_on_pause_achievements)
	pause_menu.watchers_requested.connect(_on_pause_watchers)
	pause_menu.furniture_shelf_requested.connect(_on_pause_furniture_shelf)
	pause_menu.profiler_toggled.connect(_on_pause_profiler_toggled)
	pause_menu.debug_toggled.connect(_on_pause_debug_toggled)
	pause_menu.event_log_requested.connect(_on_pause_event_log)
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

func _on_pause_watchers() -> void:
	_close_pause_menu()
	_show_watcher_config_popup()

func _on_pause_furniture_shelf() -> void:
	_close_pause_menu()
	_show_furniture_shelf()

func _on_pause_volume_settings() -> void:
	_close_pause_menu()
	_show_volume_settings_popup()

func _on_pause_weather_settings() -> void:
	_close_pause_menu()
	_show_weather_settings_popup()

func _on_pause_profiler_toggled(enabled: bool) -> void:
	profiler_enabled = enabled
	if profiler_label:
		profiler_label.visible = profiler_enabled
	profiler_update_timer = 0.0
	if profiler_enabled:
		_update_profiler_overlay()

func _on_pause_debug_toggled(enabled: bool) -> void:
	debug_overlay_enabled = enabled
	if debug_overlay_enabled:
		_update_debug_visualizations()
	elif debug_layer:
		# Clear debug visuals when disabled
		for child in debug_layer.get_children():
			child.queue_free()

func _on_pause_event_log() -> void:
	_close_pause_menu()
	_show_event_log()

func _show_event_log() -> void:
	if event_log != null:
		return
	event_log = DebugEventLogScript.new()
	add_child(event_log)
	event_log.close_requested.connect(_close_event_log)

func _close_event_log() -> void:
	if event_log:
		event_log.queue_free()
		event_log = null

func _on_pause_quit() -> void:
	_request_quit()
