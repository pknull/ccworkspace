extends Node
class_name TranscriptWatcher

signal event_received(event_data: Dictionary)
signal context_updated(session_path: String, context_percent: float)

const CLAUDE_PROJECTS_DIR = "/.claude/projects"
const ESTIMATED_MAX_CONTEXT_BYTES = 800000  # ~200K tokens * 4 chars/token
const CODEX_SESSIONS_DIR = "/.codex/sessions"
const CODEX_MAX_SCAN_DEPTH = 3  # root + YYYY/MM/DD
const POLL_INTERVAL = OfficeConstants.TRANSCRIPT_POLL_INTERVAL
const SCAN_INTERVAL = 1.0  # seconds - how often to scan for new sessions (fast to catch subagent sessions)
const ACTIVE_THRESHOLD = 300  # seconds - consider sessions active if modified within this time (longer than SESSION_INACTIVE_TIMEOUT)
const PENDING_AGENT_TIMEOUT = 1800  # seconds - consider pending agents stale after this long without updates
const WATCHER_CONFIG_FILE = "user://watchers.json"

# Context window settings
const CONTEXT_WINDOW_SECONDS = 600.0  # 10 minutes - entries older than this are pruned
const CONTEXT_PRUNE_INTERVAL = 5.0  # seconds between prune checks

# Harness enable/disable configuration
var harness_enabled: Dictionary = {
	"claude": true,
	"codex": true
}
var harness_paths: Dictionary = {
	"claude": "",
	"codex": ""
}

# Track multiple sessions
var watched_sessions: Dictionary = {}  # file_path -> {position: int, last_modified: int}
var session_context_entries: Dictionary = {}  # file_path -> Array of {time: float, size: int}
var context_prune_timer: float = 0.0
var poll_timer: float = 0.0
var scan_timer: float = 0.0

# Track tool_use_id -> agent info for matching with tool_result
var pending_agents: Dictionary = {}  # tool_use_id -> {agent_type, description, session_path, created_at}

# Track ALL pending tool calls - any tool can require permission
var pending_tools: Dictionary = {}  # tool_use_id -> {tool_name, session_path}

func _ready() -> void:
	_register_with_settings()
	# Find and start watching all active sessions
	scan_for_sessions()

func _register_with_settings() -> void:
	var registry = get_node_or_null("/root/SettingsRegistry")
	if not registry:
		_load_config()
		return

	var schema: Array = [
		{"key": "claude_enabled", "type": "bool", "default": true, "description": "Enable Claude transcript watcher"},
		{"key": "codex_enabled", "type": "bool", "default": true, "description": "Enable Codex transcript watcher"},
		{"key": "claude_path", "type": "string", "default": "", "description": "Custom path for Claude projects"},
		{"key": "codex_path", "type": "string", "default": "", "description": "Custom path for Codex sessions"}
	]

	registry.register_category("watchers", WATCHER_CONFIG_FILE, schema, _on_setting_changed)

	# Load values from registry with defaults
	var v_claude_en = registry.get_setting("watchers", "claude_enabled")
	harness_enabled["claude"] = v_claude_en if v_claude_en != null else true
	var v_codex_en = registry.get_setting("watchers", "codex_enabled")
	harness_enabled["codex"] = v_codex_en if v_codex_en != null else true
	var v_claude_path = registry.get_setting("watchers", "claude_path")
	harness_paths["claude"] = v_claude_path if v_claude_path != null else ""
	var v_codex_path = registry.get_setting("watchers", "codex_path")
	harness_paths["codex"] = v_codex_path if v_codex_path != null else ""

func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"claude_enabled":
			harness_enabled["claude"] = bool(value)
		"codex_enabled":
			harness_enabled["codex"] = bool(value)
		"claude_path":
			harness_paths["claude"] = str(value) if value != null else ""
		"codex_path":
			harness_paths["codex"] = str(value) if value != null else ""

