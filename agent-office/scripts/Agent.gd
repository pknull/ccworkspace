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

# Mood thresholds (in seconds)
const MOOD_TIRED_THRESHOLD: float = 1800.0      # 30 minutes
const MOOD_FRUSTRATED_THRESHOLD: float = 3600.0  # 1 hour
const MOOD_IRATE_THRESHOLD: float = 7200.0       # 2 hours

# Mood-specific phrases for spontaneous bubbles
const TIRED_PHRASES = [
	"*yawn*", "Need coffee...", "Getting tired.", "Long day...",
	"*stretches*", "How much longer?", "Break soon?",
]
const FRUSTRATED_PHRASES = [
	"Ugh.", "Really?", "*sigh*", "Come on...", "Why...",
	"This again?", "Seriously?", "Not ideal.",
]
const IRATE_PHRASES = [
	"ENOUGH!", "I'M DONE.", "*grumble*", "UGH!",
	"GET ME OUT.", "THIS IS RIDICULOUS", "WHY.",
]

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

# Phrases shown when agent finishes their task (instead of truncated results)
const COMPLETION_PHRASES = [
	"Task complete! Time for a break.",
	"All done here!",
	"Wrapped that up nicely.",
	"Another one in the books.",
	"Mission accomplished!",
	"That should do it.",
	"Finished and filed!",
	"Work's done, heading out.",
	"Nailed it!",
	"Off to the next thing.",
	"That was a good one.",
	"Signed, sealed, delivered.",
	"Task conquered!",
	"And... done!",
	"Time to celebrate!",
]

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
var state: State = State.SPAWNING
var target_position: Vector2
var assigned_desk: Node2D = null
var shredder_position: Vector2 = OfficeConstants.SHREDDER_POSITION
var water_cooler_position: Vector2 = OfficeConstants.WATER_COOLER_POSITION
var plant_position: Vector2 = OfficeConstants.PLANT_POSITION
var filing_cabinet_position: Vector2 = OfficeConstants.FILING_CABINET_POSITION
var taskboard_position: Vector2 = OfficeConstants.TASKBOARD_POSITION
var meeting_table_position: Vector2 = OfficeConstants.MEETING_TABLE_POSITION
var door_position: Vector2 = OfficeConstants.SPAWN_POINT

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
var furniture_tour_targets: Array[Dictionary] = []

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

var _visuals_created: bool = false
var is_female: bool = false
var hair_color: Color = OfficePalette.HAIR_BROWN  # Default brown
var skin_color: Color = OfficePalette.SKIN_LIGHT  # Store for persistence
var hair_style_index: int = 0  # For female agents
var blouse_color_index: int = 0  # For female agents
var appearance_applied: bool = false  # Track if persistent appearance was applied

# Personal items this worker brings to their desk
var personal_item_types: Array[String] = []  # Which items this worker has

# Per-agent cooldowns for social spots (spot_key -> seconds remaining)
var social_spot_cooldowns: Dictionary = {}
var nav_nudge_retries: int = 0
var nav_retry_target: Vector2 = Vector2.ZERO
var walk_last_position: Vector2 = Vector2.ZERO
var walk_stuck_timer: float = 0.0

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
	pass

func _ready() -> void:
	if not _visuals_created:
		_create_visuals()
		_visuals_created = true
	_update_appearance()
	_generate_reaction_phrases()
	if description and status_label:
		set_description(description)
	spawn_timer = OfficeConstants.AGENT_SPAWN_FADE_TIME
	# Initialize fidget timing
	next_fidget_time = randf_range(OfficeConstants.FIDGET_TIME_MIN, OfficeConstants.FIDGET_TIME_MAX)
	walk_speed_multiplier = randf_range(0.9, 1.1)
	walk_last_position = position

func _create_visuals() -> void:
	_ensure_ui_nodes()
	# Randomly determine gender and appearance
	is_female = randf() < 0.5

	# Random hair color (using palette)
	var hair_colors = [
		OfficePalette.HAIR_BROWN,
		OfficePalette.HAIR_BLACK,
		OfficePalette.HAIR_AUBURN,
		OfficePalette.HAIR_BLONDE,
		OfficePalette.HAIR_DARK_BROWN,
		OfficePalette.HAIR_VERY_DARK,
	]
	hair_color = hair_colors[randi() % hair_colors.size()]

	# Random skin tone (using palette)
	var skin_tones = [
		OfficePalette.SKIN_LIGHT,
		OfficePalette.SKIN_MEDIUM,
		OfficePalette.SKIN_TAN,
		OfficePalette.SKIN_DARK,
		OfficePalette.SKIN_VERY_LIGHT,
	]
	skin_color = skin_tones[randi() % skin_tones.size()]

	# Store indices for potential persistence
	hair_style_index = randi() % 3
	blouse_color_index = randi() % 4

	if is_female:
		_create_female_visuals(skin_color)
	else:
		_create_male_visuals(skin_color)

	# Eyes are now added as children of head in _create_male/female_visuals

func _ensure_ui_nodes() -> void:
	if type_label:
		return
	# Type label (hidden - clutters the view)
	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.position = Vector2(-40, -55)
	type_label.size = Vector2(80, 16)
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_GRAY)
	type_label.visible = false  # Hidden
	add_child(type_label)

	# Status label background (hidden - only shown on hover via tooltip)
	var status_bg = ColorRect.new()
	status_bg.name = "StatusBg"
	status_bg.size = Vector2(120, 16)
	status_bg.position = Vector2(-60, -72)
	status_bg.color = OfficePalette.UI_BG_DARK
	status_bg.visible = false  # Hidden by default
	add_child(status_bg)

	# Status label (hidden - status shown in hover tooltip)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(-60, -73)
	status_label.size = Vector2(120, 16)
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_LIGHT)
	status_label.visible = false  # Hidden by default
	add_child(status_label)

	# Tool indicator
	tool_bg = ColorRect.new()
	tool_bg.size = Vector2(32, 20)
	tool_bg.position = Vector2(18, -30)
	tool_bg.color = OfficePalette.UI_BG_DARKER
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
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	add_child(shadow)

	# Legs (dark trousers)
	var left_leg = ColorRect.new()
	left_leg.size = Vector2(10, 18)
	left_leg.position = Vector2(-12, 15)
	left_leg.color = OfficePalette.AGENT_TROUSERS_DARK
	add_child(left_leg)

	var right_leg = ColorRect.new()
	right_leg.size = Vector2(10, 18)
	right_leg.position = Vector2(2, 15)
	right_leg.color = OfficePalette.AGENT_TROUSERS_DARK
	add_child(right_leg)

	# Body/torso (gruvbox light shirt)
	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = OfficePalette.AGENT_SHIRT_WHITE
	body.z_index = 0
	add_child(body)

	# Shirt collar points
	var collar_left = ColorRect.new()
	collar_left.size = Vector2(8, 6)
	collar_left.position = Vector2(-11, -15)
	collar_left.color = OfficePalette.AGENT_SHIRT_WHITE
	collar_left.z_index = 0
	add_child(collar_left)

	var collar_right = ColorRect.new()
	collar_right.size = Vector2(8, 6)
	collar_right.position = Vector2(3, -15)
	collar_right.color = OfficePalette.AGENT_SHIRT_WHITE
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
	left_eye.color = OfficePalette.EYE_COLOR
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)  # Relative to head
	right_eye.color = OfficePalette.EYE_COLOR
	head.add_child(right_eye)

