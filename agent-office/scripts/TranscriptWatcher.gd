extends Node
class_name TranscriptWatcher

signal event_received(event_data: Dictionary)
signal context_updated(session_path: String, context_percent: float)

const CLAUDE_PROJECTS_DIR = "/.claude/projects"
const ESTIMATED_MAX_CONTEXT_BYTES = 800000  # ~200K tokens * 4 chars/token
const CODEX_SESSIONS_DIR = "/.codex/sessions"
const CODEX_MAX_SCAN_DEPTH = 3  # root + YYYY/MM/DD
const CLAWDBOT_SESSIONS_DIR = "/.clawdbot/agents"
const CLAWDBOT_MAX_SCAN_DEPTH = 3  # agents/<agent>/sessions/*.jsonl
const POLL_INTERVAL = OfficeConstants.TRANSCRIPT_POLL_INTERVAL
const SCAN_INTERVAL = 1.0  # seconds - how often to scan for new sessions (fast to catch subagent sessions)
const ACTIVE_THRESHOLD = 300  # seconds - consider sessions active if modified within this time (longer than SESSION_INACTIVE_TIMEOUT)
const PENDING_AGENT_TIMEOUT = 1800  # seconds - consider pending agents stale after this long without updates
const WATCHER_CONFIG_FILE = "user://watchers.json"
const MAX_BYTES_PER_POLL = 1048576
const MAX_LINE_BYTES = 262144
const MAX_CONTEXT_ENTRIES = 5000
const MAX_PENDING_ENTRIES = 10000
const MAX_WATCHED_SESSIONS = 256
const MAX_CODEX_SUBAGENTS = 1000
const MAX_BYTES_PER_POLL_CYCLE = 4194304
const MAX_POLL_MSEC = 50
const MAX_SCAN_ENTRIES = 5000
const MAX_SCAN_MSEC = 200
const REPLACEMENT_CHECKPOINT_BYTES = 128
const REPLACEMENT_HASH_BLOCK_BYTES = 65536
const MAX_CORRELATION_ID_CHARS = 256
const MAX_TYPE_CHARS = 128
const MAX_DESCRIPTION_CHARS = 2048
const MAX_STORED_PATH_CHARS = 4096

# Context window settings
const CONTEXT_WINDOW_SECONDS = 600.0  # 10 minutes - entries older than this are pruned
const CONTEXT_PRUNE_INTERVAL = 5.0  # seconds between prune checks

# Harness enable/disable configuration
var harness_enabled: Dictionary = {
	"claude": true,
	"codex": true,
	"clawdbot": true
}
var harness_paths: Dictionary = {
	"claude": "",
	"codex": "",
	"clawdbot": ""
}

# Track multiple sessions
var watched_sessions: Dictionary = {}  # file_path -> {position: int, last_modified: int}
var session_context_entries: Dictionary = {}  # file_path -> Array of {time: float, size: int}
var context_prune_timer: float = 0.0
var poll_timer: float = 0.0
var scan_timer: float = 0.0

static func _get_home_dir() -> String:
	if OS.get_name() == "Windows":
		var userprofile = OS.get_environment("USERPROFILE")
		if not userprofile.is_empty():
			return userprofile
		var homedrive = OS.get_environment("HOMEDRIVE")
		var homepath = OS.get_environment("HOMEPATH")
		if not homedrive.is_empty() and not homepath.is_empty():
			return homedrive + homepath
	return OS.get_environment("HOME")

# Track tool_use_id -> agent info for matching with tool_result
var pending_agents: Dictionary = {}  # tool_use_id -> {agent_type, description, session_path, created_at}

