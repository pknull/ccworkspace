extends Node
class_name AchievementSystem

# =============================================================================
# ACHIEVEMENT SYSTEM
# =============================================================================
# Manages achievement definitions, unlock conditions, and persistence

const ACHIEVEMENTS_FILE: String = "user://achievements.json"

# Category definitions (single source of truth)
const CATEGORY_ORDER: Array[String] = ["tasks", "time", "social", "cat", "tools", "milestones"]
const CATEGORY_NAMES: Dictionary = {
	"tasks": "Task Completion",
	"time": "Work Time",
	"social": "Social",
	"cat": "Cat Lover",
	"tools": "Tool Usage",
	"milestones": "Milestones",
}

# Achievement data
var achievements: Dictionary = {}  # achievement_id -> Achievement
var unlocked: Dictionary = {}  # achievement_id -> unlock_timestamp

# Signals
signal achievement_unlocked(achievement_id: String)

# =============================================================================
# DATA STRUCTURES
# =============================================================================

class Achievement:
	var id: String
	var name: String
	var description: String
	var icon: String  # Emoji or text icon
	var category: String  # "tasks", "time", "social", "tools", "milestones"
	var threshold: float  # Value needed to unlock
	var is_unlocked: bool = false
	var unlocked_at: String = ""

	func _init(p_id: String, p_name: String, p_desc: String, p_icon: String, p_category: String, p_threshold: float) -> void:
		id = p_id
		name = p_name
		description = p_desc
		icon = p_icon
		category = p_category
		threshold = p_threshold

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"is_unlocked": is_unlocked,
			"unlocked_at": unlocked_at,
		}

	func load_state(data: Dictionary) -> void:
		is_unlocked = data.get("is_unlocked", false)
		unlocked_at = data.get("unlocked_at", "")

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_define_achievements()

func _define_achievements() -> void:
	# Task completion achievements
	_add_achievement("first_task", "First Steps", "Complete your first task", "[1]", "tasks", 1)
	_add_achievement("ten_tasks", "Getting Started", "Complete 10 tasks", "[10]", "tasks", 10)
	_add_achievement("fifty_tasks", "Making Progress", "Complete 50 tasks", "[50]", "tasks", 50)
	_add_achievement("hundred_tasks", "Seasoned Worker", "Complete 100 tasks", "[C]", "tasks", 100)
	_add_achievement("five_hundred_tasks", "Veteran", "Complete 500 tasks", "[D]", "tasks", 500)

	# Work time achievements (in seconds)
	_add_achievement("dedication", "Dedication", "Accumulate 1 hour of work time", "[T]", "time", 3600)  # 1 hour
	_add_achievement("workaholic", "Workaholic", "Accumulate 5 hours of work time", "[W]", "time", 18000)  # 5 hours
	_add_achievement("marathon", "Marathon", "Accumulate 24 hours of work time", "[M]", "time", 86400)  # 24 hours

	# Agent diversity achievements
	_add_achievement("diverse_team", "Diverse Team", "See 5 unique agent types", "[5]", "milestones", 5)
	_add_achievement("full_house", "Full House", "See 10 unique agent types", "[X]", "milestones", 10)

	# Social achievements
	_add_achievement("first_chat", "Water Cooler Talk", "Witness your first agent chat", "[*]", "social", 1)
	_add_achievement("social_butterfly", "Social Butterfly", "Witness 10 agent chats", "[B]", "social", 10)
	_add_achievement("office_gossip", "Office Gossip", "Witness 50 agent chats", "[G]", "social", 50)

	# Tool usage achievements
	_add_achievement("tool_explorer", "Tool Explorer", "See 5 different tools used", "[E]", "tools", 5)
	_add_achievement("tool_master", "Tool Master", "See 10 different tools used", "[!]", "tools", 10)

	# Cat achievements
	_add_achievement("cat_petter", "Cat Petter", "Witness an agent interact with the cat", "[=^.^=]", "cat", 1)
	_add_achievement("cat_friend", "Cat Friend", "Witness 10 agent-cat interactions", "[=^w^=]", "cat", 10)
	_add_achievement("crazy_cat_office", "Crazy Cat Office", "Witness 50 agent-cat interactions", "[=^o^=]", "cat", 50)

	# Speed achievements (task duration in seconds)
	_add_achievement("quick_task", "Quick Task", "Complete a task in under 30 seconds", "[>]", "tasks", 1)
	_add_achievement("lightning_fast", "Lightning Fast", "Complete a task in under 10 seconds", "[>>]", "tasks", 1)
	_add_achievement("speed_demon", "Speed Demon", "Complete 10 quick tasks (under 30s)", "[>>>]", "tasks", 10)