func _create_female_visuals(skin_color: Color) -> void:
	# Shadow under agent
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	add_child(shadow)

	# Legs (skirt or trousers - random)
	var wears_skirt = randf() < 0.6

	if wears_skirt:
		# Skirt
		var skirt = ColorRect.new()
		skirt.size = Vector2(28, 14)
		skirt.position = Vector2(-14, 10)
		skirt.color = OfficePalette.AGENT_SKIRT_DARK
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
		left_leg.color = OfficePalette.AGENT_SKIRT_DARK
		add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(10, 18)
		right_leg.position = Vector2(2, 15)
		right_leg.color = OfficePalette.AGENT_SKIRT_DARK
		add_child(right_leg)

	# Body/torso (blouse - gruvbox colors, avoid floor/desk colors)
	var blouse_colors = [
		OfficePalette.AGENT_SHIRT_WHITE,
		OfficePalette.AGENT_BLOUSE_PINK,
		OfficePalette.AGENT_BLOUSE_BLUE,
		OfficePalette.AGENT_BLOUSE_LAVENDER,
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
	left_eye.color = OfficePalette.EYE_COLOR
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)  # Relative to head
	right_eye.color = OfficePalette.EYE_COLOR
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
	tooltip_panel.size = Vector2(280, 220)  # Larger to hold up to 500 characters
	tooltip_panel.position = Vector2(30, -100)
	tooltip_panel.color = OfficePalette.TOOLTIP_BG
	tooltip_panel.visible = false
	tooltip_panel.z_index = OfficeConstants.Z_UI_TOOLTIP  # Always on top
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tooltip_panel)

	# Tooltip border
	var border = ColorRect.new()
	border.size = Vector2(280, 220)
	border.position = Vector2(0, 0)
	border.color = OfficePalette.TOOLTIP_BORDER
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(border)

	var inner = ColorRect.new()
	inner.size = Vector2(276, 216)
	inner.position = Vector2(2, 2)
	inner.color = OfficePalette.GRUVBOX_LIGHT
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(inner)

	# Tooltip header
	var header = Label.new()
	header.name = "Header"
	header.position = Vector2(6, 4)
	header.size = Vector2(268, 16)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", OfficePalette.GRUVBOX_BG2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(header)

	# Divider line
	var divider = ColorRect.new()
	divider.size = Vector2(268, 1)
	divider.position = Vector2(6, 20)
	divider.color = OfficePalette.TOOLTIP_DIVIDER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(divider)

	# Tooltip content - sized for up to 500 characters with word wrap
	tooltip_label = Label.new()
	tooltip_label.position = Vector2(6, 23)
	tooltip_label.size = Vector2(268, 190)
	tooltip_label.add_theme_font_size_override("font_size", 9)
	tooltip_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(tooltip_label)

func _update_appearance() -> void:
	var color = get_agent_color(agent_type)
	if tie:
		tie.color = color
	var tie_knot_node = get_node_or_null("TieKnot")
	if tie_knot_node:
		tie_knot_node.color = color.darkened(0.1)
	type_label.text = get_agent_label(agent_type)

func apply_profile_appearance(profile: AgentProfile) -> void:
	# Apply persistent visual identity from the agent roster profile
	_apply_appearance_values(profile.is_female, profile.hair_color_index, profile.skin_color_index, profile.hair_style_index, profile.blouse_color_index)

	# Store profile info for tooltip display
	profile_name = profile.agent_name
	profile_level = profile.level
	profile_badges = profile.badges.duplicate()

func _apply_appearance_values(p_is_female: bool, p_hair_index: int, p_skin_index: int, p_hair_style: int, p_blouse_color: int) -> void:
	# Apply persistent visual identity
	# This ensures the same agent always looks the same across sessions
	if appearance_applied:
		return  # Don't apply twice

	appearance_applied = true
	_ensure_ui_nodes()

	# Hair colors palette
	var hair_colors = [
		OfficePalette.HAIR_BROWN,
		OfficePalette.HAIR_BLACK,
		OfficePalette.HAIR_AUBURN,
		OfficePalette.HAIR_BLONDE,
		OfficePalette.HAIR_DARK_BROWN,
		OfficePalette.HAIR_VERY_DARK,
	]

	# Skin tones palette
	var skin_tones = [
		OfficePalette.SKIN_LIGHT,
		OfficePalette.SKIN_MEDIUM,
		OfficePalette.SKIN_TAN,
		OfficePalette.SKIN_DARK,
		OfficePalette.SKIN_VERY_LIGHT,
	]

	if _visuals_created:
		# Always clear and recreate visuals with profile appearance
		# This ensures consistent appearance regardless of random initial state
		_clear_visual_nodes()

	is_female = p_is_female
	hair_color = hair_colors[p_hair_index % hair_colors.size()]
	skin_color = skin_tones[p_skin_index % skin_tones.size()]
	hair_style_index = p_hair_style
	blouse_color_index = p_blouse_color

	if is_female:
		_create_female_visuals_persistent(skin_color, hair_color, hair_style_index, blouse_color_index)
	else:
		_create_male_visuals_persistent(skin_color, hair_color)
	_visuals_created = true