# Track ALL pending tool calls - any tool can require permission
var pending_tools: Dictionary = {}  # tool_use_id -> {tool_name, session_path}
var codex_subagents: Dictionary = {}  # thread id -> normalized agent metadata
var scan_entries: int = 0
var scan_deadline_msec: int = 0
var warned_missing_paths: Dictionary = {}
var poll_cursor: int = 0
var poll_bytes_remaining: int = -1
var poll_deadline_msec: int = 0
var session_limit_warned: bool = false
var scan_directory_cursors: Dictionary = {}
var verification_session_path: String = ""

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
		{"key": "clawdbot_enabled", "type": "bool", "default": true, "description": "Enable Clawdbot session watcher"},
		{"key": "claude_path", "type": "string", "default": "", "description": "Custom path for Claude projects"},
		{"key": "codex_path", "type": "string", "default": "", "description": "Custom path for Codex sessions"},
		{"key": "clawdbot_path", "type": "string", "default": "", "description": "Custom path for Clawdbot sessions"}
	]

	registry.register_category("watchers", WATCHER_CONFIG_FILE, schema, _on_setting_changed)

	# Load values from registry with defaults
	var v_claude_en = registry.get_setting("watchers", "claude_enabled")
	harness_enabled["claude"] = v_claude_en if v_claude_en != null else true
	var v_codex_en = registry.get_setting("watchers", "codex_enabled")
	harness_enabled["codex"] = v_codex_en if v_codex_en != null else true
	var v_clawdbot_en = registry.get_setting("watchers", "clawdbot_enabled")
	harness_enabled["clawdbot"] = v_clawdbot_en if v_clawdbot_en != null else true
	var v_claude_path = registry.get_setting("watchers", "claude_path")
	harness_paths["claude"] = _validated_custom_path(str(v_claude_path) if v_claude_path != null else "")
	var v_codex_path = registry.get_setting("watchers", "codex_path")
	harness_paths["codex"] = _validated_custom_path(str(v_codex_path) if v_codex_path != null else "")
	var v_clawdbot_path = registry.get_setting("watchers", "clawdbot_path")
	harness_paths["clawdbot"] = _validated_custom_path(str(v_clawdbot_path) if v_clawdbot_path != null else "")

func _on_setting_changed(key: String, value: Variant) -> void:
	var harness = key.trim_suffix("_enabled").trim_suffix("_path")
	match key:
		"claude_enabled":
			harness_enabled["claude"] = bool(value)
		"codex_enabled":
			harness_enabled["codex"] = bool(value)
		"clawdbot_enabled":
			harness_enabled["clawdbot"] = bool(value)
		"claude_path":
			harness_paths["claude"] = _validated_custom_path(str(value) if value != null else "")
		"codex_path":
			harness_paths["codex"] = _validated_custom_path(str(value) if value != null else "")
		"clawdbot_path":
			harness_paths["clawdbot"] = _validated_custom_path(str(value) if value != null else "")
	if harness_enabled.has(harness):
		_stop_watching_harness(harness)
		scan_for_sessions()

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

func set_harness_enabled(harness: String, enabled: bool) -> bool:
	if not harness_enabled.has(harness):
		return false
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		return registry.set_setting("watchers", harness + "_enabled", enabled)
	else:
		harness_enabled[harness] = enabled
		return true

func set_harness_path(harness: String, path: String) -> bool:
	if not harness_paths.has(harness):
		return false
	var validated = _validated_custom_path(path)
	if not path.strip_edges().is_empty() and validated.is_empty():
		return false
	var registry = get_node_or_null("/root/SettingsRegistry")
	if registry:
		return registry.set_setting("watchers", harness + "_path", validated)
	else:
		harness_paths[harness] = validated
		return true

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
			call_deferred("_emit_context_updated", session_path, get_context_percent(session_path))

func _sum_context_bytes(session_path: String) -> int:
	var entries: Array = session_context_entries.get(session_path, [])
	var total: int = 0
	for entry in entries:
		total += entry.size
	return mini(total, ESTIMATED_MAX_CONTEXT_BYTES)  # Cap at max

func scan_for_sessions() -> void:
	var current_time = Time.get_unix_time_from_system()

	if harness_enabled.get("claude", true):
		_reset_scan_budget()
		_scan_claude_sessions(current_time)
	if harness_enabled.get("codex", true):
		_reset_scan_budget()
		_scan_codex_sessions(current_time)
	if harness_enabled.get("clawdbot", true):
		_reset_scan_budget()
		_scan_clawdbot_sessions(current_time)
	_remove_stale_sessions(current_time)

