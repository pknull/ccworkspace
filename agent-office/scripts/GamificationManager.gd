extends Node
class_name GamificationManager

# =============================================================================
# GAMIFICATION MANAGER - Achievement System Coordinator
# =============================================================================
# Manages achievements and achievement popups.
# Agent tracking is now handled by AgentRoster (owned by OfficeManager).

const AchievementPopupScript = preload("res://scripts/AchievementPopup.gd")

# Child components
var achievement_system: AchievementSystem

# Achievement popup queue
var popup_queue: Array = []
var current_popup: Node2D = null
var popup_container: CanvasLayer  # Render popups above everything

# Reference to AgentRoster (set by OfficeManager)
var agent_roster: AgentRoster = null

# Signals
signal achievement_unlocked(achievement_id: String)

func _ready() -> void:
	# Initialize achievement system
	achievement_system = AchievementSystem.new()
	add_child(achievement_system)

	# Create popup container (CanvasLayer to render above everything)
	popup_container = CanvasLayer.new()
	popup_container.layer = 100  # High layer to be on top
	add_child(popup_container)

	# Load persisted achievements
	achievement_system.load_achievements()

	# Connect achievement system signals
	achievement_system.achievement_unlocked.connect(_on_achievement_unlocked)

	# Disable _process by default - only enable when popups are queued
	set_process(false)

	print("[GamificationManager] Initialized with %d achievements unlocked" % [
		achievement_system.get_unlocked_count()
	])

func _process(_delta: float) -> void:
	_process_popup_queue()

	# Disable processing when queue is empty and no popup is showing
	if popup_queue.is_empty() and current_popup == null:
		set_process(false)

# =============================================================================
# ROSTER INTEGRATION
# =============================================================================

func set_agent_roster(roster: AgentRoster) -> void:
	agent_roster = roster
	if agent_roster:
		# Connect to roster signals for achievement checking
		agent_roster.roster_changed.connect(_on_roster_changed)
		agent_roster.agent_level_up.connect(_on_agent_level_up)

func _on_roster_changed() -> void:
	# Check achievements when roster data changes
	_check_achievements()

func _on_agent_level_up(_profile: AgentProfile, _new_level: int) -> void:
	# Could trigger level-up achievements here
	pass

# =============================================================================
# ACHIEVEMENT CHECKING
# =============================================================================

func _check_achievements() -> void:
	if not agent_roster:
		return

	var total_agents = agent_roster.get_agent_count()
	var total_tasks = _get_total_tasks_from_roster()
	var total_time = _get_total_work_time_from_roster()

	# Agent count achievements
	achievement_system.check_achievement("diverse_team", total_agents)
	achievement_system.check_achievement("full_house", total_agents)

	# Task count achievements
	achievement_system.check_achievement("first_task", total_tasks)
	achievement_system.check_achievement("ten_tasks", total_tasks)
	achievement_system.check_achievement("fifty_tasks", total_tasks)
	achievement_system.check_achievement("hundred_tasks", total_tasks)
	achievement_system.check_achievement("five_hundred_tasks", total_tasks)

	# Work time achievements (in seconds)
	achievement_system.check_achievement("dedication", total_time)
	achievement_system.check_achievement("workaholic", total_time)
	achievement_system.check_achievement("marathon", total_time)

func _get_total_tasks_from_roster() -> int:
	if not agent_roster:
		return 0
	var total = 0
	for profile in agent_roster.get_all_agents():
		total += profile.tasks_completed
	return total

func _get_total_work_time_from_roster() -> float:
	if not agent_roster:
		return 0.0
	var total = 0.0
	for profile in agent_roster.get_all_agents():
		total += profile.total_work_time_seconds
	return total

# =============================================================================
# ACHIEVEMENT POPUP HANDLING
# =============================================================================

func _on_achievement_unlocked(achievement_id: String) -> void:
	var achievement = achievement_system.get_achievement(achievement_id)
	if achievement:
		popup_queue.append(achievement)
		set_process(true)  # Enable processing to show popup
		achievement_unlocked.emit(achievement_id)
		print("[GamificationManager] Achievement unlocked: %s" % achievement.name)

func _process_popup_queue() -> void:
	# If no current popup and queue has items, show next popup
	if current_popup == null and not popup_queue.is_empty():
		var achievement = popup_queue.pop_front()
		_show_achievement_popup(achievement)

func _show_achievement_popup(achievement: AchievementSystem.Achievement) -> void:
	current_popup = AchievementPopupScript.new()
	current_popup.popup_finished.connect(_on_popup_finished)
	popup_container.add_child(current_popup)  # Must add to tree before setup() so _ready() creates labels
	current_popup.setup(achievement.name, achievement.description, achievement.icon)

func _on_popup_finished() -> void:
	if current_popup:
		current_popup.queue_free()
		current_popup = null

# =============================================================================
# PERSISTENCE
# =============================================================================

func save_all() -> void:
	achievement_system.save_achievements()
	print("[GamificationManager] Achievements saved")

# =============================================================================
# PUBLIC API
# =============================================================================

func get_stats_summary() -> Dictionary:
	var total_agents = agent_roster.get_agent_count() if agent_roster else 0
	var total_tasks = _get_total_tasks_from_roster()
	var total_time = _get_total_work_time_from_roster()

	return {
		"total_agents": total_agents,
		"total_tasks": total_tasks,
		"total_work_time": total_time,
		"achievements_unlocked": achievement_system.get_unlocked_count(),
		"achievements_total": achievement_system.get_total_count(),
	}