func _clear_visual_nodes() -> void:
	# Clear body-related visual nodes for recreation
	# We track known UI element references and preserve only those

	# Build list of nodes to preserve (UI elements we know about)
	var preserve_nodes: Array[Node] = []
	if status_label and is_instance_valid(status_label):
		preserve_nodes.append(status_label)
	if type_label and is_instance_valid(type_label):
		preserve_nodes.append(type_label)
	if tool_label and is_instance_valid(tool_label):
		preserve_nodes.append(tool_label)
	if tool_bg and is_instance_valid(tool_bg):
		preserve_nodes.append(tool_bg)
	if tooltip_panel and is_instance_valid(tooltip_panel):
		preserve_nodes.append(tooltip_panel)

	# Find StatusBg by name (it's not stored as a variable)
	var status_bg = get_node_or_null("StatusBg")
	if status_bg:
		preserve_nodes.append(status_bg)

	# Remove all children except preserved ones
	for child in get_children():
		if child not in preserve_nodes:
			child.queue_free()

	# Reset body part references
	body = null
	head = null
	hair = null
	tie = null
	shirt = null

func _update_visual_colors(new_skin_color: Color, new_hair_color: Color) -> void:
	# Update colors on existing visual nodes
	if head:
		head.color = new_skin_color

	# Update hair color - hair is child of head
	if head:
		for child in head.get_children():
			if child is ColorRect and child != head:
				# Check if it's a hair node (not eyes)
				if child.color.r > 0.3 or child.color.g > 0.3:  # Eyes are dark
					if child.size.y >= 6:  # Hair is larger than eyes
						child.color = new_hair_color

func _create_male_visuals_persistent(p_skin_color: Color, p_hair_color: Color) -> void:
	# Shadow under agent
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	add_child(shadow)

	# Legs
	var left_leg = ColorRect.new()
	left_leg.size = Vector2(10, 18)
	left_leg.position = Vector2(-12, 15)
	left_leg.color = OfficePalette.AGENT_TROUSERS_DARK
	add_child(left_leg)

	var right_leg = ColorRect.new()
	right_leg.size = Vector2(10, 18)
	right_leg.position = Vector2(2, 15)
	right_leg.color = OfficePalette.AGENT_TROUSERS_DARK
	add_child(right_leg)

	# Body/torso
	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = OfficePalette.AGENT_SHIRT_WHITE
	body.z_index = 0
	add_child(body)

	# Collar
	var collar_left = ColorRect.new()
	collar_left.size = Vector2(8, 6)
	collar_left.position = Vector2(-11, -15)
	collar_left.color = OfficePalette.AGENT_SHIRT_WHITE
	add_child(collar_left)

	var collar_right = ColorRect.new()
	collar_right.size = Vector2(8, 6)
	collar_right.position = Vector2(3, -15)
	collar_right.color = OfficePalette.AGENT_SHIRT_WHITE
	add_child(collar_right)

	# Tie
	tie = ColorRect.new()
	tie.size = Vector2(6, 22)
	tie.position = Vector2(-3, -12)
	tie.z_index = 1
	add_child(tie)

	var tie_knot = ColorRect.new()
	tie_knot.name = "TieKnot"
	tie_knot.size = Vector2(8, 5)
	tie_knot.position = Vector2(-4, -15)
	tie_knot.z_index = 1
	add_child(tie_knot)

	# Head
	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = p_skin_color
	head.z_index = 2
	add_child(head)

	# Hair - child of head
	hair = ColorRect.new()
	hair.size = Vector2(20, 8)
	hair.position = Vector2(-1, -5)
	hair.color = p_hair_color
	head.add_child(hair)

	# Eyes
	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(3, 5)
	left_eye.color = OfficePalette.EYE_COLOR
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)
	right_eye.color = OfficePalette.EYE_COLOR
	head.add_child(right_eye)

func _create_female_visuals_persistent(p_skin_color: Color, p_hair_color: Color, p_hair_style: int, p_blouse_index: int) -> void:
	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(30, 12)
	shadow.position = Vector2(-15, 28)
	shadow.color = OfficePalette.SHADOW_MEDIUM
	shadow.z_index = -1
	add_child(shadow)

	# Legs (skirt or trousers based on stored preference)
	var wears_skirt = p_blouse_index % 2 == 0  # Deterministic based on index

	if wears_skirt:
		var skirt = ColorRect.new()
		skirt.size = Vector2(28, 14)
		skirt.position = Vector2(-14, 10)
		skirt.color = OfficePalette.AGENT_SKIRT_DARK
		add_child(skirt)

		var left_leg = ColorRect.new()
		left_leg.size = Vector2(8, 10)
		left_leg.position = Vector2(-10, 22)
		left_leg.color = p_skin_color.darkened(0.1)
		add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(8, 10)
		right_leg.position = Vector2(2, 22)
		right_leg.color = p_skin_color.darkened(0.1)
		add_child(right_leg)
	else:
		var left_leg = ColorRect.new()
		left_leg.size = Vector2(10, 18)
		left_leg.position = Vector2(-12, 15)
		left_leg.color = OfficePalette.AGENT_SKIRT_DARK
		add_child(left_leg)

		var right_leg = ColorRect.new()
		right_leg.size = Vector2(10, 18)
		right_leg.position = Vector2(2, 15)
		right_leg.color = OfficePalette.AGENT_SKIRT_DARK
		add_child(right_leg)

	# Blouse
	var blouse_colors = [
		OfficePalette.AGENT_SHIRT_WHITE,
		OfficePalette.AGENT_BLOUSE_PINK,
		OfficePalette.AGENT_BLOUSE_BLUE,
		OfficePalette.AGENT_BLOUSE_LAVENDER,
	]
	var blouse_color = blouse_colors[p_blouse_index % blouse_colors.size()]

	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = blouse_color
	body.z_index = 0
	add_child(body)

	var collar = ColorRect.new()
	collar.size = Vector2(18, 6)
	collar.position = Vector2(-9, -17)
	collar.color = blouse_color
	add_child(collar)

	tie = null  # Female agents don't have ties

	# Head
	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = p_skin_color
	head.z_index = 2
	add_child(head)

	# Eyes
	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(3, 5)
	left_eye.color = OfficePalette.EYE_COLOR
	head.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(12, 5)
	right_eye.color = OfficePalette.EYE_COLOR
	head.add_child(right_eye)

	# Hair style based on index
	match p_hair_style % 3:
		0:
			# Long hair with side parts
			hair = ColorRect.new()
			hair.size = Vector2(24, 12)
			hair.position = Vector2(-3, -7)
			hair.color = p_hair_color
			head.add_child(hair)

			var hair_left = ColorRect.new()
			hair_left.size = Vector2(6, 18)
			hair_left.position = Vector2(-5, -1)
			hair_left.color = p_hair_color
			head.add_child(hair_left)

			var hair_right = ColorRect.new()
			hair_right.size = Vector2(6, 18)
			hair_right.position = Vector2(17, -1)
			hair_right.color = p_hair_color
			head.add_child(hair_right)
		1:
			# Bob cut
			hair = ColorRect.new()
			hair.size = Vector2(26, 14)
			hair.position = Vector2(-4, -9)
			hair.color = p_hair_color
			head.add_child(hair)

			var hair_sides = ColorRect.new()
			hair_sides.size = Vector2(28, 8)
			hair_sides.position = Vector2(-5, 1)
			hair_sides.color = p_hair_color
			head.add_child(hair_sides)
		2:
			# Ponytail/updo
			hair = ColorRect.new()
			hair.size = Vector2(22, 10)
			hair.position = Vector2(-2, -8)
			hair.color = p_hair_color
			head.add_child(hair)

			var bun = ColorRect.new()
			bun.size = Vector2(10, 10)
			bun.position = Vector2(4, -15)
			bun.color = p_hair_color
			head.add_child(bun)

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
	_update_reaction_timer(delta)

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

	if in_bounds and not is_hovered:
		is_hovered = true
		_show_tooltip()
	elif not in_bounds and is_hovered:
		is_hovered = false
		_hide_tooltip()

