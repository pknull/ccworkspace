extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_test_shared_settings_file()
	_test_navigation_overlap_and_bounds()
	_test_http_unicode_framing()
	_test_transcript_partial_write_and_truncation()
	_test_current_harness_event_shapes()
	if failures.is_empty():
		print("REGRESSION TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _test_shared_settings_file() -> void:
	var path = "/tmp/inference-inc-settings-regression.json"
	var registry = preload("res://scripts/SettingsRegistry.gd").new()
	var watcher_schema = [{"key": "claude_enabled", "type": "bool", "default": true}]
	var mcp_schema = [{"key": "enabled", "type": "bool", "default": false}]
	registry.register_category("watchers", path, watcher_schema)
	registry.register_category("mcp", path, mcp_schema)
	registry.set_setting("watchers", "claude_enabled", false)
	registry.set_setting("mcp", "enabled", true)

	var reloaded = preload("res://scripts/SettingsRegistry.gd").new()
	reloaded.register_category("watchers", path, watcher_schema)
	reloaded.register_category("mcp", path, mcp_schema)
	_check(reloaded.get_setting("watchers", "claude_enabled") == false, "Shared settings lost watcher values")
	_check(reloaded.get_setting("mcp", "enabled") == true, "Shared settings lost MCP values")

	var legacy = FileAccess.open(path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({
		"harnesses": {"claude": {"enabled": true, "path": ""}},
		"mcp": {"enabled": true},
	}))
	legacy.close()
	var migrated = preload("res://scripts/SettingsRegistry.gd").new()
	migrated.register_category("watchers", path, watcher_schema)
	migrated.register_category("mcp", path, mcp_schema)
	migrated.set_setting("watchers", "claude_enabled", false)
	_check(migrated.get_setting("watchers", "claude_enabled") == false, "Legacy watcher setting could not be changed")
	var migrated_reload = preload("res://scripts/SettingsRegistry.gd").new()
	migrated_reload.register_category("watchers", path, watcher_schema)
	migrated_reload.register_category("mcp", path, mcp_schema)
	_check(migrated_reload.get_setting("watchers", "claude_enabled") == false, "Stale legacy watcher value overrode migrated setting")
	DirAccess.remove_absolute(path)
	registry.free()
	reloaded.free()
	migrated.free()
	migrated_reload.free()

func _test_navigation_overlap_and_bounds() -> void:
	var navigation = preload("res://scripts/NavigationGrid.gd").new()
	var origin = OfficeConstants.GRID_ORIGIN
	var cell = OfficeConstants.CELL_SIZE
	var overlap = Rect2(origin + Vector2(cell, cell), Vector2(cell, cell))
	navigation.register_obstacle(overlap, "a")
	navigation.register_obstacle(overlap, "b")
	var grid_pos = navigation.world_to_grid(overlap.get_center())
	_check(not navigation.can_place_obstacle(overlap, "a"), "Excluding one obstacle hid a second overlapping obstacle")
	navigation.unregister_obstacle("a")
	_check(not navigation.is_walkable(grid_pos), "Removing one overlapping obstacle cleared the other")
	navigation.unregister_obstacle("b")
	_check(navigation.is_walkable(grid_pos), "Removing the final obstacle did not clear its cell")
	_check(not navigation.can_place_obstacle(Rect2(origin - Vector2(cell, 0), Vector2(cell, cell))), "Out-of-bounds furniture placement was accepted")

	navigation.register_obstacle(overlap, "blocked_goal")
	var path = navigation.find_path(origin + Vector2(cell * 0.5, cell * 0.5), overlap.get_center())
	_check(not path.is_empty(), "No route was produced for a blocked requested goal")
	if not path.is_empty():
		_check(path[-1] != overlap.get_center(), "Path smoothing restored the blocked requested goal")

func _test_http_unicode_framing() -> void:
	var server = preload("res://scripts/McpServer.gd").new()
	var body = JSON.stringify({"jsonrpc": "2.0", "id": 1, "method": "tools/list", "note": "café 猫"})
	var request = ("POST / HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n" % body.to_utf8_buffer().size()).to_utf8_buffer()
	var body_bytes = body.to_utf8_buffer()
	request.append_array(body_bytes.slice(0, body_bytes.size() - 1))
	_check(not server._has_complete_http_request(request), "HTTP request completed before all UTF-8 bytes arrived")
	request.append(body_bytes[-1])
	_check(server._has_complete_http_request(request), "Complete UTF-8 HTTP request was not recognized")
	_check(server._process_request({"jsonrpc": "2.0", "method": "notifications/initialized"}).is_empty(), "MCP initialized notification produced a response")
	_check(server._process_request({"id": 1, "method": "tools/list"}).has("error"), "MCP accepted a request without JSON-RPC 2.0")
	server.free()

func _test_transcript_partial_write_and_truncation() -> void:
	var path = "/tmp/inference-inc-transcript-regression.jsonl"
	var record = JSON.stringify({"type": "session_meta", "payload": {"id": "one"}})
	var split = record.length() / 2
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(record.substr(0, split))
	file.close()

	var watcher = preload("res://scripts/TranscriptWatcher.gd").new()
	watcher.watched_sessions[path] = {
		"position": 0,
		"harness_id": "codex",
		"line_buffer": PackedByteArray(),
		"discarding_line": false
	}
	watcher.check_session_for_entries(path)
	_check(watcher.watched_sessions[path]["line_buffer"].size() > 0, "Partial transcript record was consumed")

	file = FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(record.substr(split) + "\n")
	file.close()
	watcher.check_session_for_entries(path)
	_check(watcher.watched_sessions[path]["line_buffer"].is_empty(), "Completed transcript record left a stale remainder")

	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"type": "session_meta", "payload": {"id": "two"}}) + "\n")
	file.close()
	watcher.check_session_for_entries(path)
	_check(watcher.watched_sessions[path]["position"] == FileAccess.get_file_as_bytes(path).size(), "Transcript truncation did not reset the read position")

	var old_rewrite = JSON.stringify({
		"type": "response_item",
		"payload": {
			"type": "function_call",
			"name": "shell",
			"call_id": "old0-rewrite",
			"arguments": JSON.stringify({"padding": "x".repeat(400)})
		}
	}) + "\n"
	var new_rewrite = old_rewrite.replace("old0-rewrite", "same-rewrite")
	_check(old_rewrite.to_utf8_buffer().size() == new_rewrite.to_utf8_buffer().size(), "Same-size rewrite fixture changed length")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(old_rewrite)
	file.close()
	watcher.check_session_for_entries(path)
	watcher.pending_tools.clear()
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(new_rewrite)
	file.close()
	watcher.check_session_for_entries(path)
	_check(watcher.pending_tools.has("same-rewrite"), "Same-size transcript replacement was not re-read")
	DirAccess.remove_absolute(path)
	watcher.free()

