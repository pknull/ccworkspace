extends Node
class_name BadgeSystem

# =============================================================================
# BADGE SYSTEM - Competitive Titles
# =============================================================================
# Calculates which agent currently holds each badge based on stats.
# Badges move between agents as stats change.

# Badge definitions
const BADGES = {
	"top_performer": {
		"name": "Top Performer",
		"icon": "[T]",
		"description": "Most tasks completed"
	},
	"workaholic": {
		"name": "Workaholic",
		"icon": "[W]",
		"description": "Most work time"
	},
	"social_butterfly": {
		"name": "Social Butterfly",
		"icon": "[S]",
		"description": "Most chats with colleagues"
	},
	"bash_expert": {
		"name": "Bash Expert",
		"icon": "[B]",
		"description": "Most Bash tool uses"
	},
	"code_reader": {
		"name": "Code Reader",
		"icon": "[R]",
		"description": "Most Read tool uses"
	},
	"editor_pro": {
		"name": "Editor Pro",
		"icon": "[E]",
		"description": "Most Edit tool uses"
	},
	"search_master": {
		"name": "Search Master",
		"icon": "[?]",
		"description": "Most Grep/Glob uses"
	},
	"team_lead": {
		"name": "Team Lead",
		"icon": "[L]",
		"description": "Most orchestrator sessions"
	},
	"versatile": {
		"name": "Versatile",
		"icon": "[V]",
		"description": "Most different skills used"
	},
	"connector": {
		"name": "Connector",
		"icon": "[C]",
		"description": "Worked with most colleagues"
	},
}

# Current badge holders (badge_id -> agent_id)
var badge_holders: Dictionary = {}

# Reference to roster
var roster: AgentRoster = null

# Signals
signal badge_changed(badge_id: String, old_holder_id: int, new_holder_id: int)

# =============================================================================
# INITIALIZATION
# =============================================================================

func setup(agent_roster: AgentRoster) -> void:
	roster = agent_roster
	roster.roster_changed.connect(_on_roster_changed)
	recalculate_all_badges()

func _on_roster_changed() -> void:
	recalculate_all_badges()

# =============================================================================
# BADGE CALCULATION
# =============================================================================

func recalculate_all_badges() -> void:
	if roster == null:
		return

	var agents = roster.get_all_agents()
	if agents.is_empty():
		badge_holders.clear()
		return

	# Calculate each badge
	_calculate_badge("top_performer", agents, func(a): return a.tasks_completed)
	_calculate_badge("workaholic", agents, func(a): return a.total_work_time_seconds)
	_calculate_badge("social_butterfly", agents, func(a): return a.get_total_chats())
	_calculate_badge("bash_expert", agents, func(a): return a.tools.get("Bash", 0))
	_calculate_badge("code_reader", agents, func(a): return a.tools.get("Read", 0))
	_calculate_badge("editor_pro", agents, func(a): return a.tools.get("Edit", 0))
	_calculate_badge("search_master", agents, func(a): return a.tools.get("Grep", 0) + a.tools.get("Glob", 0))
	_calculate_badge("team_lead", agents, func(a): return a.orchestrator_sessions)
	_calculate_badge("versatile", agents, func(a): return a.get_unique_skills_count())
	_calculate_badge("connector", agents, func(a): return a.get_unique_colleagues_count())

	# Update badge arrays on each agent
	_update_agent_badges(agents)

func _calculate_badge(badge_id: String, agents: Array[AgentProfile], value_getter: Callable) -> void:
	var best_agent: AgentProfile = null
	var best_value: float = -1

	for agent in agents:
		var value = value_getter.call(agent)
		if value > best_value:
			best_value = value
			best_agent = agent

	# Only award badge if value > 0
	if best_agent and best_value > 0:
		var old_holder = badge_holders.get(badge_id, -1)
		var new_holder = best_agent.id

		if old_holder != new_holder:
			badge_holders[badge_id] = new_holder
			badge_changed.emit(badge_id, old_holder, new_holder)
	else:
		badge_holders.erase(badge_id)

func _update_agent_badges(agents: Array[AgentProfile]) -> void:
	# Clear all agent badges first
	for agent in agents:
		agent.badges.clear()

	# Assign badges based on current holders
	for badge_id in badge_holders.keys():
		var holder_id = badge_holders[badge_id]
		var agent = roster.get_agent(holder_id)
		if agent:
			agent.badges.append(badge_id)

# =============================================================================
# QUERIES
# =============================================================================

func get_badge_holder(badge_id: String) -> AgentProfile:
	if not badge_holders.has(badge_id):
		return null
	return roster.get_agent(badge_holders[badge_id])

func get_badge_info(badge_id: String) -> Dictionary:
	return BADGES.get(badge_id, {})

func get_all_badge_ids() -> Array:
	return BADGES.keys()

func get_agent_badges(agent_id: int) -> Array[String]:
	var result: Array[String] = []
	for badge_id in badge_holders.keys():
		if badge_holders[badge_id] == agent_id:
			result.append(badge_id)
	return result