func _show_tooltip() -> void:
	if tooltip_panel:
		var tooltip_width = tooltip_panel.size.x
		var tooltip_height = tooltip_panel.size.y

		# Horizontal positioning - flip to left side if near right edge
		var tooltip_x: float = 30.0  # Default: right side of agent
		if global_position.x + 30 + tooltip_width > OfficeConstants.SCREEN_WIDTH:
			tooltip_x = -tooltip_width - 10  # Left side

		# Vertical positioning - shift down if near top edge, up if near bottom
		var tooltip_y: float = -100.0  # Default: above agent
		if global_position.y + tooltip_y < 0:
			# Too close to top - position below the default
			tooltip_y = -global_position.y + 10
		elif global_position.y + tooltip_y + tooltip_height > OfficeConstants.SCREEN_HEIGHT - 30:
			# Too close to bottom (leave room for status bar) - shift up
			tooltip_y = OfficeConstants.SCREEN_HEIGHT - 30 - tooltip_height - global_position.y

		tooltip_panel.position = Vector2(tooltip_x, tooltip_y)

		var header = tooltip_panel.get_node_or_null("Header")
		if header:
			# Show profile name if available, otherwise agent type
			if profile_name:
				header.text = profile_name + " (Lv." + str(profile_level) + " " + get_agent_label(agent_type) + ")"
			else:
				header.text = get_agent_label(agent_type) + " (" + agent_id.substr(0, 8) + ")"
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
				State.CHATTING: state_text = "Small talk"
				State.WANDERING: state_text = "Looking around"

			# Build tooltip content
			var lines: Array[String] = []

			# Status line first
			var status_line = "Status: " + state_text
			if state == State.WORKING and work_elapsed > 0:
				status_line += " (%.0fs)" % work_elapsed
			lines.append(status_line)

			# Mood and floor time
			var floor_time = get_floor_time_text()
			var mood_text = get_mood_text()
			if mood_text:
				lines.append("Mood: " + mood_text + (" (%s)" % floor_time if floor_time else ""))
			elif floor_time:
				lines.append(floor_time)

			# Badges (if any)
			if not profile_badges.is_empty():
				lines.append("Badges: " + ", ".join(profile_badges))

			# Current tool (if working and using a tool)
			if state == State.WORKING and current_tool:
				lines.append("Using: " + current_tool)

			# Show result when finished (up to 500 chars)
			if result and (state == State.DELIVERING or state == State.LEAVING or state == State.COMPLETING or state == State.SOCIALIZING):
				lines.append("")
				var res_text = result.strip_edges()
				if res_text.length() > 500:
					res_text = res_text.substr(0, 497) + "..."
				lines.append("Result: " + res_text)
			else:
				# Task description - show up to 500 characters while working
				lines.append("")
				if description:
					var desc = description.strip_edges()
					if desc.length() > 500:
						desc = desc.substr(0, 497) + "..."
					lines.append("Task: " + desc)
				else:
					lines.append("(no task assigned)")

			tooltip_label.text = "\n".join(lines)
		tooltip_panel.visible = true