func _reset_scan_budget() -> void:
	scan_entries = 0
	scan_deadline_msec = Time.get_ticks_msec() + MAX_SCAN_MSEC / 3

func _scan_claude_sessions(current_time: float) -> void:
	var custom_path = harness_paths.get("claude", "")
	var projects_dir: String
	if not custom_path.is_empty():
		projects_dir = custom_path
	else:
		var home_dir = _get_home_dir()
		projects_dir = home_dir + CLAUDE_PROJECTS_DIR

	if not DirAccess.dir_exists_absolute(projects_dir):
		if not warned_missing_paths.has(projects_dir):
			warned_missing_paths[projects_dir] = true
			push_warning("[TranscriptWatcher] Cannot open: %s" % projects_dir)
		return
	warned_missing_paths.erase(projects_dir)
	_scan_jsonl_recursive(projects_dir, current_time, 1, "claude")

func _scan_codex_sessions(current_time: float) -> void:
	var sessions_dir = _get_codex_sessions_dir()
	var dir = DirAccess.open(sessions_dir)
	if not dir:
		return
	_scan_jsonl_recursive(sessions_dir, current_time, CODEX_MAX_SCAN_DEPTH, "codex")

func _scan_clawdbot_sessions(current_time: float) -> void:
	var sessions_dir = _get_clawdbot_sessions_dir()
	var dir = DirAccess.open(sessions_dir)
	if not dir:
		return
	# We only want to scan agent session folders under ~/.clawdbot/agents
	_scan_jsonl_recursive(sessions_dir, current_time, CLAWDBOT_MAX_SCAN_DEPTH, "clawdbot")

func _scan_jsonl_recursive(dir_path: String, current_time: float, depth: int, harness: String) -> void:
	if depth < 0 or scan_entries > MAX_SCAN_ENTRIES or Time.get_ticks_msec() >= scan_deadline_msec:
		return
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	var entries: Array = []
	for directory_name in dir.get_directories():
		if not directory_name.begins_with("."):
			entries.append({"name": directory_name, "directory": true})
	for file_name in dir.get_files():
		if not file_name.begins_with("."):
			entries.append({"name": file_name, "directory": false})
	if entries.is_empty():
		scan_directory_cursors.erase(dir_path)
		return
	var cursor = int(scan_directory_cursors.get(dir_path, 0)) % entries.size()
	var visited = 0
	while visited < entries.size():
		scan_entries += 1
		if scan_entries > MAX_SCAN_ENTRIES or Time.get_ticks_msec() >= scan_deadline_msec:
			break
		var entry: Dictionary = entries[(cursor + visited) % entries.size()]
		var entry_name = str(entry["name"])
		if entry_name.begins_with("."):
			visited += 1
			continue
		var entry_path = dir_path + "/" + entry_name
		if bool(entry["directory"]):
			_scan_jsonl_recursive(entry_path, current_time, depth - 1, harness)
		elif entry_name.ends_with(".jsonl"):
			var mod_time = FileAccess.get_modified_time(entry_path)
			if current_time - mod_time < ACTIVE_THRESHOLD:
				if not watched_sessions.has(entry_path):
					start_watching_session(entry_path, harness)
		visited += 1
	scan_directory_cursors[dir_path] = (cursor + maxi(1, visited)) % entries.size()

func _get_codex_sessions_dir() -> String:
	var custom_path = harness_paths.get("codex", "")
	if not custom_path.is_empty():
		return custom_path
	var codex_home = OS.get_environment("CODEX_HOME")
	if codex_home.is_empty():
		var home_dir = _get_home_dir()
		codex_home = home_dir + "/.codex"
	return codex_home + "/sessions"

func _get_clawdbot_sessions_dir() -> String:
	var custom_path = harness_paths.get("clawdbot", "")
	if not custom_path.is_empty():
		return custom_path
	var home_dir = _get_home_dir()
	return home_dir + CLAWDBOT_SESSIONS_DIR

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
		session_context_entries.erase(path)
		# Defer session_end emit to avoid synchronous cascade that can cause X11 threading issues
		call_deferred("_emit_session_end", session_id, path, harness)