func _test_current_harness_event_shapes() -> void:
	var watcher = preload("res://scripts/TranscriptWatcher.gd").new()
	var thread_id = "12345678-1234-1234-1234-123456789abc"
	watcher._process_codex_entry({
		"type": "event_msg",
		"payload": {
			"type": "sub_agent_activity",
			"agent_thread_id": thread_id,
			"agent_path": "/root/reviewer",
			"kind": "started"
		}
	}, "/tmp/codex-session.jsonl")
	_check(watcher.codex_subagents.has(thread_id), "Current Codex subagent start event was ignored")
	watcher._process_codex_entry({
		"type": "event_msg",
		"payload": {
			"type": "sub_agent_activity",
			"agent_thread_id": thread_id,
			"agent_path": "/root/reviewer",
			"kind": "interrupted"
		}
	}, "/tmp/codex-session.jsonl")
	_check(not watcher.codex_subagents.has(thread_id), "Current Codex subagent interruption did not complete")

	watcher.process_tool_use({
		"name": "Agent",
		"id": "toolu_current_agent",
		"input": {"subagent_type": "reviewer", "description": "Review"}
	}, {"timestamp": ""}, "/tmp/claude-session.jsonl")
	_check(watcher.pending_agents.has("toolu_current_agent"), "Current Claude Agent tool was ignored")
	watcher.free()