func _hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _process_spawning(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = 1.0 - (spawn_timer / OfficeConstants.AGENT_SPAWN_FADE_TIME)
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
			# Arrived at desk, start working
			work_elapsed = 0.0
			state = State.WORKING
			_log_debug_event("STATE", "Started working at desk")
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
			spawn_timer = OfficeConstants.AGENT_SPAWN_FADE_TIME
			if status_label:
				status_label.text = "Goodbye!"
		State.FURNITURE_TOUR:
			# Arrived at a furniture item during tour
			_furniture_tour_arrived()

func _furniture_tour_arrived() -> void:
	if not furniture_tour_active:
		return

	# Brief pause at each furniture item
	var current_target = furniture_tour_targets[furniture_tour_index]
	print("[Agent %s] Furniture tour: arrived at %s" % [agent_id, current_target.get("name", "unknown")])
	if status_label:
		status_label.text = current_target.get("status", "Inspecting...")

	# Move to next target after a short delay
	furniture_tour_index += 1
	if furniture_tour_index < furniture_tour_targets.size():
		# Continue tour after brief pause
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or not furniture_tour_active:
			return
		var next_target = furniture_tour_targets[furniture_tour_index]
		if status_label:
			status_label.text = "Walking to " + next_target.get("name", "next")
		_build_path_to(next_target["pos"])
	else:
		# Tour complete
		print("[Agent %s] Furniture tour complete!" % agent_id)
		furniture_tour_active = false
		if status_label:
			status_label.text = "Tour complete!"
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

func _pick_tour_target(candidates: Array[Vector2], fallback: Vector2) -> Vector2:
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
	print("[Agent %s] Starting furniture tour" % agent_id)
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
	if status_label:
		status_label.text = "Starting tour..."
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
	var available: Array = []
	for option in options:
		if option.get("type", "") == "exit":
			available.append(option)
			continue
		var key = option.get("cooldown_key", "")
		if key.is_empty() or not social_spot_cooldowns.has(key):
			available.append(option)

	if available.is_empty():
		available = options

	var total_weight = 0.0
	for option in available:
		total_weight += float(option.get("weight", 1.0))

	var roll = randf() * total_weight
	for option in available:
		roll -= float(option.get("weight", 1.0))
		if roll <= 0.0:
			return option

	return available[available.size() - 1]

func _mark_social_spot_cooldown(option: Dictionary) -> void:
	var key = option.get("cooldown_key", "")
	if key.is_empty():
		return
	social_spot_cooldowns[key] = SOCIAL_SPOT_COOLDOWN

func _update_social_spot_cooldowns(delta: float) -> void:
	if social_spot_cooldowns.is_empty():
		return
	var to_clear: Array[String] = []
	for key in social_spot_cooldowns.keys():
		var remaining = float(social_spot_cooldowns[key]) - delta
		if remaining <= 0.0:
			to_clear.append(key)
		else:
			social_spot_cooldowns[key] = remaining
	for key in to_clear:
		social_spot_cooldowns.erase(key)

func _start_socializing_at(target_pos: Vector2, status_text: String, furniture_name: String = "", apply_offset: bool = true) -> void:
	# Release any previously held interaction point
	_release_current_interaction_point()

	# Check if this furniture uses interaction points
	if office_manager and _is_tracked_furniture(furniture_name):
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
	if status_label:
		status_label.text = status_text

func _is_tracked_furniture(furniture_name: String) -> bool:
	"""Check if this furniture uses the interaction point system."""
	return furniture_name in ["water_cooler", "plant", "filing_cabinet", "shredder", "taskboard"]

func _release_current_interaction_point() -> void:
	"""Release any interaction point we're currently holding."""
	if office_manager and current_interaction_furniture:
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

	if status_label:
		status_label.text = "Looking around..."

func _process_wandering(delta: float) -> void:
	"""Process wandering state - walk to random position, then retry finding a spot."""
	# If we have waypoints, keep walking
	if not path_waypoints.is_empty():
		_process_walking_path(delta)
		return

	# Idle animation while waiting (looking around)
	if body:
		body.position.y = -15 + sin(Time.get_ticks_msec() * 0.003) * 1.5
	if head:
		head.position.y = -35 + sin(Time.get_ticks_msec() * 0.003 + 0.5) * 1.5

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
	if assigned_desk:
		if assigned_desk.has_method("hide_tool"):
			assigned_desk.hide_tool()
		assigned_desk.set_occupied(false)
		assigned_desk = null
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

func _process_chatting(delta: float) -> void:
	# Chat animation - agents face each other and sway slightly
	if body:
		body.position.y = -15 + sin(Time.get_ticks_msec() * 0.004) * 1.5
	if head:
		head.position.y = -35 + sin(Time.get_ticks_msec() * 0.004 + 0.3) * 1.5

	# Spontaneous bubbles during chat
	_process_spontaneous_bubble(delta, true)

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

	if status_label:
		status_label.text = "Chatting..."

func end_chat() -> void:
	chat_cooldown = CHAT_COOLDOWN_TIME
	chatting_with = null

	# Reset head position after facing other agent
	if head:
		head.position.x = -9  # Default center position

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
	var phrase = SMALL_TALK_PHRASES[randi() % SMALL_TALK_PHRASES.size()]
	_show_speech_bubble(phrase)

# Called when near the office cat
func react_to_cat() -> void:
	if cat_reaction_cooldown > 0:
		return
	if state == State.COMPLETING or state == State.SPAWNING or state == State.LEAVING:
		return

	cat_reaction_cooldown = CAT_REACTION_COOLDOWN_TIME
	var phrase = CAT_PHRASES[randi() % CAT_PHRASES.size()]
	_show_speech_bubble(phrase)

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
	if body:
		body.position.y = -15 + body_bob
	if head:
		head.position.y = -35 + head_bob

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
	_log_debug_event("STATE", "Joining meeting")
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
		var t = Time.get_ticks_msec() * 0.008
		var bob = sin(t) * 1.5
		if body:
			body.position.y = base_body_y + bob
		if head:
			head.position.y = base_head_y + bob

		# Typing sound
		typing_timer += delta
		if typing_timer >= TYPING_INTERVAL:
			typing_timer = 0.0
			if audio_manager and randf() < 0.3:  # 30% chance per interval to avoid constant sound
				audio_manager.play_typing()

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
			print("[Agent %s] Cannot reach destination %s - going idle" % [agent_id, destination])
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
	if state == State.WALKING_TO_DESK and assigned_desk:
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
				if status_label:
					status_label.text = "Skipping to " + next_target.get("name", "next")
				_build_path_to(next_target["pos"])
			else:
				furniture_tour_active = false
				_start_leaving()
		State.SOCIALIZING, State.DELIVERING:
			# Can't reach destination, just leave
			_start_leaving()
		_:
			state = State.IDLE
			if status_label:
				status_label.text = "Can't get there..."

func on_furniture_moved(furniture_name: String, new_position: Vector2) -> void:
	"""Called when furniture moves - recalculate path if we're heading there."""
	if destination_furniture != furniture_name:
		return

	if path_waypoints.is_empty():
		return

	_log_debug_event("NAV", "Furniture moved: %s -> recalc path" % furniture_name)
	print("[Agent %s] Recalculating path - %s moved to %s" % [agent_id, furniture_name, new_position])

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
	if assigned_desk:
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
		if status_label:
			status_label.text = "Shredding docs..."
	else:
		var delivery_pos = _get_random_filing_cabinet_approach()
		_build_path_to(delivery_pos, "filing_cabinet")
		if status_label:
			status_label.text = "Filing away..."

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
	if assigned_desk:
		state = State.WALKING_TO_DESK
		_build_path_to(assigned_desk.get_work_position())
		if status_label:
			status_label.text = "Going to desk..."

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
	if status_label:
		if desc.length() > 25:
			status_label.text = desc.substr(0, 22) + "..."
		else:
			status_label.text = desc

func set_result(res: String) -> void:
	result = res
	# Show a brief summary as a speech bubble when result is set
	if result:
		_show_result_bubble()

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
			spawn_timer = OfficeConstants.AGENT_SPAWN_FADE_TIME
		State.DELIVERING, State.SOCIALIZING, State.LEAVING, State.COMPLETING:
			pass  # Already on their way out

func show_tool(tool_name: String) -> void:
	current_tool = tool_name
	# No timer - tool persists until changed

	var icon = OfficePalette.TOOL_ICONS.get(tool_name, "[" + tool_name.substr(0, 1) + "]")
	var color = OfficePalette.TOOL_COLORS.get(tool_name, OfficePalette.TOOL_DEFAULT)

	# Show on desk monitor if we have an assigned desk
	if assigned_desk and assigned_desk.has_method("show_tool"):
		assigned_desk.show_tool(icon, color)
	else:
		# Fallback to floating label if no desk
		if tool_label and tool_bg:
			tool_label.text = icon
			tool_label.add_theme_color_override("font_color", color)
			tool_bg.color = OfficePalette.UI_BG_DARKER
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
			# Random mug color (using palette)
			var mug_colors = [OfficePalette.MUG_WHITE, OfficePalette.MUG_RED, OfficePalette.MUG_BLUE, OfficePalette.MUG_GREEN, OfficePalette.MUG_YELLOW]
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
			frame.color = OfficePalette.PHOTO_FRAME_WOOD
			item.add_child(frame)
			# Photo inside
			var photo = ColorRect.new()
			photo.size = Vector2(10, 10)
			photo.position = Vector2(2, 2)
			photo.color = OfficePalette.PHOTO_SKY
			item.add_child(photo)

		"plant":
			# Small terracotta pot
			var pot = ColorRect.new()
			pot.size = Vector2(14, 10)
			pot.position = Vector2(0, 4)
			pot.color = OfficePalette.POT_TERRACOTTA
			item.add_child(pot)
			# Pot rim
			var rim = ColorRect.new()
			rim.size = Vector2(16, 3)
			rim.position = Vector2(-1, 2)
			rim.color = OfficePalette.POT_TERRACOTTA_DARK
			item.add_child(rim)
			# Soil
			var soil = ColorRect.new()
			soil.size = Vector2(12, 3)
			soil.position = Vector2(1, 3)
			soil.color = OfficePalette.SOIL_DARK
			item.add_child(soil)
			# Succulent/cactus body
			var cactus = ColorRect.new()
			cactus.size = Vector2(8, 10)
			cactus.position = Vector2(3, -6)
			cactus.color = OfficePalette.LEAF_GREEN
			item.add_child(cactus)
			# Small arm/leaf
			var leaf = ColorRect.new()
			leaf.size = Vector2(4, 6)
			leaf.position = Vector2(10, -4)
			leaf.color = OfficePalette.LEAF_GREEN_LIGHT
			item.add_child(leaf)

		"pencil_cup":
			# Cup
			var cup = ColorRect.new()
			cup.size = Vector2(10, 14)
			cup.position = Vector2(0, 0)
			cup.color = OfficePalette.PENCIL_CUP
			item.add_child(cup)
			# Pencils
			var pencil1 = ColorRect.new()
			pencil1.size = Vector2(2, 8)
			pencil1.position = Vector2(2, -6)
			pencil1.color = OfficePalette.PENCIL_YELLOW
			item.add_child(pencil1)
			var pencil2 = ColorRect.new()
			pencil2.size = Vector2(2, 6)
			pencil2.position = Vector2(6, -4)
			pencil2.color = OfficePalette.PENCIL_BLUE
			item.add_child(pencil2)

		"stress_ball":
			var ball = ColorRect.new()
			ball.size = Vector2(12, 12)
			ball.position = Vector2(0, 2)
			var ball_colors = [OfficePalette.GRUVBOX_RED_BRIGHT, OfficePalette.GRUVBOX_BLUE_BRIGHT, OfficePalette.GRUVBOX_YELLOW_BRIGHT, OfficePalette.GRUVBOX_AQUA_BRIGHT]
			ball.color = ball_colors[randi() % ball_colors.size()]
			item.add_child(ball)

		"snack":
			# Snack wrapper/bag
			var wrapper = ColorRect.new()
			wrapper.size = Vector2(14, 10)
			wrapper.position = Vector2(0, 4)
			var snack_colors = [OfficePalette.GRUVBOX_RED_BRIGHT, OfficePalette.GRUVBOX_BLUE, OfficePalette.GRUVBOX_ORANGE_BRIGHT]
			wrapper.color = snack_colors[randi() % snack_colors.size()]
			item.add_child(wrapper)

		"water_bottle":
			# Bottle
			var bottle = ColorRect.new()
			bottle.size = Vector2(8, 18)
			bottle.position = Vector2(0, -4)
			bottle.color = OfficePalette.WATER_BOTTLE
			item.add_child(bottle)
			# Cap
			var cap = ColorRect.new()
			cap.size = Vector2(6, 4)
			cap.position = Vector2(1, -6)
			cap.color = OfficePalette.WATER_BOTTLE_CAP
			item.add_child(cap)

		"figurine":
			# Base
			var base = ColorRect.new()
			base.size = Vector2(10, 4)
			base.position = Vector2(0, 10)
			base.color = OfficePalette.FIGURINE_BASE
			item.add_child(base)
			# Figure body
			var fig = ColorRect.new()
			fig.size = Vector2(8, 14)
			fig.position = Vector2(1, -4)
			var fig_colors = [OfficePalette.GRUVBOX_RED_BRIGHT, OfficePalette.GRUVBOX_GREEN, OfficePalette.GRUVBOX_BLUE, OfficePalette.GRUVBOX_YELLOW_BRIGHT]
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

# Small talk when bumping into another agent
const SMALL_TALK_PHRASES = [
	"Hey!", "Oh, hi!", "Fancy meeting you!", "How's your day?",
	"Nice tie!", "Love your work!", "Quick chat?", "What's up?",
	"Busy day?", "Tell me about it!", "Ha, right?", "Same here!",
	"I know, right?", "Totally.", "For real!", "Big mood.",
	"Coffee later?", "Heading out soon?", "Almost done!", "Hang in there!",
]

# Cat interaction phrases
const CAT_PHRASES = [
	"Aww, kitty!", "Hey there!", "Pspspsps!", "Good kitty!",
	"Nice cat!", "Who's fluffy?", "Office mascot!", "*pets*",
	"Hello, friend!", "Meow to you too!", "So soft!", "Cute!",
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

func _unhandled_input(event: InputEvent) -> void:
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
	reaction_bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	add_child(reaction_bubble)

	# Speech bubble background (gruvbox light)
	var bubble_bg = ColorRect.new()
	var text_width = phrase.length() * 7 + 16
	bubble_bg.size = Vector2(max(text_width, 60), 24)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -95)
	bubble_bg.color = OfficePalette.SPEECH_BUBBLE
	reaction_bubble.add_child(bubble_bg)

	# Bubble border
	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(4, 4)
	bubble_border.position = bubble_bg.position - Vector2(2, 2)
	bubble_border.color = OfficePalette.SPEECH_BUBBLE_BORDER
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	# Bubble pointer (triangle approximation with small rect)
	var pointer = ColorRect.new()
	pointer.size = Vector2(8, 8)
	pointer.position = Vector2(-4, -73)
	pointer.color = OfficePalette.SPEECH_BUBBLE
	reaction_bubble.add_child(pointer)

	# Pointer border
	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(10, 10)
	pointer_border.position = Vector2(-5, -74)
	pointer_border.color = OfficePalette.SPEECH_BUBBLE_BORDER
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	# Text
	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(8, 3)
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	reaction_bubble.add_child(text_label)

	# Set timer for how long the bubble shows
	reaction_timer = 2.5

# Generic speech bubble display (used for small talk, cat reactions, etc.)
func _show_speech_bubble(phrase: String) -> void:
	# Don't show if already showing a reaction
	if reaction_timer > 0:
		return

	# Create or update reaction bubble
	if reaction_bubble:
		reaction_bubble.queue_free()

	reaction_bubble = Node2D.new()
	reaction_bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	add_child(reaction_bubble)

	# Speech bubble background
	var bubble_bg = ColorRect.new()
	var text_width = phrase.length() * 7 + 16
	bubble_bg.size = Vector2(max(text_width, 60), 24)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -95)
	bubble_bg.color = OfficePalette.SPEECH_BUBBLE
	reaction_bubble.add_child(bubble_bg)

	# Bubble border
	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(4, 4)
	bubble_border.position = bubble_bg.position - Vector2(2, 2)
	bubble_border.color = OfficePalette.SPEECH_BUBBLE_BORDER
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	# Bubble pointer
	var pointer = ColorRect.new()
	pointer.size = Vector2(8, 8)
	pointer.position = Vector2(-4, -73)
	pointer.color = OfficePalette.SPEECH_BUBBLE
	reaction_bubble.add_child(pointer)

	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(10, 10)
	pointer_border.position = Vector2(-5, -74)
	pointer_border.color = OfficePalette.SPEECH_BUBBLE_BORDER
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	# Text
	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(8, 3)
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	reaction_bubble.add_child(text_label)

	reaction_timer = 2.5

