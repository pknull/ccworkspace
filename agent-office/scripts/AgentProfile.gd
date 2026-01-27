extends RefCounted
class_name AgentProfile

# =============================================================================
# AGENT PROFILE - Individual Agent Data
# =============================================================================
# Represents a single named agent in the roster with all their stats,
# skills, appearance, and progression data.

# Name pool for generating agent names
const NAMES: Array[String] = [
	"Alex", "Jordan", "Sam", "Taylor", "Morgan", "Casey", "Jamie", "Riley",
	"Quinn", "Avery", "Dakota", "Skyler", "Parker", "Cameron", "Drew", "Finley",
	"Hayden", "Kendall", "Logan", "Peyton", "Reese", "Rowan", "Sage", "Spencer",
	"Blake", "Charlie", "Emery", "Frankie", "Gray", "Harper", "Jesse", "Kit",
	"Lane", "Max", "Nico", "Phoenix", "Ray", "Scout", "Tatum", "Val",
	"Winter", "Ash", "Bailey", "Ellis", "Flynn", "Glenn", "Hunter", "Indigo",
	"Jules", "Kerry", "Lee", "Marley", "Nat", "Oakley", "Pat", "Robin",
	"Shannon", "Terry", "Wren", "Zion"
]

# Level thresholds and titles
const LEVEL_THRESHOLDS: Array[int] = [0, 500, 1500, 4000, 8000, 15000, 30000, 50000]
const LEVEL_TITLES: Array[String] = [
	"Intern", "Junior", "Associate", "Senior", "Lead", "Principal", "Staff", "Distinguished"
]

# XP rewards
const XP_TASK_COMPLETED: int = 100
const XP_TOOL_CALL: int = 5
const XP_CHAT: int = 20
const XP_WORK_MINUTE: int = 1
const XP_ORCHESTRATOR_SESSION: int = 50

# =============================================================================
# PROFILE DATA
# =============================================================================

var id: int = 0
var agent_name: String = ""
var hired_at: String = ""
var last_seen: String = ""

# Appearance (persistent)
var is_female: bool = false  # true = blouse, false = shirt+tie
var hair_color_index: int = 0
var skin_color_index: int = 0
var hair_style_index: int = 0
var blouse_color_index: int = 0  # top color (blouse or tie)
var bottom_type: int = 0  # 0 = pants, 1 = skirt
var bottom_color_index: int = 0

# Progression
var xp: int = 0
var level: int = 1

# Stats
var tasks_completed: int = 0
var total_work_time_seconds: float = 0.0
var orchestrator_sessions: int = 0

# Skills (agent_type -> {tasks: int, time: float})
var skills: Dictionary = {}

# Tools (tool_name -> count)
var tools: Dictionary = {}

# Relationships (agent_id as string -> count)
var worked_with: Dictionary = {}
var chatted_with: Dictionary = {}

# Current badges held (calculated, not persisted)
var badges: Array[String] = []

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(p_id: int = 0, p_name: String = "") -> void:
	id = p_id
	agent_name = p_name
	hired_at = _get_iso_timestamp()
	last_seen = hired_at

	# Randomize appearance
	is_female = randf() < 0.5  # 50% blouse, 50% shirt+tie
	hair_color_index = randi_range(0, 5)
	skin_color_index = randi_range(0, 4)
	hair_style_index = randi_range(0, 3)
	blouse_color_index = randi_range(0, 3)
	bottom_type = randi_range(0, 1)  # 0 = pants, 1 = skirt
	bottom_color_index = randi_range(0, 3)

static func _get_iso_timestamp() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

# =============================================================================
# LEVEL & TITLE
# =============================================================================

func get_title() -> String:
	return LEVEL_TITLES[min(level - 1, LEVEL_TITLES.size() - 1)]

func get_xp_for_next_level() -> int:
	if level >= LEVEL_THRESHOLDS.size():
		return -1  # Max level
	return LEVEL_THRESHOLDS[level]

func get_xp_progress() -> float:
	# Returns 0.0 to 1.0 progress toward next level
	if level >= LEVEL_THRESHOLDS.size():
		return 1.0  # Max level

	var current_threshold = LEVEL_THRESHOLDS[level - 1]
	var next_threshold = LEVEL_THRESHOLDS[level]
	var xp_in_level = xp - current_threshold
	var xp_needed = next_threshold - current_threshold

	return float(xp_in_level) / float(xp_needed)

func _recalculate_level() -> int:
	# Returns new level (may be same as current)
	var old_level = level

	for i in range(LEVEL_THRESHOLDS.size() - 1, -1, -1):
		if xp >= LEVEL_THRESHOLDS[i]:
			level = i + 1
			break

	return level if level != old_level else 0  # Return new level or 0 if unchanged

# =============================================================================
# XP & STATS UPDATES
# =============================================================================