func start_watching_session(file_path: String, harness: String = "") -> void:
	if watched_sessions.size() >= MAX_WATCHED_SESSIONS:
		if not session_limit_warned:
			session_limit_warned = true
			push_warning("[TranscriptWatcher] Session watch limit reached (%d)" % MAX_WATCHED_SESSIONS)
		return
	session_limit_warned = false
	# Open file and seek to end
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		file.seek_end(0)
		watched_sessions[file_path] = {
			"position": file.get_position(),
			"last_modified": FileAccess.get_modified_time(file_path),
			"harness_id": harness if not harness.is_empty() else _derive_harness(file_path),
			"line_buffer": PackedByteArray(),
			"discarding_line": false,
			"checkpoint": _read_checkpoint(file, file.get_position()),
			"block_hashes": _hash_blocks(file, file.get_position()),
			"verify_block": 0
		}
		file.close()
		print("[TranscriptWatcher] Watching: %s" % file_path.get_file())

		# Emit session_start event so orchestrator (Claude) appears (deferred to ensure signal is connected)
		var session_id = _derive_session_id(file_path)
		call_deferred("_emit_session_start", session_id, file_path)
	else:
		push_warning("[TranscriptWatcher] Cannot open: %s" % file_path)

func _emit_event(data: Dictionary) -> void:
	## Helper for deferred emission - breaks synchronous cascades that can cause X11 threading issues.
	## Guards against emission during shutdown to prevent X11 fatal errors.
	if not is_inside_tree():
		return
	if is_queued_for_deletion():
		return
	var tree = get_tree()
	if tree == null:
		return
	event_received.emit(data)

func _emit_context_updated(session_path: String, context_percent: float) -> void:
	## Deferred emission helper for context_updated signal.
	if not is_inside_tree():
		return
	if is_queued_for_deletion():
		return
	if get_tree() == null:
		return
	context_updated.emit(session_path, context_percent)

func _emit_session_start(session_id: String, session_path: String) -> void:
	var harness = _derive_harness(session_path)
	call_deferred("_emit_event", {
		"event": "session_start",
		"session_id": session_id,
		"session_path": session_path,
		"harness_id": harness,
		"harness_label": harness.capitalize() if harness else "",
		"timestamp": Time.get_datetime_string_from_system()
	})

func _emit_session_end(session_id: String, session_path: String, harness: String) -> void:
	call_deferred("_emit_event", {
		"event": "session_end",
		"session_id": session_id,
		"session_path": session_path,
		"harness_id": harness,
		"harness_label": harness.capitalize() if harness else "",
		"timestamp": Time.get_datetime_string_from_system()
	})

func check_all_sessions() -> void:
	var paths = watched_sessions.keys()
	if paths.is_empty():
		return
	poll_bytes_remaining = MAX_BYTES_PER_POLL_CYCLE
	poll_deadline_msec = Time.get_ticks_msec() + MAX_POLL_MSEC
	verification_session_path = str(paths[poll_cursor % paths.size()])
	var visited = 0
	while visited < paths.size() and poll_bytes_remaining > 0 and Time.get_ticks_msec() < poll_deadline_msec:
		var index = (poll_cursor + visited) % paths.size()
		check_session_for_entries(str(paths[index]))
		visited += 1
	var cursor_advance = 1 if visited >= paths.size() else maxi(1, visited)
	poll_cursor = (poll_cursor + cursor_advance) % paths.size()
	poll_bytes_remaining = -1
	verification_session_path = ""