# Set which direction the agent faces (for chatting)
func _set_facing_direction(face_left: bool) -> void:
	# This is a simple implementation - flip the head position slightly
	# In a more complex setup, you'd mirror sprites
	if head:
		if face_left:
			head.position.x = -4  # Slightly left of center
		else:
			head.position.x = 4   # Slightly right of center

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

func _update_mood() -> void:
	var old_mood = current_mood
	if time_on_floor >= MOOD_IRATE_THRESHOLD:
		current_mood = Mood.IRATE
	elif time_on_floor >= MOOD_FRUSTRATED_THRESHOLD:
		current_mood = Mood.FRUSTRATED
	elif time_on_floor >= MOOD_TIRED_THRESHOLD:
		current_mood = Mood.TIRED
	else:
		current_mood = Mood.CONTENT

	# Update mood indicator if mood changed
	if old_mood != current_mood:
		_update_mood_indicator()

func _update_mood_indicator() -> void:
	if not mood_indicator:
		mood_indicator = Label.new()
		mood_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mood_indicator.position = Vector2(-10, -70)
		mood_indicator.size = Vector2(20, 16)
		mood_indicator.add_theme_font_size_override("font_size", 12)
		add_child(mood_indicator)

	match current_mood:
		Mood.CONTENT:
			mood_indicator.text = ""
			mood_indicator.visible = false
		Mood.TIRED:
			mood_indicator.text = "~"
			mood_indicator.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
			mood_indicator.visible = true
		Mood.FRUSTRATED:
			mood_indicator.text = "!"
			mood_indicator.add_theme_color_override("font_color", OfficePalette.GRUVBOX_ORANGE)
			mood_indicator.visible = true
		Mood.IRATE:
			mood_indicator.text = "!!"
			mood_indicator.add_theme_color_override("font_color", OfficePalette.GRUVBOX_RED)
			mood_indicator.visible = true

