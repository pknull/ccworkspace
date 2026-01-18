extends Node
class_name AgentStable

# =============================================================================
# AGENT STABLE - Persistent Agent Records
# =============================================================================
# Manages CRUD operations for persistent agent records stored in user://
# Each unique agent_type becomes a persistent "character" tracked across sessions

const STABLE_FILE: String = "user://agent_stable.json"

# In-memory cache of all agent records
var agents: Dictionary = {}  # agent_type -> AgentRecord

# Signal emitted when stable data changes
signal agent_updated(agent_type: String)
signal stable_loaded()
signal stable_saved()

# =============================================================================
# DATA STRUCTURES
# =============================================================================

class AgentRecord:
	var agent_type: String = ""
	var display_name: String = ""
	var tasks_completed: int = 0
	var tasks_failed: int = 0
	var total_work_time_seconds: float = 0.0
	var tools_used: Dictionary = {}  # tool_name -> count
	var first_seen: String = ""  # ISO 8601 timestamp
	var last_seen: String = ""   # ISO 8601 timestamp
	var session_count: int = 0
	var worked_with: Dictionary = {}  # agent_type -> count
	var chatted_with: Dictionary = {}  # agent_type -> count
	# Visual identity (persistent across sessions)
	var is_female: bool = false
	var hair_color_index: int = 0
	var skin_color_index: int = 0
	var hair_style_index: int = 0  # For female agents
	var blouse_color_index: int = 0  # For female agents

	func _init(type: String = "") -> void:
		agent_type = type
		display_name = _generate_display_name(type)
		first_seen = _get_iso_timestamp()
		last_seen = first_seen

	static func _generate_display_name(type: String) -> String:
		# Convert agent_type to readable name: "full-stack-developer" -> "Full Stack Developer"
		var label = type.replace("-", " ").replace("_", " ")
		var words = label.split(" ")
		var capitalized: Array[String] = []
		for word in words:
			if word.length() > 0:
				capitalized.append(word[0].to_upper() + word.substr(1))
		return " ".join(capitalized)

	static func _get_iso_timestamp() -> String:
		var datetime = Time.get_datetime_dict_from_system()
		return "%04d-%02d-%02dT%02d:%02d:%02d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second
		]

	func to_dict() -> Dictionary:
		return {
			"agent_type": agent_type,
			"display_name": display_name,
			"tasks_completed": tasks_completed,
			"tasks_failed": tasks_failed,
			"total_work_time_seconds": total_work_time_seconds,
			"tools_used": tools_used,
			"first_seen": first_seen,
			"last_seen": last_seen,
			"session_count": session_count,
			"worked_with": worked_with,
			"chatted_with": chatted_with,
			"is_female": is_female,
			"hair_color_index": hair_color_index,
			"skin_color_index": skin_color_index,
			"hair_style_index": hair_style_index,
			"blouse_color_index": blouse_color_index,
		}

	static func from_dict(data: Dictionary) -> AgentRecord:
		var record = AgentRecord.new(data.get("agent_type", ""))
		record.display_name = data.get("display_name", record.display_name)
		record.tasks_completed = data.get("tasks_completed", 0)
		record.tasks_failed = data.get("tasks_failed", 0)
		record.total_work_time_seconds = data.get("total_work_time_seconds", 0.0)
		record.tools_used = data.get("tools_used", {})
		record.first_seen = data.get("first_seen", record.first_seen)
		record.last_seen = data.get("last_seen", record.last_seen)
		record.session_count = data.get("session_count", 0)
		record.worked_with = data.get("worked_with", {})
		record.chatted_with = data.get("chatted_with", {})
		record.is_female = data.get("is_female", false)
		record.hair_color_index = data.get("hair_color_index", 0)
		record.skin_color_index = data.get("skin_color_index", 0)
		record.hair_style_index = data.get("hair_style_index", 0)
		record.blouse_color_index = data.get("blouse_color_index", 0)
		return record

# =============================================================================
# PERSISTENCE
# =============================================================================

func load_stable() -> void:
	agents.clear()

	if not FileAccess.file_exists(STABLE_FILE):
		print("[AgentStable] No saved stable found, starting fresh")
		stable_loaded.emit()
		return

	var file = FileAccess.open(STABLE_FILE, FileAccess.READ)
	if file == null:
		push_warning("[AgentStable] Failed to open stable file: %s" % FileAccess.get_open_error())
		stable_loaded.emit()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_warning("[AgentStable] Failed to parse stable JSON: %s" % json.get_error_message())
		stable_loaded.emit()
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[AgentStable] Invalid stable file format")
		stable_loaded.emit()
		return

	var agents_data = data.get("agents", {})
	for agent_type in agents_data.keys():
		var record = AgentRecord.from_dict(agents_data[agent_type])
		agents[agent_type] = record

	print("[AgentStable] Loaded %d agent records" % agents.size())
	stable_loaded.emit()

