extends Node
class_name AgentRoster

# =============================================================================
# AGENT ROSTER - Named Agent Management
# =============================================================================
# Manages the stable of named agents, handles hiring, assignment, and persistence.
# Each agent has their own profile file in user://stable/

const STABLE_DIR: String = "user://stable"
const INDEX_FILE: String = "user://stable/index.json"

# In-memory roster
var agents: Dictionary = {}  # id -> AgentProfile
var agents_by_name: Dictionary = {}  # name -> AgentProfile (for quick lookup)
var next_id: int = 1
var used_name_indices: Array[int] = []  # Track which names have been used

# Currently working agents (id -> true)
var working_agents: Dictionary = {}

# Signals
signal agent_hired(profile: AgentProfile)
signal agent_level_up(profile: AgentProfile, new_level: int)
signal roster_changed()

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_ensure_stable_dir()
	load_roster()

func _ensure_stable_dir() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("stable"):
		dir.make_dir("stable")

# =============================================================================
# PERSISTENCE
# =============================================================================

func load_roster() -> void:
	agents.clear()
	agents_by_name.clear()
	working_agents.clear()

	if not FileAccess.file_exists(INDEX_FILE):
		print("[AgentRoster] No roster found, starting fresh")
		return

	# Load index
	var file = FileAccess.open(INDEX_FILE, FileAccess.READ)
	if file == null:
		push_warning("[AgentRoster] Failed to open index file")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_warning("[AgentRoster] Failed to parse index JSON")
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[AgentRoster] Invalid index format")
		return

	next_id = data.get("next_id", 1)
	var agent_ids = data.get("agents", [])
	used_name_indices = []
	for idx in data.get("used_name_indices", []):
		used_name_indices.append(int(idx))

	# Load each agent profile
	print("[AgentRoster] Index lists %d agents: %s" % [agent_ids.size(), agent_ids])
	for agent_id in agent_ids:
		var profile = _load_agent_profile(int(agent_id))
		if profile:
			agents[profile.id] = profile
			agents_by_name[profile.agent_name] = profile
			print("[AgentRoster] Loaded: %s (id=%d)" % [profile.agent_name, profile.id])
		else:
			print("[AgentRoster] FAILED to load agent id=%d" % agent_id)

	print("[AgentRoster] Loaded %d agents" % agents.size())
	_cleanup_orphaned_relationships()
	roster_changed.emit()

func _load_agent_profile(agent_id: int) -> AgentProfile:
	var path = "%s/agent_%03d.json" % [STABLE_DIR, agent_id]
	if not FileAccess.file_exists(path):
		push_warning("[AgentRoster] Profile not found: %s" % path)
		return null

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		return null

	return AgentProfile.from_dict(json.data)

func _cleanup_orphaned_relationships() -> void:
	# Remove chat/work records referencing agents that no longer exist
	var valid_ids: Array = []
	for id in agents.keys():
		valid_ids.append(id)
	var cleaned_count = 0

	for agent in agents.values():
		# Clean chatted_with
		var orphaned_chats: Array = []
		for id_key in agent.chatted_with.keys():
			var id_int = int(id_key) if id_key is String else id_key
			if id_int not in valid_ids:
				orphaned_chats.append(id_key)
		for id_key in orphaned_chats:
			agent.chatted_with.erase(id_key)
			cleaned_count += 1

		# Clean worked_with
		var orphaned_work: Array = []
		for id_key in agent.worked_with.keys():
			var id_int = int(id_key) if id_key is String else id_key
			if id_int not in valid_ids:
				orphaned_work.append(id_key)
		for id_key in orphaned_work:
			agent.worked_with.erase(id_key)
			cleaned_count += 1

	if cleaned_count > 0:
		print("[AgentRoster] Cleaned %d orphaned relationship records" % cleaned_count)
		# Save cleaned data
		for agent in agents.values():
			save_profile(agent)