func _add_achievement(id: String, name: String, desc: String, icon: String, category: String, threshold: float) -> void:
	achievements[id] = Achievement.new(id, name, desc, icon, category, threshold)

# =============================================================================
# PERSISTENCE
# =============================================================================

func load_achievements() -> void:
	if not FileAccess.file_exists(ACHIEVEMENTS_FILE):
		print("[AchievementSystem] No saved achievements found")
		return

	var file = FileAccess.open(ACHIEVEMENTS_FILE, FileAccess.READ)
	if file == null:
		push_warning("[AchievementSystem] Failed to open achievements file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_warning("[AchievementSystem] Failed to parse achievements JSON")
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	var unlocked_data = data.get("unlocked", {})
	for achievement_id in unlocked_data.keys():
		if achievements.has(achievement_id):
			achievements[achievement_id].load_state(unlocked_data[achievement_id])
			if achievements[achievement_id].is_unlocked:
				unlocked[achievement_id] = achievements[achievement_id].unlocked_at

	print("[AchievementSystem] Loaded %d unlocked achievements" % unlocked.size())

func save_achievements() -> void:
	var unlocked_data = {}
	for achievement_id in achievements.keys():
		if achievements[achievement_id].is_unlocked:
			unlocked_data[achievement_id] = achievements[achievement_id].to_dict()

	var data = {
		"version": 1,
		"saved_at": AgentStable.AgentRecord._get_iso_timestamp(),
		"unlocked": unlocked_data,
	}

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(ACHIEVEMENTS_FILE, FileAccess.WRITE)
	if file == null:
		push_warning("[AchievementSystem] Failed to save achievements")
		return

	file.store_string(json_string)
	file.close()
	print("[AchievementSystem] Saved %d unlocked achievements" % unlocked_data.size())

# =============================================================================
# ACHIEVEMENT CHECKING
# =============================================================================

func check_achievement(achievement_id: String, current_value: float) -> bool:
	if not achievements.has(achievement_id):
		return false

	var achievement = achievements[achievement_id]
	if achievement.is_unlocked:
		return false  # Already unlocked

	if current_value >= achievement.threshold:
		_unlock_achievement(achievement_id)
		return true

	return false

func _unlock_achievement(achievement_id: String) -> void:
	if not achievements.has(achievement_id):
		return

	var achievement = achievements[achievement_id]
	achievement.is_unlocked = true
	achievement.unlocked_at = AgentStable.AgentRecord._get_iso_timestamp()
	unlocked[achievement_id] = achievement.unlocked_at

	achievement_unlocked.emit(achievement_id)
	# Note: Saving is handled by GamificationManager on window close to avoid
	# multiple disk writes when several achievements unlock in quick succession

# =============================================================================
# PUBLIC API
# =============================================================================

func get_achievement(achievement_id: String) -> Achievement:
	return achievements.get(achievement_id, null)

func get_all_achievements() -> Array[Achievement]:
	var result: Array[Achievement] = []
	result.assign(achievements.values())
	return result

func get_achievements_by_category(category: String) -> Array[Achievement]:
	var result: Array[Achievement] = []
	for achievement in achievements.values():
		if achievement.category == category:
			result.append(achievement)
	return result

func get_unlocked_achievements() -> Array[Achievement]:
	var result: Array[Achievement] = []
	for achievement in achievements.values():
		if achievement.is_unlocked:
			result.append(achievement)
	return result

func get_locked_achievements() -> Array[Achievement]:
	var result: Array[Achievement] = []
	for achievement in achievements.values():
		if not achievement.is_unlocked:
			result.append(achievement)
	return result

func get_unlocked_count() -> int:
	return unlocked.size()

func get_total_count() -> int:
	return achievements.size()

func get_progress_percent() -> float:
	if achievements.size() == 0:
		return 0.0
	return (float(unlocked.size()) / float(achievements.size())) * 100.0

func is_unlocked(achievement_id: String) -> bool:
	return unlocked.has(achievement_id)