func save_stable() -> void:
	var agents_data = {}
	for agent_type in agents.keys():
		agents_data[agent_type] = agents[agent_type].to_dict()

	var data = {
		"version": 1,
		"saved_at": AgentRecord._get_iso_timestamp(),
		"agents": agents_data,
	}

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(STABLE_FILE, FileAccess.WRITE)
	if file == null:
		push_warning("[AgentStable] Failed to save stable: %s" % FileAccess.get_open_error())
		return

	file.store_string(json_string)
	file.close()
	print("[AgentStable] Saved %d agent records" % agents.size())
	stable_saved.emit()

# =============================================================================
# CRUD OPERATIONS
# =============================================================================

func get_or_create_agent(agent_type: String) -> AgentRecord:
	if agent_type.is_empty():
		push_warning("[AgentStable] Cannot create agent with empty type")
		return null

	if agents.has(agent_type):
		return agents[agent_type]

	# Create new record with randomized appearance
	var record = AgentRecord.new(agent_type)
	record.is_female = randf() < 0.5
	record.hair_color_index = randi_range(0, 5)
	record.skin_color_index = randi_range(0, 4)
	record.hair_style_index = randi_range(0, 2)
	record.blouse_color_index = randi_range(0, 3)

	agents[agent_type] = record
	print("[AgentStable] Created new agent record: %s" % agent_type)
	return record

func get_agent(agent_type: String) -> AgentRecord:
	return agents.get(agent_type, null)

func get_all_agents() -> Array[AgentRecord]:
	var result: Array[AgentRecord] = []
	result.assign(agents.values())
	return result

func get_agent_count() -> int:
	return agents.size()

# =============================================================================
# STATISTICS UPDATES
# =============================================================================

func record_spawn(agent_type: String) -> AgentRecord:
	var record = get_or_create_agent(agent_type)
	if record == null:
		return null

	record.session_count += 1
	record.last_seen = AgentRecord._get_iso_timestamp()
	agent_updated.emit(agent_type)
	return record

func record_completion(agent_type: String, work_time: float, success: bool = true) -> void:
	if agent_type.is_empty():
		return

	var record = get_agent(agent_type)
	if record == null:
		return

	if success:
		record.tasks_completed += 1
	else:
		record.tasks_failed += 1

	record.total_work_time_seconds += work_time
	record.last_seen = AgentRecord._get_iso_timestamp()
	agent_updated.emit(agent_type)

func record_tool_use(agent_type: String, tool_name: String) -> void:
	if agent_type.is_empty() or tool_name.is_empty():
		return

	var record = get_agent(agent_type)
	if record == null:
		return

	if not record.tools_used.has(tool_name):
		record.tools_used[tool_name] = 0
	record.tools_used[tool_name] += 1
	agent_updated.emit(agent_type)

func record_worked_with(agent_type: String, other_agent_type: String) -> void:
	if agent_type.is_empty() or other_agent_type.is_empty():
		return
	if agent_type == other_agent_type:
		return

	var record = get_agent(agent_type)
	if record == null:
		return

	if not record.worked_with.has(other_agent_type):
		record.worked_with[other_agent_type] = 0
	record.worked_with[other_agent_type] += 1
	agent_updated.emit(agent_type)

func record_chat(agent_type: String, other_agent_type: String) -> void:
	if agent_type.is_empty() or other_agent_type.is_empty():
		return
	if agent_type == other_agent_type:
		return

	var record = get_agent(agent_type)
	if record == null:
		return

	if not record.chatted_with.has(other_agent_type):
		record.chatted_with[other_agent_type] = 0
	record.chatted_with[other_agent_type] += 1
	agent_updated.emit(agent_type)

# =============================================================================
# STATISTICS QUERIES
# =============================================================================

func get_total_tasks_completed() -> int:
	var total = 0
	for record in agents.values():
		total += record.tasks_completed
	return total

func get_total_work_time() -> float:
	var total = 0.0
	for record in agents.values():
		total += record.total_work_time_seconds
	return total

func get_top_agents_by_tasks(limit: int = 5) -> Array[AgentRecord]:
	var sorted_agents: Array[AgentRecord] = []
	sorted_agents.assign(agents.values())
	sorted_agents.sort_custom(func(a, b): return a.tasks_completed > b.tasks_completed)
	return sorted_agents.slice(0, limit)

func get_top_agents_by_work_time(limit: int = 5) -> Array[AgentRecord]:
	var sorted_agents: Array[AgentRecord] = []
	sorted_agents.assign(agents.values())
	sorted_agents.sort_custom(func(a, b): return a.total_work_time_seconds > b.total_work_time_seconds)
	return sorted_agents.slice(0, limit)

func get_most_social_agents(limit: int = 5) -> Array[AgentRecord]:
	var sorted_agents: Array[AgentRecord] = []
	sorted_agents.assign(agents.values())
	sorted_agents.sort_custom(func(a, b):
		var a_chats = 0
		for count in a.chatted_with.values():
			a_chats += count
		var b_chats = 0
		for count in b.chatted_with.values():
			b_chats += count
		return a_chats > b_chats
	)
	return sorted_agents.slice(0, limit)

func get_tool_usage_stats() -> Dictionary:
	var tool_totals = {}
	for record in agents.values():
		for tool_name in record.tools_used.keys():
			if not tool_totals.has(tool_name):
				tool_totals[tool_name] = 0
			tool_totals[tool_name] += record.tools_used[tool_name]
	return tool_totals