func _load_config() -> void:
	if not FileAccess.file_exists(WATCHER_CONFIG_FILE):
		return
	var file = FileAccess.open(WATCHER_CONFIG_FILE, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data = json.get_data()
	if not data is Dictionary:
		return
	var harnesses = data.get("harnesses", {})
	if harnesses is Dictionary:
		for harness_name in harnesses.keys():
			var h = harnesses[harness_name]
			if h is Dictionary:
				if h.has("enabled"):
					harness_enabled[harness_name] = bool(h["enabled"])
				if h.has("path"):
					harness_paths[harness_name] = str(h["path"])

func save_config() -> void:
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		registry.save_category("watchers")
		return

	# Legacy save
	var data: Dictionary = {}
	if FileAccess.file_exists(WATCHER_CONFIG_FILE):
		var file = FileAccess.open(WATCHER_CONFIG_FILE, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				data = json.data
			file.close()

	data["version"] = 1
	data["harnesses"] = {}
	for harness_name in harness_enabled.keys():
		data["harnesses"][harness_name] = {
			"enabled": harness_enabled.get(harness_name, true),
			"path": harness_paths.get(harness_name, "")
		}

	var out = FileAccess.open(WATCHER_CONFIG_FILE, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(data, "\t"))
		out.close()

func get_harness_config() -> Dictionary:
	var result: Dictionary = {}
	for harness_name in harness_enabled.keys():
		result[harness_name] = {
			"enabled": harness_enabled.get(harness_name, true),
			"path": harness_paths.get(harness_name, "")
		}
	return result

func set_harness_enabled(harness: String, enabled: bool) -> void:
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		registry.set_setting("watchers", harness + "_enabled", enabled)
	else:
		harness_enabled[harness] = enabled

func set_harness_path(harness: String, path: String) -> void:
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		registry.set_setting("watchers", harness + "_path", path)
	else:
		harness_paths[harness] = path

func get_harness_summary() -> Dictionary:
	var summary: Dictionary = {}
	for harness_name in harness_enabled.keys():
		var active_count = 0
		for path in watched_sessions.keys():
			if _derive_harness(path) == harness_name:
				active_count += 1
		summary[harness_name] = {
			"enabled": harness_enabled.get(harness_name, true),
			"active_sessions": active_count
		}
	return summary

func get_context_percent(session_path: String) -> float:
	var bytes = _sum_context_bytes(session_path)
	return clampf(float(bytes) / ESTIMATED_MAX_CONTEXT_BYTES, 0.0, 1.0)

func reset_context_tracking(session_path: String) -> void:
	session_context_entries.erase(session_path)

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

	# Prune old context entries and update percentages
	context_prune_timer += delta
	if context_prune_timer >= CONTEXT_PRUNE_INTERVAL:
		context_prune_timer = 0.0
		_prune_context_entries()

func _prune_context_entries() -> void:
	var current_time = Time.get_unix_time_from_system()
	var cutoff_time = current_time - CONTEXT_WINDOW_SECONDS

	for session_path in session_context_entries.keys():
		var entries: Array = session_context_entries[session_path]
		var original_size = entries.size()

		# Remove entries older than the window
		var new_entries: Array = []
		for entry in entries:
			if entry.time >= cutoff_time:
				new_entries.append(entry)
		session_context_entries[session_path] = new_entries

		# If entries were pruned, emit updated percentage
		if new_entries.size() != original_size:
			context_updated.emit(session_path, get_context_percent(session_path))

func _sum_context_bytes(session_path: String) -> int:
	var entries: Array = session_context_entries.get(session_path, [])
	var total: int = 0
	for entry in entries:
		total += entry.size
	return mini(total, ESTIMATED_MAX_CONTEXT_BYTES)  # Cap at max

func scan_for_sessions() -> void:
	var current_time = Time.get_unix_time_from_system()

	if harness_enabled.get("claude", true):
		_scan_claude_sessions(current_time)
	if harness_enabled.get("codex", true):
		_scan_codex_sessions(current_time)
	_remove_stale_sessions(current_time)

func _scan_claude_sessions(current_time: float) -> void:
	var custom_path = harness_paths.get("claude", "")
	var projects_dir: String
	if not custom_path.is_empty():
		projects_dir = custom_path
	else:
		var home_dir = OS.get_environment("HOME")
		projects_dir = home_dir + CLAUDE_PROJECTS_DIR

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

func _scan_codex_sessions(current_time: float) -> void:
	var sessions_dir = _get_codex_sessions_dir()
	var dir = DirAccess.open(sessions_dir)
	if not dir:
		return
	_scan_jsonl_recursive(sessions_dir, current_time, CODEX_MAX_SCAN_DEPTH)

func _scan_jsonl_recursive(dir_path: String, current_time: float, depth: int) -> void:
	if depth < 0:
		return
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry_name = dir.get_next()
	while entry_name != "":
		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue
		var entry_path = dir_path + "/" + entry_name
		if dir.current_is_dir():
			_scan_jsonl_recursive(entry_path, current_time, depth - 1)
		elif entry_name.ends_with(".jsonl"):
			var mod_time = FileAccess.get_modified_time(entry_path)
			if current_time - mod_time < ACTIVE_THRESHOLD:
				if not watched_sessions.has(entry_path):
					start_watching_session(entry_path)
		entry_name = dir.get_next()
	dir.list_dir_end()

func _get_codex_sessions_dir() -> String:
	var custom_path = harness_paths.get("codex", "")
	if not custom_path.is_empty():
		return custom_path
	var codex_home = OS.get_environment("CODEX_HOME")
	if codex_home.is_empty():
		var home_dir = OS.get_environment("HOME")
		codex_home = home_dir + "/.codex"
	return codex_home + "/sessions"

func _remove_stale_sessions(current_time: float) -> void:
	# Remove stale sessions (not modified recently AND no pending agents)
	var to_remove: Array[String] = []
	for path in watched_sessions.keys():
		var mod_time = FileAccess.get_modified_time(path)
		if current_time - mod_time > ACTIVE_THRESHOLD:
			# Only remove if no pending agents from this session
			if not session_has_pending_agents(path, current_time):
				to_remove.append(path)

	for path in to_remove:
		print("[TranscriptWatcher] Stopped watching inactive: %s" % path.get_file())
		var session_id = _derive_session_id(path)
		var harness = _derive_harness(path)
		_cleanup_pending_for_session(path)
		watched_sessions.erase(path)
		# Emit session_end so orchestrator can take a break
		event_received.emit({
			"event": "session_end",
			"session_id": session_id,
			"session_path": path,
			"harness_id": harness,
			"harness_label": harness.capitalize() if harness else "",
			"timestamp": Time.get_datetime_string_from_system()
		})

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

		# Emit session_start event so orchestrator (Claude) appears (deferred to ensure signal is connected)
		var session_id = _derive_session_id(file_path)
		call_deferred("_emit_session_start", session_id, file_path)
	else:
		push_warning("[TranscriptWatcher] Cannot open: %s" % file_path)

func _emit_session_start(session_id: String, session_path: String) -> void:
	var harness = _derive_harness(session_path)
	event_received.emit({
		"event": "session_start",
		"session_id": session_id,
		"session_path": session_path,
		"harness_id": harness,
		"harness_label": harness.capitalize() if harness else "",
		"timestamp": Time.get_datetime_string_from_system()
	})

func check_all_sessions() -> void:
	for file_path in watched_sessions.keys():
		check_session_for_entries(file_path)

func check_session_for_entries(file_path: String) -> void:
	var session = watched_sessions[file_path]

	# Check if file was modified since last check - avoid unnecessary file opens
	var current_mod_time = FileAccess.get_modified_time(file_path)
	if current_mod_time == session.get("last_modified", 0):
		return  # File hasn't changed, skip opening it

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	# Update last modified time
	watched_sessions[file_path].last_modified = current_mod_time

	# Seek to where we left off
	file.seek(session.position)

	# Read new lines
	var had_content = false
	while not file.eof_reached():
		var line = file.get_line()
		if line.strip_edges().is_empty():
			continue
		had_content = true
		process_line(line, file_path)

	# Update position
	watched_sessions[file_path].position = file.get_position()
	file.close()

	# Emit session_activity so OfficeManager can respawn missing orchestrators
	if had_content:
		var session_id = _derive_session_id(file_path)
		var harness = _derive_harness(file_path)
		event_received.emit({
			"event": "session_activity",
			"session_id": session_id,
			"session_path": file_path,
			"harness_id": harness,
			"harness_label": harness.capitalize() if harness else "",
			"timestamp": Time.get_datetime_string_from_system()
		})

func process_line(line: String, session_path: String = "") -> void:
	var json = JSON.new()
	var error = json.parse(line)
	if error != OK:
		push_warning("[TranscriptWatcher] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	var entry = json.data
	if not entry is Dictionary:
		return

	# Track context usage with sliding window (approximate bytes for context meter)
	if not session_path.is_empty():
		var line_bytes = line.length()
		if not session_context_entries.has(session_path):
			session_context_entries[session_path] = []
		session_context_entries[session_path].append({
			"time": Time.get_unix_time_from_system(),
			"size": line_bytes
		})
		context_updated.emit(session_path, get_context_percent(session_path))

	if _process_codex_entry(entry, session_path):
		return

	# Check for /exit, /quit, or /compact commands in user messages
	var entry_type = entry.get("type", "")
	if entry_type == "user":
		var user_message = entry.get("message", {})
		if user_message is Dictionary:
			var user_content = user_message.get("content", "")
			if user_content is String:
				# Check for exit/quit
				if user_content.contains("<command-name>/exit</command-name>") or \
				   user_content.contains("<command-name>/quit</command-name>"):
					var session_id = _derive_session_id(session_path)
					var harness = _derive_harness(session_path)
					print("[TranscriptWatcher] EXIT detected for session: %s" % session_id)
					event_received.emit({
						"event": "session_exit",
						"session_id": session_id,
						"session_path": session_path,
						"harness_id": harness,
						"harness_label": harness.capitalize() if harness else "",
						"timestamp": entry.get("timestamp", Time.get_datetime_string_from_system())
					})
					return  # Don't process further for exit commands
				# Check for /compact - reset context tracking
				if user_content.contains("<command-name>/compact</command-name>"):
					print("[TranscriptWatcher] COMPACT detected for session: %s" % _derive_session_id(session_path))
					session_context_entries[session_path] = []
					context_updated.emit(session_path, 0.0)

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

func _process_codex_entry(entry: Dictionary, session_path: String) -> bool:
	var entry_type = entry.get("type", "")
	if entry_type == "response_item":
		var payload = entry.get("payload", {})
		if not payload is Dictionary:
			return true
		var payload_type = payload.get("type", "")
		if payload_type == "function_call":
			_process_codex_tool_use(payload, entry, session_path)
		elif payload_type == "function_call_output":
			_process_codex_tool_result(payload, entry)
		return true
	if entry_type == "session_meta" or entry_type == "event_msg" or entry_type == "turn_context":
		return true
	return false

func _process_codex_tool_use(payload: Dictionary, entry: Dictionary, session_path: String) -> void:
	var tool_name = payload.get("name", "")
	var tool_id = payload.get("call_id", "")
	var tool_input = _parse_codex_tool_input(payload.get("arguments", {}))
	var timestamp = entry.get("timestamp", "")

	var item = {
		"name": tool_name,
		"id": tool_id,
		"input": tool_input
	}
	var normalized_entry = {"timestamp": timestamp}
	process_tool_use(item, normalized_entry, session_path)

func _process_codex_tool_result(payload: Dictionary, entry: Dictionary) -> void:
	var tool_use_id = payload.get("call_id", "")
	var timestamp = entry.get("timestamp", "")
	var output = payload.get("output", "")

	var item = {
		"tool_use_id": tool_use_id,
		"content": output,
		"is_error": false
	}
	var normalized_entry = {"timestamp": timestamp}
	process_tool_result(item, normalized_entry)

func _parse_codex_tool_input(raw_args) -> Dictionary:
	if raw_args is Dictionary:
		return raw_args
	if raw_args is String:
		var json = JSON.new()
		if json.parse(raw_args) == OK and json.data is Dictionary:
			return json.data
		return {"raw": raw_args}
	return {"raw": str(raw_args)}

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
			"session_path": session_path,
			"created_at": Time.get_unix_time_from_system()
		}

		print("[TranscriptWatcher] SPAWN: %s - %s (id: %s)" % [agent_type, description, tool_id.substr(0, 12)])

		var harness = _derive_harness(session_path)
		event_received.emit({
			"event": "agent_spawn",
			"agent_id": tool_id.substr(0, 12),  # Use 12 chars to reduce collision risk
			"agent_type": agent_type,
			"description": description,
			"parent_id": "main",
			"timestamp": timestamp,
			"session_path": session_path,
			"harness_id": harness,
			"harness_label": harness.capitalize() if harness else ""
		})
	else:
		# ALL tools can potentially wait for permission - track them all
		pending_tools[tool_id] = {
			"tool_name": tool_name,
			"session_path": session_path
		}

		# Build tool description for display
		var tool_desc = ""
		match tool_name:
			"Bash", "shell":
				tool_desc = str(tool_input.get("description", tool_input.get("command", "")))
			"Read", "Edit", "Write":
				tool_desc = str(tool_input.get("file_path", ""))
			"Glob", "Grep":
				tool_desc = str(tool_input.get("pattern", ""))

		if tool_desc:
			tool_desc = tool_desc.substr(0, 50)

		print("[TranscriptWatcher] TOOL: %s (id: %s)" % [tool_name, tool_id.substr(0, 12)])

		var harness = _derive_harness(session_path)
		# Emit waiting_for_input - monitor turns red until result comes back
		event_received.emit({
			"event": "waiting_for_input",
			"agent_id": "main",
			"tool": tool_name,
			"description": tool_desc,
			"timestamp": timestamp,
			"session_path": session_path,
			"harness_id": harness,
			"harness_label": harness.capitalize() if harness else ""
		})

func process_tool_result(item: Dictionary, entry: Dictionary) -> void:
	var tool_use_id = item.get("tool_use_id", "")
	var timestamp = entry.get("timestamp", "")

	# Check if this completes a pending agent
	if pending_agents.has(tool_use_id):
		var agent_info = pending_agents[tool_use_id]
		pending_agents.erase(tool_use_id)

		# Extract the result content - handle both string and array formats
		var raw_content = item.get("content", "")
		var result_content = ""

		if raw_content is String:
			result_content = raw_content
		elif raw_content is Array:
			# Content can be an array of content blocks - extract text
			for block in raw_content:
				if block is Dictionary:
					if block.get("type") == "text":
						result_content += block.get("text", "")
					elif block.has("text"):
						result_content += str(block.get("text", ""))
				elif block is String:
					result_content += block
		else:
			result_content = str(raw_content)

		var is_error = item.get("is_error", false)

		# Truncate long results for display (keep first ~200 chars)
		var display_result = result_content.strip_edges()
		if display_result.length() > 200:
			display_result = display_result.substr(0, 197) + "..."

		print("[TranscriptWatcher] COMPLETE: %s - %s (id: %s) result=%s" % [agent_info.agent_type, agent_info.description, tool_use_id.substr(0, 12), display_result.substr(0, 50)])

		event_received.emit({
			"event": "agent_complete",
			"agent_id": tool_use_id.substr(0, 12),  # Match spawn ID length
			"success": str(not is_error),
			"result": display_result,
			"timestamp": timestamp
		})

	# Check if this clears a waiting state (tool completed)
	if pending_tools.has(tool_use_id):
		var tool_info = pending_tools[tool_use_id]
		pending_tools.erase(tool_use_id)

		print("[TranscriptWatcher] TOOL DONE: %s (id: %s)" % [tool_info.tool_name, tool_use_id.substr(0, 12)])

		event_received.emit({
			"event": "input_received",
			"agent_id": "main",
			"tool": tool_info.tool_name,
			"timestamp": timestamp,
			"session_path": tool_info.session_path
		})

func session_has_pending_agents(session_path: String, current_time: float = -1.0) -> bool:
	var now = current_time
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	for tool_id in pending_agents.keys():
		var agent_info = pending_agents[tool_id]
		if agent_info.get("session_path", "") == session_path:
			var created_at = float(agent_info.get("created_at", 0))
			if created_at > 0 and (now - created_at) <= PENDING_AGENT_TIMEOUT:
				return true
	return false

func _cleanup_pending_for_session(session_path: String) -> void:
	var agent_keys: Array = []
	for tool_id in pending_agents.keys():
		var agent_info = pending_agents[tool_id]
		if agent_info.get("session_path", "") == session_path:
			agent_keys.append(tool_id)
	for tool_id in agent_keys:
		pending_agents.erase(tool_id)

	var tool_keys: Array = []
	for tool_id in pending_tools.keys():
		var tool_info = pending_tools[tool_id]
		if tool_info.get("session_path", "") == session_path:
			tool_keys.append(tool_id)
	for tool_id in tool_keys:
		pending_tools.erase(tool_id)

func _derive_session_id(file_path: String) -> String:
	var basename = file_path.get_file().get_basename()
	if basename.begins_with("rollout-"):
		var trimmed = basename.substr(8)
		if not trimmed.is_empty():
			return trimmed
	return basename

func _derive_harness(session_path: String) -> String:
	# Determine if this is a claude or codex session based on path
	if session_path.contains("/.claude/"):
		return "claude"
	elif session_path.contains("/.codex/"):
		return "codex"
	return ""

func get_watched_count() -> int:
	return watched_sessions.size()