func save_roster() -> void:
	_ensure_stable_dir()

	# Save index
	var agent_ids: Array = []
	for id in agents.keys():
		agent_ids.append(id)

	var index_data = {
		"version": 2,
		"next_id": next_id,
		"agents": agent_ids,
		"used_name_indices": used_name_indices,
		"saved_at": AgentProfile._get_iso_timestamp(),
	}

	var index_json = JSON.stringify(index_data, "\t")
	var file = FileAccess.open(INDEX_FILE, FileAccess.WRITE)
	if file:
		file.store_string(index_json)
		file.close()

	# Save each agent profile
	for profile in agents.values():
		save_profile(profile)

	print("[AgentRoster] Saved %d agents" % agents.size())

func save_profile(profile: AgentProfile) -> void:
	var path = "%s/agent_%03d.json" % [STABLE_DIR, profile.id]
	var json_string = JSON.stringify(profile.to_dict(), "\t")

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

# =============================================================================
# AGENT HIRING & ASSIGNMENT
# =============================================================================

func hire_agent() -> AgentProfile:
	# Generate a new agent with unique name
	var name = _generate_unique_name()
	var profile = AgentProfile.new(next_id, name)
	next_id += 1

	agents[profile.id] = profile
	agents_by_name[profile.agent_name] = profile

	print("[AgentRoster] Hired new agent: %s (#%d)" % [profile.agent_name, profile.id])
	agent_hired.emit(profile)
	roster_changed.emit()

	# Save immediately
	save_profile(profile)
	save_roster()

	return profile

func _generate_unique_name() -> String:
	# Find an unused name from the pool
	for i in range(AgentProfile.NAMES.size()):
		if i not in used_name_indices:
			used_name_indices.append(i)
			return AgentProfile.NAMES[i]

	# All names used - generate numbered name
	var count = used_name_indices.size() - AgentProfile.NAMES.size() + 1
	return "Agent_%d" % count

func assign_agent_for_task(is_orchestrator: bool = false) -> AgentProfile:
	# For orchestrator: assign highest level/XP agent
	# For regular task: assign random available agent, or hire if all busy

	if is_orchestrator:
		return _assign_best_agent()
	else:
		return _assign_available_agent()

func _assign_best_agent() -> AgentProfile:
	# Find highest level agent that's not already working (XP as tiebreaker)
	var best_profile: AgentProfile = null
	var best_level: int = -1
	var best_xp: int = -1

	for profile in agents.values():
		# Skip agents that are already working
		if working_agents.has(profile.id):
			continue
		if profile.level > best_level or (profile.level == best_level and profile.xp > best_xp):
			best_profile = profile
			best_level = profile.level
			best_xp = profile.xp

	if best_profile == null:
		# All agents busy or no agents yet - hire new one
		best_profile = hire_agent()

	working_agents[best_profile.id] = true
	return best_profile

func _assign_available_agent() -> AgentProfile:
	# Find idle agents
	var idle_agents: Array[AgentProfile] = []
	for profile in agents.values():
		if not working_agents.has(profile.id):
			idle_agents.append(profile)

	if idle_agents.is_empty():
		# All busy - hire new agent
		var new_agent = hire_agent()
		working_agents[new_agent.id] = true
		return new_agent

	# Pick random idle agent
	var chosen = idle_agents[randi() % idle_agents.size()]
	working_agents[chosen.id] = true
	return chosen

func release_agent(agent_id: int) -> void:
	working_agents.erase(agent_id)

func is_working(agent_id: int) -> bool:
	return working_agents.has(agent_id)

func fire_agent(agent_id: int) -> bool:
	if not agents.has(agent_id):
		return false
	if working_agents.has(agent_id):
		push_warning("[AgentRoster] Cannot fire agent %d while working" % agent_id)
		return false

	var profile = agents[agent_id]
	agents.erase(agent_id)
	agents_by_name.erase(profile.agent_name)
	working_agents.erase(agent_id)

	var name_index = AgentProfile.NAMES.find(profile.agent_name)
	if name_index != -1 and name_index in used_name_indices:
		used_name_indices.erase(name_index)

	var path = "%s/agent_%03d.json" % [STABLE_DIR, profile.id]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	save_roster()
	roster_changed.emit()
	print("[AgentRoster] Fired agent: %s (#%d)" % [profile.agent_name, profile.id])
	return true

