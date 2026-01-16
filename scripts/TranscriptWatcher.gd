extends Node
class_name TranscriptWatcher

signal event_received(event_data: Dictionary)

const CLAUDE_PROJECTS_DIR = "/.claude/projects"
const POLL_INTERVAL = 0.5  # seconds
const SCAN_INTERVAL = 5.0  # seconds - how often to scan for new sessions
const ACTIVE_THRESHOLD = 300  # seconds - consider sessions active if modified within this time

# Track multiple sessions
var watched_sessions: Dictionary = {}  # file_path -> {position: int, last_modified: int}
var poll_timer: float = 0.0
var scan_timer: float = 0.0

# Track tool_use_id -> agent info for matching with tool_result
var pending_agents: Dictionary = {}  # tool_use_id -> {agent_type, description, session_path}

func _ready() -> void:
	# Find and start watching all active sessions
	scan_for_sessions()

func _process(delta: float) -> void:
	# Poll existing sessions for new entries
	poll_timer += delta
	if poll_timer >= POLL_INTERVAL:
		poll_timer = 0.0
		check_all_sessions()

	# Periodically scan for new sessions
	scan_timer += delta
	if scan_timer >= SCAN_INTERVAL:
		scan_timer = 0.0
		scan_for_sessions()

func scan_for_sessions() -> void:
	var home_dir = OS.get_environment("HOME")
	var projects_dir = home_dir + CLAUDE_PROJECTS_DIR
	var current_time = Time.get_unix_time_from_system()

	var dir = DirAccess.open(projects_dir)
	if not dir:
		push_warning("[TranscriptWatcher] Cannot open: %s" % projects_dir)
		return

	# Search all project subdirectories
	dir.list_dir_begin()
	var subdir_name = dir.get_next()
	while subdir_name != "":
		if dir.current_is_dir() and not subdir_name.begins_with("."):
			var subdir_path = projects_dir + "/" + subdir_name
			var subdir = DirAccess.open(subdir_path)
			if subdir:
				subdir.list_dir_begin()
				var file_name = subdir.get_next()
				while file_name != "":
					if file_name.ends_with(".jsonl"):
						var full_path = subdir_path + "/" + file_name
						var mod_time = FileAccess.get_modified_time(full_path)

						# Only watch recently active sessions
						if current_time - mod_time < ACTIVE_THRESHOLD:
							if not watched_sessions.has(full_path):
								# New session - start watching from end
								start_watching_session(full_path)
					file_name = subdir.get_next()
				subdir.list_dir_end()
		subdir_name = dir.get_next()
	dir.list_dir_end()

	# Remove stale sessions (not modified recently AND no pending agents)
	var to_remove = []
	for path in watched_sessions.keys():
		var mod_time = FileAccess.get_modified_time(path)
		if current_time - mod_time > ACTIVE_THRESHOLD:
			# Only remove if no pending agents from this session
			if not session_has_pending_agents(path):
				to_remove.append(path)

	for path in to_remove:
		print("[TranscriptWatcher] Stopped watching inactive: %s" % path.get_file())
		watched_sessions.erase(path)

func start_watching_session(file_path: String) -> void:
	# Open file and seek to end
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		file.seek_end(0)
		watched_sessions[file_path] = {
			"position": file.get_position(),
			"last_modified": FileAccess.get_modified_time(file_path)
		}
		file.close()
		print("[TranscriptWatcher] Watching: %s" % file_path.get_file())
	else:
		push_warning("[TranscriptWatcher] Cannot open: %s" % file_path)

func check_all_sessions() -> void:
	for file_path in watched_sessions.keys():
		check_session_for_entries(file_path)

func check_session_for_entries(file_path: String) -> void:
	var session = watched_sessions[file_path]
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	# Seek to where we left off
	file.seek(session.position)

	# Read new lines
	while not file.eof_reached():
		var line = file.get_line()
		if line.strip_edges().is_empty():
			continue
		process_line(line, file_path)

	# Update position
	watched_sessions[file_path].position = file.get_position()
	file.close()

func process_line(line: String, session_path: String = "") -> void:
	var json = JSON.new()
	var error = json.parse(line)
	if error != OK:
		return

	var entry = json.data
	if not entry is Dictionary:
		return

	var message = entry.get("message", {})
	if not message is Dictionary:
		return

	var content = message.get("content", [])
	if not content is Array:
		return

	for item in content:
		if not item is Dictionary:
			continue

		var item_type = item.get("type", "")

		if item_type == "tool_use":
			process_tool_use(item, entry, session_path)
		elif item_type == "tool_result":
			process_tool_result(item, entry)

func process_tool_use(item: Dictionary, entry: Dictionary, session_path: String = "") -> void:
	var tool_name = item.get("name", "")
	var tool_id = item.get("id", "")
	var tool_input = item.get("input", {})
	var timestamp = entry.get("timestamp", "")

	if tool_name == "Task":
		# Agent spawn
		var agent_type = tool_input.get("subagent_type", "default")
		var description = tool_input.get("description", "")

		# Store for matching with result (including session for cleanup)
		pending_agents[tool_id] = {
			"agent_type": agent_type,
			"description": description,
			"session_path": session_path
		}

		print("[TranscriptWatcher] SPAWN: %s - %s" % [agent_type, description])

		event_received.emit({
			"event": "agent_spawn",
			"agent_id": tool_id.substr(0, 8),
			"agent_type": agent_type,
			"description": description,
			"parent_id": "main",
			"timestamp": timestamp
		})
	else:
		# Regular tool use
		var tool_desc = ""
		match tool_name:
			"Bash":
				tool_desc = str(tool_input.get("description", tool_input.get("command", "")))
			"Read":
				tool_desc = str(tool_input.get("file_path", ""))
			"Edit", "Write":
				tool_desc = str(tool_input.get("file_path", ""))
			"Glob", "Grep":
				tool_desc = str(tool_input.get("pattern", ""))

		if tool_desc:
			tool_desc = tool_desc.substr(0, 50)

		event_received.emit({
			"event": "tool_use",
			"agent_id": "main",
			"tool": tool_name,
			"description": tool_desc,
			"timestamp": timestamp
		})

func process_tool_result(item: Dictionary, entry: Dictionary) -> void:
	var tool_use_id = item.get("tool_use_id", "")
	var timestamp = entry.get("timestamp", "")

	# Check if this completes a pending agent
	if pending_agents.has(tool_use_id):
		var agent_info = pending_agents[tool_use_id]
		pending_agents.erase(tool_use_id)

		print("[TranscriptWatcher] COMPLETE: %s - %s" % [agent_info.agent_type, agent_info.description])

		event_received.emit({
			"event": "agent_complete",
			"agent_id": tool_use_id.substr(0, 8),
			"success": "true",
			"timestamp": timestamp
		})

func session_has_pending_agents(session_path: String) -> bool:
	for tool_id in pending_agents.keys():
		var agent_info = pending_agents[tool_id]
		if agent_info.get("session_path", "") == session_path:
			return true
	return false

func get_watched_count() -> int:
	return watched_sessions.size()