func add_task_completed(skill_name: String, work_time: float) -> int:
	# Returns new level if leveled up, 0 otherwise
	tasks_completed += 1
	total_work_time_seconds += work_time
	last_seen = _get_iso_timestamp()

	# Update skill
	if not skills.has(skill_name):
		skills[skill_name] = {"tasks": 0, "time": 0.0}
	skills[skill_name]["tasks"] += 1
	skills[skill_name]["time"] += work_time

	# Add XP
	var xp_gained = XP_TASK_COMPLETED + int(work_time / 60.0) * XP_WORK_MINUTE
	xp += xp_gained

	return _recalculate_level()

func add_tool_use(tool_name: String) -> int:
	# Returns new level if leveled up, 0 otherwise
	if not tools.has(tool_name):
		tools[tool_name] = 0
	tools[tool_name] += 1

	xp += XP_TOOL_CALL
	return _recalculate_level()

func add_chat(other_agent_id: int) -> int:
	# Returns new level if leveled up, 0 otherwise
	var key = str(other_agent_id)
	if not chatted_with.has(key):
		chatted_with[key] = 0
	chatted_with[key] += 1

	xp += XP_CHAT
	return _recalculate_level()

func add_worked_with(other_agent_id: int) -> void:
	var key = str(other_agent_id)
	if not worked_with.has(key):
		worked_with[key] = 0
	worked_with[key] += 1

func add_orchestrator_session() -> int:
	# Returns new level if leveled up, 0 otherwise
	orchestrator_sessions += 1
	xp += XP_ORCHESTRATOR_SESSION
	return _recalculate_level()

# =============================================================================
# STATS QUERIES
# =============================================================================

func get_total_tool_uses() -> int:
	var total = 0
	for count in tools.values():
		total += count
	return total

func get_total_chats() -> int:
	var total = 0
	for count in chatted_with.values():
		total += count
	return total

func get_unique_colleagues_count() -> int:
	return worked_with.size()

func get_unique_skills_count() -> int:
	return skills.size()

func get_work_time_hours() -> float:
	return total_work_time_seconds / 3600.0

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": agent_name,
		"hired_at": hired_at,
		"last_seen": last_seen,
		"appearance": {
			"is_female": is_female,
			"hair_color_index": hair_color_index,
			"skin_color_index": skin_color_index,
			"hair_style_index": hair_style_index,
			"blouse_color_index": blouse_color_index,
			"bottom_type": bottom_type,
			"bottom_color_index": bottom_color_index,
		},
		"progression": {
			"xp": xp,
			"level": level,
		},
		"stats": {
			"tasks_completed": tasks_completed,
			"total_work_time_seconds": total_work_time_seconds,
			"orchestrator_sessions": orchestrator_sessions,
		},
		"skills": skills,
		"tools": tools,
		"relationships": {
			"worked_with": worked_with,
			"chatted_with": chatted_with,
		},
	}

static func from_dict(data: Dictionary) -> AgentProfile:
	var profile = AgentProfile.new()

	profile.id = data.get("id", 0)
	profile.agent_name = data.get("name", "Unknown")
	profile.hired_at = data.get("hired_at", _get_iso_timestamp())
	profile.last_seen = data.get("last_seen", profile.hired_at)

	var appearance = data.get("appearance", {})
	profile.is_female = appearance.get("is_female", false)
	profile.hair_color_index = appearance.get("hair_color_index", 0)
	profile.skin_color_index = appearance.get("skin_color_index", 0)
	profile.hair_style_index = appearance.get("hair_style_index", 0)
	profile.blouse_color_index = appearance.get("blouse_color_index", 0)
	# New fields with backwards compatibility (migrate from old encoding)
	if appearance.has("bottom_type"):
		profile.bottom_type = appearance.get("bottom_type", 0)
		profile.bottom_color_index = appearance.get("bottom_color_index", 0)
	else:
		# Migrate from old encoding: blouse_color_index % 2 == 0 meant skirt
		profile.bottom_type = 1 if (profile.is_female and profile.blouse_color_index % 2 == 0) else 0
		profile.bottom_color_index = 0

	var progression = data.get("progression", {})
	profile.xp = progression.get("xp", 0)
	profile.level = progression.get("level", 1)

	var stats = data.get("stats", {})
	profile.tasks_completed = stats.get("tasks_completed", 0)
	profile.total_work_time_seconds = stats.get("total_work_time_seconds", 0.0)
	profile.orchestrator_sessions = stats.get("orchestrator_sessions", 0)

	profile.skills = data.get("skills", {})
	profile.tools = data.get("tools", {})

	var relationships = data.get("relationships", {})
	profile.worked_with = relationships.get("worked_with", {})
	profile.chatted_with = relationships.get("chatted_with", {})

	return profile