func get_mood_text() -> String:
	match current_mood:
		Mood.TIRED:
			return "Tired"
		Mood.FRUSTRATED:
			return "Frustrated"
		Mood.IRATE:
			return "IRATE"
		_:
			return ""

func get_floor_time_text() -> String:
	var hours = int(time_on_floor / 3600)
	var minutes = int(fmod(time_on_floor, 3600) / 60)
	if hours > 0:
		return "%dh %dm on floor" % [hours, minutes]
	elif minutes > 0:
		return "%dm on floor" % minutes
	return ""

# Idle fidget animation functions
func _start_random_fidget() -> void:
	var fidgets = ["head_scratch", "stretch", "look_around", "lean_back", "sip_drink", "adjust_posture"]
	current_fidget = fidgets[randi() % fidgets.size()]
	fidget_progress = 0.0
	next_fidget_time = randf_range(OfficeConstants.NEXT_FIDGET_MIN, OfficeConstants.NEXT_FIDGET_MAX)

func _process_fidget(delta: float) -> void:
	if current_fidget == "":
		return

	fidget_progress += delta
	var fidget_duration = OfficeConstants.FIDGET_DURATION
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
	if is_instance_valid(office_manager) and office_manager.has_method("can_show_spontaneous_bubble"):
		return office_manager.can_show_spontaneous_bubble()
	return true  # Default to yes if no manager