func check_session_for_entries(file_path: String) -> void:
	if not watched_sessions.has(file_path) or not FileAccess.file_exists(file_path):
		return
	var session = watched_sessions[file_path]

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	var file_length = file.get_length()
	var position = int(session.get("position", 0))
	var modified_time = FileAccess.get_modified_time(file_path)
	var replaced = false
	if position > 0 and file_length >= position:
		var expected: PackedByteArray = session.get("checkpoint", PackedByteArray())
		if not expected.is_empty() and _read_checkpoint(file, position) != expected:
			replaced = true
		# Verify one earlier block per poll cycle, independent of timestamp
		# resolution. Round-robin block checks eventually detect arbitrary
		# in-place or same-size rewrites without rehashing every transcript.
		var should_verify = verification_session_path.is_empty() or verification_session_path == file_path
		var block_hashes: Array = session.get("block_hashes", [])
		if not replaced and should_verify and not block_hashes.is_empty():
			var block_index = int(session.get("verify_block", 0)) % block_hashes.size()
			var block_start = block_index * REPLACEMENT_HASH_BLOCK_BYTES
			var block_end = mini(position, block_start + REPLACEMENT_HASH_BLOCK_BYTES)
			if block_start < block_end:
				var actual_hash = _hash_range(file, block_start, block_end)
				if actual_hash != str(block_hashes[block_index]):
					replaced = true
			watched_sessions[file_path]["verify_block"] = (block_index + 1) % block_hashes.size()
	if file_length < position or replaced:
		position = 0
		watched_sessions[file_path]["line_buffer"] = PackedByteArray()
		watched_sessions[file_path]["discarding_line"] = false
		watched_sessions[file_path]["checkpoint"] = PackedByteArray()
		watched_sessions[file_path]["block_hashes"] = []
		watched_sessions[file_path]["verify_block"] = 0
	if file_length <= position:
		watched_sessions[file_path]["last_modified"] = modified_time
		file.close()
		return
	file.seek(position)
	var to_read = mini(file_length - position, MAX_BYTES_PER_POLL)
	if poll_bytes_remaining >= 0:
		to_read = mini(to_read, poll_bytes_remaining)
	if to_read <= 0:
		file.close()
		return
	var read_start_position = position
	var incoming = file.get_buffer(to_read)
	if poll_bytes_remaining >= 0:
		poll_bytes_remaining -= incoming.size()
	watched_sessions[file_path]["position"] = file.get_position()
	watched_sessions[file_path]["last_modified"] = modified_time
	watched_sessions[file_path]["block_hashes"] = _update_block_hashes(
		file,
		read_start_position,
		file.get_position(),
		watched_sessions[file_path].get("block_hashes", [])
	)
	watched_sessions[file_path]["checkpoint"] = _read_checkpoint(file, file.get_position())
	file.close()

	var buffer: PackedByteArray = watched_sessions[file_path].get("line_buffer", PackedByteArray())
	buffer.append_array(incoming)
	var had_content = false
	while true:
		var newline = buffer.find(10)
		if newline < 0:
			break
		var line_bytes = buffer.slice(0, newline)
		buffer = buffer.slice(newline + 1)
		if bool(watched_sessions[file_path].get("discarding_line", false)):
			watched_sessions[file_path]["discarding_line"] = false
			continue
		if line_bytes.size() > MAX_LINE_BYTES:
			push_warning("[TranscriptWatcher] Skipping oversized transcript record in %s" % file_path.get_file())
			continue
		if not line_bytes.is_empty() and line_bytes[line_bytes.size() - 1] == 13:
			line_bytes.resize(line_bytes.size() - 1)
		var line = line_bytes.get_string_from_utf8()
		if line.strip_edges().is_empty():
			continue
		had_content = true
		process_line(line, file_path)
	if buffer.size() > MAX_LINE_BYTES:
		buffer.clear()
		watched_sessions[file_path]["discarding_line"] = true
		push_warning("[TranscriptWatcher] Discarding oversized unterminated record in %s" % file_path.get_file())
	watched_sessions[file_path]["line_buffer"] = buffer

	# Emit session_activity so OfficeManager can respawn missing orchestrators
	if had_content:
		var session_id = _derive_session_id(file_path)
		var harness = _derive_harness(file_path)
		call_deferred("_emit_event", {
			"event": "session_activity",
			"session_id": session_id,
			"session_path": file_path,
			"harness_id": harness,
			"harness_label": harness.capitalize() if harness else "",
			"timestamp": Time.get_datetime_string_from_system()
		})

