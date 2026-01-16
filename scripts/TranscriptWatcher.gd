extends Node
class_name TranscriptWatcher

signal event_received(event_data: Dictionary)

const CLAUDE_PROJECTS_DIR = "/.claude/projects"
const POLL_INTERVAL = 0.5  # seconds

var watching_file: String = ""
var file_handle: FileAccess = null
var file_position: int = 0
var poll_timer: float = 0.0

# Track tool_use_id -> agent info for matching with tool_result
var pending_agents: Dictionary = {}  # tool_use_id -> {agent_type, description}

func _ready() -> void:
	# Find and start watching the most recent session
	var session_file = find_latest_session()
	if session_file:
		start_watching(session_file)
	else:
		push_warning("[TranscriptWatcher] No session file found")

func _process(delta: float) -> void:
	if watching_file.is_empty():
		return

	poll_timer += delta
	if poll_timer >= POLL_INTERVAL:
		poll_timer = 0.0
		check_for_new_entries()

func find_latest_session() -> String:
	var home_dir = OS.get_environment("HOME")
	var projects_dir = home_dir + CLAUDE_PROJECTS_DIR

	var dir = DirAccess.open(projects_dir)
	if not dir:
		push_warning("[TranscriptWatcher] Cannot open: %s" % projects_dir)
		return ""

	var latest_file = ""
	var latest_time = 0

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
						if mod_time > latest_time:
							latest_time = mod_time
							latest_file = full_path
					file_name = subdir.get_next()
				subdir.list_dir_end()
		subdir_name = dir.get_next()
	dir.list_dir_end()

	return latest_file

func start_watching(file_path: String) -> void:
	watching_file = file_path

	# Open file and seek to end
	file_handle = FileAccess.open(file_path, FileAccess.READ)
	if file_handle:
		file_handle.seek_end(0)
		file_position = file_handle.get_position()
		print("[TranscriptWatcher] Watching: %s" % file_path.get_file())
	else:
		push_warning("[TranscriptWatcher] Cannot open: %s" % file_path)

func check_for_new_entries() -> void:
	if not file_handle:
		return

	# Reopen file to get fresh content (file might have grown)
	file_handle.close()
	file_handle = FileAccess.open(watching_file, FileAccess.READ)
	if not file_handle:
		return

	# Seek to where we left off
	file_handle.seek(file_position)

	# Read new lines
	while not file_handle.eof_reached():
		var line = file_handle.get_line()
		if line.strip_edges().is_empty():
			continue
		process_line(line)

	file_position = file_handle.get_position()

func process_line(line: String) -> void:
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
			process_tool_use(item, entry)
		elif item_type == "tool_result":
			process_tool_result(item, entry)

func process_tool_use(item: Dictionary, entry: Dictionary) -> void:
	var tool_name = item.get("name", "")
	var tool_id = item.get("id", "")
	var tool_input = item.get("input", {})
	var timestamp = entry.get("timestamp", "")

	if tool_name == "Task":
		# Agent spawn
		var agent_type = tool_input.get("subagent_type", "default")
		var description = tool_input.get("description", "")

		# Store for matching with result
		pending_agents[tool_id] = {
			"agent_type": agent_type,
			"description": description
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

func switch_session(session_id: String) -> void:
	# Allow manually switching to a specific session
	var home_dir = OS.get_environment("HOME")
	var projects_dir = home_dir + CLAUDE_PROJECTS_DIR

	var dir = DirAccess.open(projects_dir)
	if not dir:
		return

	dir.list_dir_begin()
	var subdir_name = dir.get_next()
	while subdir_name != "":
		if dir.current_is_dir():
			var file_path = projects_dir + "/" + subdir_name + "/" + session_id + ".jsonl"
			if FileAccess.file_exists(file_path):
				if file_handle:
					file_handle.close()
				pending_agents.clear()
				start_watching(file_path)
				return
		subdir_name = dir.get_next()
	dir.list_dir_end()

	push_warning("[TranscriptWatcher] Session not found: %s" % session_id)