func _show_spontaneous_reaction(is_socializing: bool = false, is_meeting: bool = false) -> void:
	# Pick appropriate phrase based on context
	var phrase = ""

	# Mood-based phrases take priority when agent is unhappy
	var use_mood_phrase = false
	if current_mood == Mood.IRATE:
		use_mood_phrase = randf() < 0.7  # 70% chance to complain when irate
	elif current_mood == Mood.FRUSTRATED:
		use_mood_phrase = randf() < 0.4  # 40% chance when frustrated
	elif current_mood == Mood.TIRED:
		use_mood_phrase = randf() < 0.25  # 25% chance when tired

	if use_mood_phrase:
		match current_mood:
			Mood.IRATE:
				phrase = IRATE_PHRASES[randi() % IRATE_PHRASES.size()]
			Mood.FRUSTRATED:
				phrase = FRUSTRATED_PHRASES[randi() % FRUSTRATED_PHRASES.size()]
			Mood.TIRED:
				phrase = TIRED_PHRASES[randi() % TIRED_PHRASES.size()]
	# If we have a tool and it's work-related context, sometimes mention the tool
	elif current_tool and not is_socializing and randf() < 0.5:
		phrase = _get_tool_aware_phrase(current_tool, is_meeting)
	else:
		var phrases = WORKING_PHRASES
		if is_meeting:
			phrases = MEETING_PHRASES
		elif is_socializing:
			phrases = SOCIALIZING_PHRASES
		phrase = phrases[randi() % phrases.size()]

	# Notify manager that we're showing a bubble
	if is_instance_valid(office_manager) and office_manager.has_method("register_spontaneous_bubble"):
		office_manager.register_spontaneous_bubble(self)

	# Create smaller, quicker bubble than click reactions
	if reaction_bubble:
		reaction_bubble.queue_free()

	reaction_bubble = Node2D.new()
	reaction_bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	add_child(reaction_bubble)

	# Smaller speech bubble for spontaneous thoughts (gruvbox)
	var bubble_bg = ColorRect.new()
	var text_width = phrase.length() * 6 + 12
	bubble_bg.size = Vector2(max(text_width, 50), 20)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -90)
	bubble_bg.color = Color(OfficePalette.GRUVBOX_LIGHT.r, OfficePalette.GRUVBOX_LIGHT.g, OfficePalette.GRUVBOX_LIGHT.b, 0.92)
	reaction_bubble.add_child(bubble_bg)

	# Thinner border
	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(2, 2)
	bubble_border.position = bubble_bg.position - Vector2(1, 1)
	bubble_border.color = OfficePalette.GRUVBOX_GRAY
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	# Smaller pointer
	var pointer = ColorRect.new()
	pointer.size = Vector2(6, 6)
	pointer.position = Vector2(-3, -71)
	pointer.color = Color(OfficePalette.GRUVBOX_LIGHT.r, OfficePalette.GRUVBOX_LIGHT.g, OfficePalette.GRUVBOX_LIGHT.b, 0.92)
	reaction_bubble.add_child(pointer)

	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(8, 8)
	pointer_border.position = Vector2(-4, -72)
	pointer_border.color = OfficePalette.GRUVBOX_GRAY
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	# Smaller text
	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(6, 2)
	text_label.add_theme_font_size_override("font_size", 10)
	text_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_BG2)
	reaction_bubble.add_child(text_label)

	# Shorter display time for spontaneous bubbles
	reaction_timer = 1.8

func clear_spontaneous_bubble() -> void:
	# Called by manager when another agent wants to show a bubble
	if reaction_bubble and reaction_timer > 0.5:
		# Only clear if we've shown for at least 0.5s
		reaction_timer = 0.3  # Quick fade out

func _show_result_bubble() -> void:
	# Show a completion phrase as a speech bubble when task finishes
	# Pick a phrase based on agent_id hash for consistency
	var phrase_idx = hash(agent_id) % COMPLETION_PHRASES.size()
	var phrase = COMPLETION_PHRASES[phrase_idx]

	# If already showing a reaction, queue this for later or skip
	if reaction_bubble:
		reaction_bubble.queue_free()

	reaction_bubble = Node2D.new()
	reaction_bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	add_child(reaction_bubble)

	# Result bubble - gruvbox aqua-tinted to indicate success/completion
	var bubble_bg = ColorRect.new()
	var text_width = phrase.length() * 6 + 20  # Width estimate for font size 11
	bubble_bg.size = Vector2(min(max(text_width, 100), 400), 26)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -100)
	bubble_bg.color = OfficePalette.RESULT_BUBBLE_BG
	reaction_bubble.add_child(bubble_bg)

	# Border
	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(4, 4)
	bubble_border.position = bubble_bg.position - Vector2(2, 2)
	bubble_border.color = OfficePalette.RESULT_BUBBLE_BORDER
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	# Pointer
	var pointer = ColorRect.new()
	pointer.size = Vector2(8, 8)
	pointer.position = Vector2(-4, -76)
	pointer.color = OfficePalette.RESULT_BUBBLE_BG
	reaction_bubble.add_child(pointer)

	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(10, 10)
	pointer_border.position = Vector2(-5, -77)
	pointer_border.color = OfficePalette.RESULT_BUBBLE_BORDER
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	# Text - use Control to properly clip
	var text_container = Control.new()
	text_container.position = bubble_bg.position
	text_container.size = bubble_bg.size
	text_container.clip_contents = true
	reaction_bubble.add_child(text_container)

	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = Vector2(8, 4)
	text_label.size = Vector2(bubble_bg.size.x - 16, 20)
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", OfficePalette.RESULT_BUBBLE_TEXT)
	text_label.clip_text = true
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_container.add_child(text_label)

	# Display time for completion phrase
	reaction_timer = 3.0