# =============================================================================
# STATS UPDATES (with level-up detection)
# =============================================================================

func record_task_completed(agent_id: int, skill_name: String, work_time: float) -> void:
	if not agents.has(agent_id):
		push_warning("[AgentRoster] record_task_completed: agent %d not found!" % agent_id)
		return

	var profile = agents[agent_id]
	var new_level = profile.add_task_completed(skill_name, work_time)
	if OfficeConstants.DEBUG_TOOL_TRACKING:
		print("[AgentRoster] Task completed for %s (id=%d): tools=%s" % [profile.agent_name, agent_id, str(profile.tools)])

	if new_level > 0:
		agent_level_up.emit(profile, new_level)

	save_profile(profile)
	roster_changed.emit()

func record_task_failed(agent_id: int, skill_name: String, work_time: float) -> void:
	if not agents.has(agent_id):
		return

	var profile = agents[agent_id]
	profile.add_task_failed(skill_name, work_time)
	save_profile(profile)
	roster_changed.emit()

func record_tool_use(agent_id: int, tool_name: String) -> void:
	if not agents.has(agent_id):
		print("[AgentRoster] WARNING: record_tool_use for unknown agent %d" % agent_id)
		return

	var profile = agents[agent_id]
	var new_level = profile.add_tool_use(tool_name)
	print("[AgentRoster] %s used tool: %s (total: %d)" % [profile.agent_name, tool_name, profile.get_total_tool_uses()])

	if new_level > 0:
		agent_level_up.emit(profile, new_level)

	# Don't save on every tool use - too frequent
	roster_changed.emit()

func record_chat(agent_a_id: int, agent_b_id: int) -> void:
	if not agents.has(agent_a_id) or not agents.has(agent_b_id):
		return

	var profile_a = agents[agent_a_id]
	var profile_b = agents[agent_b_id]

	var new_level_a = profile_a.add_chat(agent_b_id)
	var new_level_b = profile_b.add_chat(agent_a_id)

	if new_level_a > 0:
		agent_level_up.emit(profile_a, new_level_a)
	if new_level_b > 0:
		agent_level_up.emit(profile_b, new_level_b)

	roster_changed.emit()

func record_worked_with(agent_id: int, other_agent_id: int) -> void:
	if not agents.has(agent_id) or not agents.has(other_agent_id):
		return
	if agent_id == other_agent_id:
		return

	agents[agent_id].add_worked_with(other_agent_id)
	agents[other_agent_id].add_worked_with(agent_id)

func record_orchestrator_session(agent_id: int) -> void:
	if not agents.has(agent_id):
		return

	var profile = agents[agent_id]
	var new_level = profile.add_orchestrator_session()

	if new_level > 0:
		agent_level_up.emit(profile, new_level)

	save_profile(profile)
	roster_changed.emit()

# =============================================================================
# QUERIES
# =============================================================================

func get_agent(agent_id: int) -> AgentProfile:
	return agents.get(agent_id, null)

func get_agent_by_name(name: String) -> AgentProfile:
	return agents_by_name.get(name, null)

func get_all_agents() -> Array[AgentProfile]:
	var result: Array[AgentProfile] = []
	result.assign(agents.values())
	return result

func get_agents_sorted_by_xp() -> Array[AgentProfile]:
	var result: Array[AgentProfile] = get_all_agents()
	result.sort_custom(func(a, b): return a.xp > b.xp)
	return result

func get_top_agent() -> AgentProfile:
	var sorted = get_agents_sorted_by_xp()
	return sorted[0] if not sorted.is_empty() else null

func get_agent_count() -> int:
	return agents.size()

func get_idle_agent_count() -> int:
	return agents.size() - working_agents.size()