func _read_checkpoint(file: FileAccess, position: int) -> PackedByteArray:
	if position <= 0:
		return PackedByteArray()
	var start = maxi(0, position - REPLACEMENT_CHECKPOINT_BYTES)
	file.seek(start)
	return file.get_buffer(position - start)

func _hash_range(file: FileAccess, start: int, end: int) -> String:
	file.seek(start)
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(end - start))
	return context.finish().hex_encode()

func _hash_blocks(file: FileAccess, end: int) -> Array:
	var hashes: Array = []
	var offset = 0
	while offset < end:
		var block_end = mini(end, offset + REPLACEMENT_HASH_BLOCK_BYTES)
		hashes.append(_hash_range(file, offset, block_end))
		offset = block_end
	file.seek(end)
	return hashes

func _update_block_hashes(file: FileAccess, start: int, end: int, existing: Array) -> Array:
	var hashes = existing.duplicate()
	var start_block: int = start / REPLACEMENT_HASH_BLOCK_BYTES
	hashes.resize(start_block)
	var offset = start_block * REPLACEMENT_HASH_BLOCK_BYTES
	while offset < end:
		var block_end = mini(end, offset + REPLACEMENT_HASH_BLOCK_BYTES)
		hashes.append(_hash_range(file, offset, block_end))
		offset = block_end
	file.seek(end)
	return hashes

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
		var line_bytes = line.to_utf8_buffer().size()
		if not session_context_entries.has(session_path):
			session_context_entries[session_path] = []
		session_context_entries[session_path].append({
			"time": Time.get_unix_time_from_system(),
			"size": line_bytes
		})
		if session_context_entries[session_path].size() > MAX_CONTEXT_ENTRIES:
			session_context_entries[session_path] = session_context_entries[session_path].slice(-MAX_CONTEXT_ENTRIES)
		call_deferred("_emit_context_updated", session_path, get_context_percent(session_path))

	if _process_codex_entry(entry, session_path):
		return
	if _process_clawdbot_entry(entry, session_path):
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
					call_deferred("_emit_event", {
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
					call_deferred("_emit_context_updated", session_path, 0.0)

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
		elif payload_type == "agent_message":
			_process_codex_agent_message(payload, entry)
		return true
	if entry_type == "event_msg":
		var payload = entry.get("payload", {})
		if payload is Dictionary and payload.get("type", "") == "sub_agent_activity":
			_process_codex_subagent_activity(payload, entry, session_path)
		return true
	if entry_type == "session_meta" or entry_type == "turn_context":
		return true
	return false

func _process_codex_subagent_activity(payload: Dictionary, entry: Dictionary, session_path: String) -> void:
	var thread_id = str(payload.get("agent_thread_id", "")).strip_edges()
	if thread_id.is_empty() or thread_id.length() > MAX_CORRELATION_ID_CHARS:
		return
	var agent_path = str(payload.get("agent_path", "")).left(MAX_DESCRIPTION_CHARS)
	var agent_id = thread_id.substr(0, 12)
	var kind = str(payload.get("kind", ""))
	if kind == "started":
		if codex_subagents.size() >= MAX_CODEX_SUBAGENTS and not codex_subagents.has(thread_id):
			push_warning("[TranscriptWatcher] Codex subagent limit reached (%d)" % MAX_CODEX_SUBAGENTS)
			return
		var agent_type = agent_path.get_file()
		if agent_type.is_empty():
			agent_type = "default"
		codex_subagents[thread_id] = {
			"agent_id": agent_id,
			"agent_path": agent_path,
			"session_path": session_path,
			"created_at": Time.get_unix_time_from_system()
		}
		call_deferred("_emit_event", {
			"event": "agent_spawn", "agent_id": agent_id, "agent_type": agent_type,
			"description": agent_path, "parent_id": _get_orchestrator_id(session_path),
			"session_path": session_path, "harness_id": "codex",
			"harness_label": "Codex", "timestamp": entry.get("timestamp", "")
		})
	elif kind == "interrupted" and codex_subagents.has(thread_id):
		codex_subagents.erase(thread_id)
		call_deferred("_emit_event", {
			"event": "agent_complete", "agent_id": agent_id, "success": "false",
			"result": "Interrupted", "timestamp": entry.get("timestamp", "")
		})

func _process_codex_agent_message(payload: Dictionary, entry: Dictionary) -> void:
	var author = str(payload.get("author", ""))
	if not author.begins_with("/"):
		return
	var result_text = ""
	for block in payload.get("content", []):
		if block is Dictionary:
			result_text += str(block.get("text", ""))
	if not result_text.contains("Message Type: FINAL_ANSWER"):
		return
	for thread_id in codex_subagents.keys():
		var info = codex_subagents[thread_id]
		if info.get("agent_path", "") != author:
			continue
		codex_subagents.erase(thread_id)
		call_deferred("_emit_event", {
			"event": "agent_complete", "agent_id": info.get("agent_id", ""),
			"success": "true", "result": result_text.substr(0, 200),
			"timestamp": entry.get("timestamp", "")
		})
		break

func _process_clawdbot_entry(entry: Dictionary, session_path: String) -> bool:
	# Clawdbot sessions are JSONL with top-level entry types (session, model_change, message, ...).
	# Tool calls are embedded INSIDE message.content as items with type="toolCall".
	# There may not be explicit toolResult entries; we clear "waiting" state opportunistically.
	var entry_type = entry.get("type", "")
	if entry_type != "message":
		return false
	var msg = entry.get("message", {})
	if not msg is Dictionary:
		return true
	var content = msg.get("content", [])
	if not content is Array:
		return true

	var timestamp = entry.get("timestamp", "")
	var saw_tool_call := false
	var saw_text := false

	for block in content:
		if not block is Dictionary:
			continue
		var block_type = str(block.get("type", ""))
		if block_type == "toolCall":
			saw_tool_call = true
			var tool_name = str(block.get("name", ""))
			var tool_id = str(block.get("id", ""))
			var tool_args = block.get("arguments", {})
			if not tool_args is Dictionary:
				tool_args = {}
			var item = {"name": tool_name, "id": tool_id, "input": tool_args}
			var normalized_entry = {"timestamp": timestamp}
			process_tool_use(item, normalized_entry, session_path)
		elif block_type == "text":
			var t = str(block.get("text", "")).strip_edges()
			if not t.is_empty():
				saw_text = true

	# If we previously emitted waiting_for_input, but Clawdbot doesn't emit tool results,
	# clear the waiting state when we observe subsequent text content.
	if (not saw_tool_call) and saw_text:
		var to_clear: Array[String] = []
		for tool_use_id in pending_tools.keys():
			var info = pending_tools[tool_use_id]
			if info.get("session_path", "") == session_path:
				to_clear.append(tool_use_id)
		for tool_use_id in to_clear:
			var info = pending_tools.get(tool_use_id, {})
			pending_tools.erase(tool_use_id)
			call_deferred("_emit_event", {
				"event": "tool_finished",
				"agent_id": "main",
				"tool": info.get("tool_name", ""),
				"timestamp": timestamp,
				"session_path": session_path
			})

	return true

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
	var tool_name = str(item.get("name", "")).left(MAX_TYPE_CHARS)
	var tool_id = str(item.get("id", ""))
	if tool_id.is_empty() or tool_id.length() > MAX_CORRELATION_ID_CHARS:
		return
	var tool_input = item.get("input", {})
	if not tool_input is Dictionary:
		tool_input = {}
	var timestamp = entry.get("timestamp", "")
	session_path = session_path.left(MAX_STORED_PATH_CHARS)

	if tool_name == "Task" or tool_name == "Agent":
		# Agent spawn
		var agent_type = str(tool_input.get("subagent_type", "default")).left(MAX_TYPE_CHARS)
		var description = str(tool_input.get("description", "")).left(MAX_DESCRIPTION_CHARS)

		# Store for matching with result (including session for cleanup)
		pending_agents[tool_id] = {
			"agent_type": agent_type,
			"description": description,
			"session_path": session_path,
			"created_at": Time.get_unix_time_from_system()
		}
		_trim_pending_map(pending_agents)

		var parent_id = _get_orchestrator_id(session_path)
		print("[TranscriptWatcher] SPAWN: %s - %s (id: %s, parent: %s)" % [agent_type, description, tool_id.substr(0, 12), parent_id])

		var harness = _derive_harness(session_path)
		call_deferred("_emit_event", {
			"event": "agent_spawn",
			"agent_id": tool_id.substr(0, 12),  # Use 12 chars to reduce collision risk
			"agent_type": agent_type,
			"description": description,
			"parent_id": parent_id,
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
		_trim_pending_map(pending_tools)

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
		# Tool activity is distinct from an explicit permission prompt.
		call_deferred("_emit_event", {
			"event": "tool_started",
			"agent_id": "main",
			"tool_use_id": tool_id,
			"tool": tool_name,
			"description": tool_desc,
			"timestamp": timestamp,
			"session_path": session_path,
			"harness_id": harness,
			"harness_label": harness.capitalize() if harness else ""
		})

func process_tool_result(item: Dictionary, entry: Dictionary) -> void:
	var tool_use_id = str(item.get("tool_use_id", ""))
	if tool_use_id.is_empty() or tool_use_id.length() > MAX_CORRELATION_ID_CHARS:
		return
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

		call_deferred("_emit_event", {
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

		call_deferred("_emit_event", {
			"event": "tool_finished",
			"agent_id": "main",
			"tool_use_id": tool_use_id,
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
	for info in codex_subagents.values():
		var created_at = float(info.get("created_at", 0))
		if info.get("session_path", "") == session_path and created_at > 0 and now - created_at <= PENDING_AGENT_TIMEOUT:
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

	var codex_keys: Array = []
	for thread_id in codex_subagents.keys():
		if codex_subagents[thread_id].get("session_path", "") == session_path:
			codex_keys.append(thread_id)
	for thread_id in codex_keys:
		codex_subagents.erase(thread_id)

func _derive_session_id(file_path: String) -> String:
	var basename = file_path.get_file().get_basename()
	if basename.begins_with("rollout-"):
		var trimmed = basename.substr(8)
		if not trimmed.is_empty():
			return trimmed
	return basename

func _get_session_short_id(session_id: String) -> String:
	if session_id.is_empty():
		return "unknown"
	if session_id.length() <= 8:
		return session_id
	return session_id.substr(session_id.length() - 8)

func _get_orchestrator_id(session_path: String) -> String:
	var session_id = _derive_session_id(session_path)
	return "orch_" + _get_session_short_id(session_id)

func _derive_harness(session_path: String) -> String:
	if watched_sessions.has(session_path):
		var stored = str(watched_sessions[session_path].get("harness_id", ""))
		if not stored.is_empty():
			return stored
	# Determine harness from path (handles both / and \ separators)
	var normalized = session_path.replace("\\", "/")
	if normalized.contains("/.claude/"):
		return "claude"
	elif normalized.contains("/.codex/"):
		return "codex"
	elif normalized.contains("/.clawdbot/"):
		return "clawdbot"
	return ""

func _validated_custom_path(value: String) -> String:
	var path = value.strip_edges().simplify_path()
	if path.is_empty():
		return ""
	var home = _get_home_dir().simplify_path()
	if not path.is_absolute_path() or path == "/" or path == home or not DirAccess.dir_exists_absolute(path):
		push_warning("[TranscriptWatcher] Rejected unsafe custom watcher path: %s" % value)
		return ""
	return path

func _stop_watching_harness(harness: String) -> void:
	for path in watched_sessions.keys():
		if _derive_harness(path) == harness:
			call_deferred("_emit_session_end", _derive_session_id(path), path, harness)
			_cleanup_pending_for_session(path)
			watched_sessions.erase(path)
			session_context_entries.erase(path)

func _trim_pending_map(entries: Dictionary) -> void:
	while entries.size() > MAX_PENDING_ENTRIES:
		entries.erase(entries.keys()[0])

func get_watched_count() -> int:
	return watched_sessions.size()
