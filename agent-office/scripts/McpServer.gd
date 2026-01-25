extends Node
class_name McpServer

signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal event_received(event_data: Dictionary)
signal server_started()
signal server_stopped()
signal tool_called(tool_name: String, args: Dictionary)

const DEFAULT_PORT = 9999
const DEFAULT_BIND_ADDRESS = "127.0.0.1"
const WATCHER_CONFIG_FILE = "user://watchers.json"
const MAX_MESSAGE_SIZE = 65536
const MAX_CLIENTS = 25
const EVENT_HISTORY_LIMIT = 200
const SERVER_NAME = "Claude Office MCP"
const SERVER_VERSION = "0.1"

var tcp_server: TCPServer = null
var tcp_clients: Dictionary = {}  # client_id -> StreamPeerTCP
var tcp_buffers: Dictionary = {}  # client_id -> String (for HTTP request accumulation)
var pending_disconnect: Dictionary = {}  # client_id -> timestamp (deferred disconnect)
var next_tcp_id: int = 1
const DISCONNECT_DELAY_MS: int = 100  # Wait for TCP buffer to flush
var transport: String = "none"
var enabled: bool = true
var port: int = DEFAULT_PORT
var bind_address: String = DEFAULT_BIND_ADDRESS
var office_manager: Node = null
var recent_events: Array = []

func _ready() -> void:
	_load_mcp_config()
	_start_server()

func _process(_delta: float) -> void:
	if tcp_server == null:
		return
	_process_http()

func _exit_tree() -> void:
	_stop_server()

func set_office_manager(manager: Node) -> void:
	office_manager = manager

func record_event(event_data: Dictionary) -> void:
	var entry = event_data.duplicate(true)
	entry["received_at"] = Time.get_datetime_string_from_system()
	recent_events.append(entry)
	if recent_events.size() > EVENT_HISTORY_LIMIT:
		recent_events.pop_front()

func get_mcp_config() -> Dictionary:
	return {
		"enabled": enabled,
		"port": port,
		"bind_address": bind_address
	}

func get_transport() -> String:
	return transport

func set_mcp_config(config: Dictionary) -> void:
	var next_enabled = bool(config.get("enabled", enabled))
	var next_port = int(config.get("port", port))
	var next_bind = str(config.get("bind_address", bind_address)).strip_edges()
	if next_bind.is_empty():
		next_bind = bind_address

	var changed = next_enabled != enabled or next_port != port or next_bind != bind_address
	enabled = next_enabled
	port = next_port
	bind_address = next_bind
	_save_mcp_config()
	if changed:
		_restart_server()

func _start_server() -> void:
	if not enabled:
		return
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port, bind_address)
	if err != OK:
		push_error("Failed to start MCP HTTP server on %s:%d: %s" % [bind_address, port, error_string(err)])
		tcp_server = null
		return
	transport = "http"
	print("[McpServer] Listening on http://%s:%d" % [bind_address, port])
	server_started.emit()

func _stop_server() -> void:
	var was_running = tcp_server != null
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
		print("[McpServer] HTTP server stopped")
	_disconnect_tcp_clients()
	transport = "none"
	if was_running:
		server_stopped.emit()

func _disconnect_tcp_clients() -> void:
	for client_id in tcp_clients.keys():
		var peer = tcp_clients[client_id]
		peer.disconnect_from_host()
	tcp_clients.clear()
	tcp_buffers.clear()
	pending_disconnect.clear()

func _restart_server() -> void:
	_stop_server()
	_start_server()

func _process_http() -> void:
	# Accept new connections
	while tcp_server.is_connection_available():
		if tcp_clients.size() >= MAX_CLIENTS:
			var rejected = tcp_server.take_connection()
			if rejected:
				rejected.disconnect_from_host()
			push_warning("[McpServer] Connection rejected: max clients (%d) reached" % MAX_CLIENTS)
			break
		var peer = tcp_server.take_connection()
		if peer:
			peer.set_no_delay(true)  # Disable Nagle's algorithm for faster response
			var client_id = next_tcp_id
			next_tcp_id += 1
			tcp_clients[client_id] = peer
			tcp_buffers[client_id] = ""
			client_connected.emit(client_id)

	# Process existing connections
	var to_disconnect_now: Array[int] = []
	for client_id in tcp_clients.keys():
		# Skip clients pending deferred disconnect
		if pending_disconnect.has(client_id):
			continue
		var client = tcp_clients[client_id]
		client.poll()
		var status = client.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			to_disconnect_now.append(client_id)
			continue
		if status != StreamPeerTCP.STATUS_CONNECTED:
			continue
		var available = client.get_available_bytes()
		if available > MAX_MESSAGE_SIZE:
			_send_http_error(client_id, 413, "Request too large")
			_schedule_disconnect(client_id)
			continue
		if available > 0:
			var data = client.get_data(available)
			if data[0] == OK:
				tcp_buffers[client_id] += data[1].get_string_from_utf8()
				if tcp_buffers[client_id].length() > MAX_MESSAGE_SIZE:
					_send_http_error(client_id, 413, "Request too large")
					_schedule_disconnect(client_id)
					continue
				# Check if we have a complete HTTP request
				if _has_complete_http_request(tcp_buffers[client_id]):
					_handle_http_request(client_id, tcp_buffers[client_id])
					_schedule_disconnect(client_id)

	# Process deferred disconnects (wait for TCP buffer to flush)
	var now = Time.get_ticks_msec()
	for client_id in pending_disconnect.keys():
		var scheduled_time = pending_disconnect[client_id]
		if now >= scheduled_time:
			to_disconnect_now.append(client_id)

	# Actually disconnect clients
	for id in to_disconnect_now:
		pending_disconnect.erase(id)
		if tcp_clients.has(id):
			var peer = tcp_clients[id]
			peer.disconnect_from_host()
			tcp_clients.erase(id)
			tcp_buffers.erase(id)
			client_disconnected.emit(id)

func _schedule_disconnect(client_id: int) -> void:
	pending_disconnect[client_id] = Time.get_ticks_msec() + DISCONNECT_DELAY_MS

func _has_complete_http_request(buffer: String) -> bool:
	# Check for end of headers
	var header_end = buffer.find("\r\n\r\n")
	if header_end == -1:
		return false
	# Check Content-Length if present
	var headers = buffer.substr(0, header_end)
	var content_length = _get_content_length(headers)
	if content_length == 0:
		return true  # No body expected
	var body_start = header_end + 4
	var body = buffer.substr(body_start)
	return body.length() >= content_length

func _get_content_length(headers: String) -> int:
	for line in headers.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			var value = line.substr(15).strip_edges()
			if value.is_valid_int():
				return int(value)
	return 0

func _handle_http_request(client_id: int, raw_request: String) -> void:
	var header_end = raw_request.find("\r\n\r\n")
	var headers_part = raw_request.substr(0, header_end)
	var body = raw_request.substr(header_end + 4)

	var lines = headers_part.split("\r\n")
	if lines.is_empty():
		_send_http_error(client_id, 400, "Bad Request")
		return

	var request_line = lines[0].split(" ")
	if request_line.size() < 2:
		_send_http_error(client_id, 400, "Bad Request")
		return

	var method = request_line[0]
	var path = request_line[1]

	# Handle CORS preflight
	if method == "OPTIONS":
		_send_http_cors_preflight(client_id)
		return

	# Only accept POST for MCP
	if method != "POST":
		_send_http_error(client_id, 405, "Method Not Allowed")
		return

	# Parse JSON-RPC body
	var content_length = _get_content_length(headers_part)
	if content_length > 0:
		body = body.substr(0, content_length)

	var json = JSON.new()
	var err = json.parse(body)
	if err != OK:
		_send_http_json_rpc_error(client_id, null, -32700, "Parse error")
		return

	var payload = json.data
	if payload is Array:
		var results: Array = []
		for entry in payload:
			if entry is Dictionary:
				results.append(_process_request(entry))
		_send_http_json_response(client_id, results)
	elif payload is Dictionary:
		var result = _process_request(payload)
		_send_http_json_response(client_id, result)
	else:
		_send_http_json_rpc_error(client_id, null, -32600, "Invalid Request")

func _process_request(request: Dictionary) -> Dictionary:
	var method = str(request.get("method", ""))
	var id = request.get("id", null)

	if method.is_empty():
		return _build_json_rpc_error(id, -32600, "Invalid Request")

	match method:
		"initialize":
			return _build_json_rpc_result(id, _build_initialize_result(request.get("params", {})))
		"resources/list", "list_resources":
			return _build_json_rpc_result(id, {"resources": _list_resources()})
		"resources/read", "read_resource":
			var params = request.get("params", {})
			var uri = ""
			if params is Dictionary:
				uri = str(params.get("uri", ""))
			return _build_json_rpc_result(id, _read_resource(uri))
		"tools/list", "list_tools":
			return _build_json_rpc_result(id, {"tools": _list_tools()})
		"tools/call", "call_tool":
			var params = request.get("params", {})
			return _build_json_rpc_result(id, _call_tool(params))
		_:
			return _build_json_rpc_error(id, -32601, "Method not found")

func _build_json_rpc_result(id, result) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": id,
		"result": result
	}

func _build_json_rpc_error(id, code: int, message: String) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": id,
		"error": {
			"code": code,
			"message": message
		}
	}

func _send_http_json_response(client_id: int, payload) -> void:
	var body = JSON.stringify(payload)
	var response = "HTTP/1.1 200 OK\r\n"
	response += "Content-Type: application/json\r\n"
	response += "Content-Length: %d\r\n" % body.length()
	response += "Access-Control-Allow-Origin: http://localhost\r\n"
	response += "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"
	response += body
	_send_raw(client_id, response)

func _send_http_json_rpc_error(client_id: int, id, code: int, message: String) -> void:
	_send_http_json_response(client_id, _build_json_rpc_error(id, code, message))

func _send_http_error(client_id: int, status_code: int, message: String) -> void:
	var response = "HTTP/1.1 %d %s\r\n" % [status_code, message]
	response += "Content-Type: text/plain\r\n"
	response += "Content-Length: %d\r\n" % message.length()
	response += "Connection: close\r\n"
	response += "\r\n"
	response += message
	_send_raw(client_id, response)

func _send_http_cors_preflight(client_id: int) -> void:
	var response = "HTTP/1.1 204 No Content\r\n"
	response += "Access-Control-Allow-Origin: http://localhost\r\n"
	response += "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"
	response += "Access-Control-Max-Age: 86400\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"
	_send_raw(client_id, response)

func _send_raw(client_id: int, data: String) -> void:
	if not tcp_clients.has(client_id):
		return
	var peer = tcp_clients[client_id]
	peer.put_data(data.to_utf8_buffer())
	peer.poll()  # Attempt to flush send buffer

func _build_initialize_result(params: Dictionary) -> Dictionary:
	var protocol_version = str(params.get("protocolVersion", "2024-11-05"))
	return {
		"protocolVersion": protocol_version,
		"serverInfo": {
			"name": SERVER_NAME,
			"version": SERVER_VERSION
		},
		"capabilities": {
			"resources": {
				"list": true,
				"read": true
			},
			"tools": {
				"list": true,
				"call": true
			}
		}
	}

func _list_resources() -> Array[Dictionary]:
	return [
		{
			"uri": "office://summary",
			"name": "Office Summary",
			"description": "High-level office status and counts",
			"mimeType": "application/json"
		},
		{
			"uri": "office://agents",
			"name": "Active Agents",
			"description": "Active agent details",
			"mimeType": "application/json"
		},
		{
			"uri": "office://watchers",
			"name": "Watcher Status",
			"description": "Harness watcher configuration and status",
			"mimeType": "application/json"
		},
		{
			"uri": "office://sessions",
			"name": "Sessions",
			"description": "Watched session list",
			"mimeType": "application/json"
		},
		{
			"uri": "office://events",
			"name": "Recent Events",
			"description": "Recent office events",
			"mimeType": "application/json"
		}
	]

func _read_resource(uri: String) -> Dictionary:
	var payload = {}
	match uri:
		"office://summary":
			payload = _build_summary()
		"office://agents":
			payload = _build_agents()
		"office://watchers":
			payload = _build_watchers()
		"office://sessions":
			payload = _build_sessions()
		"office://events":
			payload = {"events": recent_events.duplicate(true)}
		_:
			return {
				"contents": [{
					"uri": uri,
					"mimeType": "text/plain",
					"text": "Unknown resource"
				}]
			}

	return {
		"contents": [{
			"uri": uri,
			"mimeType": "application/json",
			"text": JSON.stringify(payload)
		}]
	}

func _list_tools() -> Array[Dictionary]:
	return [
		{
			"name": "post_event",
			"description": "Post an event to the office (agent_spawn, agent_complete, tool_use, chat, etc).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"event": {"type": "string", "description": "Event type"},
					"agent_id": {"type": "string"},
					"agent_type": {"type": "string"},
					"session_id": {"type": "string"},
					"description": {"type": "string"},
					"tool_name": {"type": "string"},
					"success": {"type": "boolean"},
					"message": {"type": "string"},
					"target_agent_id": {"type": "string"}
				},
				"required": ["event"]
			}
		},
		{
			"name": "set_weather",
			"description": "Set the office weather (clear, cloudy, drizzle, rain, showers, storm, snow, fog).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"state": {"type": "string"}
				},
				"required": ["state"]
			}
		},
		{
			"name": "dismiss_agent",
			"description": "Dismiss a single agent by ID.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"agent_id": {"type": "string"},
					"force": {"type": "boolean"}
				},
				"required": ["agent_id"]
			}
		},
		{
			"name": "dismiss_all_agents",
			"description": "Dismiss all active agents.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"force": {"type": "boolean"}
				}
			}
		},
		{
			"name": "quit_office",
			"description": "Quit the office application cleanly.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "get_office_state",
			"description": "Get the full office state including agents, furniture positions, weather, and cat.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "list_agents",
			"description": "List all active agents in the office.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "get_agent_profile",
			"description": "Get detailed profile for an agent by profile ID.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"profile_id": {"type": "integer", "description": "Agent profile ID"}
				},
				"required": ["profile_id"]
			}
		},
		{
			"name": "move_furniture",
			"description": "Move a furniture item to a new position.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"item": {"type": "string", "description": "Furniture name: water_cooler, plant, filing_cabinet, shredder, cat_bed, meeting_table"},
					"x": {"type": "number", "description": "X position (30-1250)"},
					"y": {"type": "number", "description": "Y position (100-620)"}
				},
				"required": ["item", "x", "y"]
			}
		},
		{
			"name": "move_desk",
			"description": "Move a desk to a new position.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"desk_index": {"type": "integer", "description": "Desk index (0-7)"},
					"x": {"type": "number", "description": "X position"},
					"y": {"type": "number", "description": "Y position"}
				},
				"required": ["desk_index", "x", "y"]
			}
		},
		{
			"name": "remove_desk",
			"description": "Remove a desk from the office. Desk must be empty (no agent working at it).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"desk_index": {"type": "integer", "description": "Desk index (use get_office_state to see desk indices)"}
				},
				"required": ["desk_index"]
			}
		},
		{
			"name": "add_desk",
			"description": "Add a new desk to the office.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"x": {"type": "number", "description": "X position"},
					"y": {"type": "number", "description": "Y position"}
				},
				"required": ["x", "y"]
			}
		},
		{
			"name": "pet_cat",
			"description": "Pet the office cat. Returns cat's reaction.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "spawn_agent",
			"description": "Spawn a new agent in the office.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"agent_type": {"type": "string", "description": "Agent type (e.g., 'explorer', 'planner', 'coder')"},
					"description": {"type": "string", "description": "Task description"}
				},
				"required": ["agent_type"]
			}
		},
		{
			"name": "remove_furniture",
			"description": "Remove a furniture item from the office. Use get_office_state to see furniture IDs.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"furniture_id": {"type": "string", "description": "Furniture ID (e.g., 'furniture_5' for dynamic, 'default_shredder' for default items)"}
				},
				"required": ["furniture_id"]
			}
		},
		{
			"name": "add_furniture",
			"description": "Add a new furniture item to the office.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"type": {"type": "string", "description": "Furniture type: water_cooler, potted_plant, filing_cabinet, shredder, cat_bed, meeting_table, taskboard"},
					"x": {"type": "number", "description": "X position"},
					"y": {"type": "number", "description": "Y position"}
				},
				"required": ["type", "x", "y"]
			}
		},
		{
			"name": "update_agent_appearance",
			"description": "Update an agent's appearance. Use name OR profile_id. Hair colors: brown(0), black(1), auburn(2), blonde(3), dark_brown(4), very_dark(5). Skin tones: light(0), medium(1), tan(2), dark(3), very_light(4). Bottom type: pants(0), skirt(1).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"name": {"type": "string", "description": "Agent name (e.g., 'Quinn')"},
					"profile_id": {"type": "integer", "description": "Agent profile ID"},
					"hair_color": {"type": ["string", "integer"], "description": "Hair color name (brown, black, auburn, blonde, dark_brown, very_dark) or index 0-5"},
					"skin_color": {"type": ["string", "integer"], "description": "Skin tone name (light, medium, tan, dark, very_light) or index 0-4"},
					"hair_style": {"type": "integer", "description": "Hair style index 0-3"},
					"is_female": {"type": "boolean", "description": "true = blouse, false = shirt+tie"},
					"top_color": {"type": "integer", "description": "Blouse or tie color index 0-3"},
					"bottom_type": {"type": ["string", "integer"], "description": "pants(0) or skirt(1)"},
					"bottom_color": {"type": "integer", "description": "Bottom color index 0-3"}
				}
			}
		}
	]

func _call_tool(params) -> Dictionary:
	if not params is Dictionary:
		return _tool_error("Invalid params")
	var name = str(params.get("name", ""))
	var args = params.get("arguments", {})
	if not args is Dictionary:
		args = {}

	# Emit tool_called for Manager reactions
	tool_called.emit(name, args)

	match name:
		"post_event":
			return _tool_post_event(args)
		"set_weather":
			return _tool_set_weather(args)
		"dismiss_agent":
			return _tool_dismiss_agent(args)
		"dismiss_all_agents":
			return _tool_dismiss_all_agents(args)
		"quit_office":
			return _tool_quit_office(args)
		"get_office_state":
			return _tool_get_office_state(args)
		"list_agents":
			return _tool_list_agents(args)
		"get_agent_profile":
			return _tool_get_agent_profile(args)
		"move_furniture":
			return _tool_move_furniture(args)
		"move_desk":
			return _tool_move_desk(args)
		"remove_desk":
			return _tool_remove_desk(args)
		"add_desk":
			return _tool_add_desk(args)
		"pet_cat":
			return _tool_pet_cat(args)
		"spawn_agent":
			return _tool_spawn_agent(args)
		"remove_furniture":
			return _tool_remove_furniture(args)
		"add_furniture":
			return _tool_add_furniture(args)
		"update_agent_appearance":
			return _tool_update_agent_appearance(args)
		_:
			return _tool_error("Unknown tool")

func _tool_post_event(args: Dictionary) -> Dictionary:
	var event_type = str(args.get("event", "")).strip_edges()
	if event_type.is_empty():
		return _tool_error("event is required")
	# Build event data from args
	var event_data = args.duplicate()
	# Record and emit
	record_event(event_data)
	event_received.emit(event_data)
	return _tool_ok("Event posted: %s" % event_type)

func _tool_set_weather(args: Dictionary) -> Dictionary:
	var state = str(args.get("state", "")).strip_edges()
	if state.is_empty():
		return _tool_error("state is required")
	if office_manager and office_manager.has_method("_handle_weather_set"):
		office_manager._handle_weather_set({"state": state})
	return _tool_ok("Weather set to %s" % state)

func _tool_dismiss_agent(args: Dictionary) -> Dictionary:
	var agent_id = str(args.get("agent_id", "")).strip_edges()
	var force = bool(args.get("force", true))
	if agent_id.is_empty():
		return _tool_error("agent_id is required")
	if office_manager and office_manager.has_method("_handle_agent_complete"):
		office_manager._handle_agent_complete({"agent_id": agent_id, "force": force, "source": "mcp"})
	return _tool_ok("Dismiss requested for %s" % agent_id)

func _tool_dismiss_all_agents(args: Dictionary) -> Dictionary:
	var force = bool(args.get("force", true))
	if office_manager:
		var ids = office_manager.active_agents.keys()
		for aid in ids:
			office_manager._handle_agent_complete({"agent_id": str(aid), "force": force, "source": "mcp"})
	return _tool_ok("Dismiss requested for all agents")

func _tool_quit_office(_args: Dictionary) -> Dictionary:
	# Request clean shutdown - give time for response to be sent
	if office_manager and office_manager.has_method("_request_quit"):
		call_deferred("_deferred_quit")
	else:
		call_deferred("_deferred_quit")
	return _tool_ok("Quit requested - office shutting down")

func _deferred_quit() -> void:
	# Small delay to ensure HTTP response is sent
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func _tool_get_office_state(_args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var weather_name = "unknown"
	if office_manager.weather_system:
		var ws = office_manager.weather_system
		weather_name = ws.WeatherState.keys()[ws.current_weather]

	var state = {
		"weather": weather_name,
		"time": Time.get_datetime_string_from_system(),
		"agents": [],
		"furniture": {},
		"desks": [],
		"cat": {}
	}

	# Agents
	for agent_id in office_manager.active_agents.keys():
		var agent = office_manager.active_agents[agent_id]
		if agent:
			state.agents.append({
				"id": agent.agent_id,
				"type": agent.agent_type,
				"name": agent.profile_name,
				"state": Agent.State.keys()[agent.state] if agent is Agent else str(agent.state),
				"position": {"x": agent.position.x, "y": agent.position.y}
			})

	# Default furniture (with IDs for removal)
	state.furniture.defaults = []
	if office_manager.draggable_water_cooler:
		state.furniture.defaults.append({"id": "default_water_cooler", "type": "water_cooler", "x": office_manager.water_cooler_position.x, "y": office_manager.water_cooler_position.y})
	if office_manager.draggable_plant:
		state.furniture.defaults.append({"id": "default_plant", "type": "plant", "x": office_manager.plant_position.x, "y": office_manager.plant_position.y})
	if office_manager.draggable_filing_cabinet:
		state.furniture.defaults.append({"id": "default_filing_cabinet", "type": "filing_cabinet", "x": office_manager.filing_cabinet_position.x, "y": office_manager.filing_cabinet_position.y})
	if office_manager.draggable_shredder:
		state.furniture.defaults.append({"id": "default_shredder", "type": "shredder", "x": office_manager.shredder_position.x, "y": office_manager.shredder_position.y})
	if office_manager.draggable_cat_bed:
		state.furniture.defaults.append({"id": "default_cat_bed", "type": "cat_bed", "x": office_manager.cat_bed_position.x, "y": office_manager.cat_bed_position.y})
	if office_manager.meeting_table:
		state.furniture.defaults.append({"id": "default_meeting_table", "type": "meeting_table", "x": office_manager.meeting_table_position.x, "y": office_manager.meeting_table_position.y})

	# Dynamic furniture (user-placed)
	state.furniture.dynamic = []
	for f in office_manager.placed_furniture:
		state.furniture.dynamic.append({"id": f.id, "type": f.type, "x": f.position.x, "y": f.position.y})

	# Desks
	for i in range(office_manager.desks.size()):
		var desk = office_manager.desks[i]
		state.desks.append({
			"index": i,
			"position": {"x": desk.position.x, "y": desk.position.y},
			"occupied": desk.is_occupied
		})

	# Cat
	if office_manager.office_cat:
		var cat = office_manager.office_cat
		var cat_state_name = "unknown"
		if "state" in cat:
			cat_state_name = cat.State.keys()[cat.state] if cat.state < cat.State.size() else "unknown"
		state.cat = {
			"position": {"x": cat.position.x, "y": cat.position.y},
			"state": cat_state_name,
			"pet_count": cat.pet_count if "pet_count" in cat else 0
		}

	return _tool_json(state)

func _tool_list_agents(_args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var agents = []
	for agent_id in office_manager.active_agents.keys():
		var agent = office_manager.active_agents[agent_id]
		if agent:
			agents.append({
				"agent_id": agent.agent_id,
				"agent_type": agent.agent_type,
				"profile_id": agent.profile_id,
				"profile_name": agent.profile_name,
				"description": agent.description,
				"state": Agent.State.keys()[agent.state] if agent is Agent else str(agent.state)
			})

	return _tool_json({"count": agents.size(), "agents": agents})

func _tool_get_agent_profile(args: Dictionary) -> Dictionary:
	if not office_manager or not office_manager.agent_roster:
		return _tool_error("Agent roster not available")

	var profile_id = int(args.get("profile_id", -1))
	if profile_id < 0:
		return _tool_error("profile_id is required")

	var profile = office_manager.agent_roster.get_agent(profile_id)
	if not profile:
		return _tool_error("Agent profile not found: %d" % profile_id)

	return _tool_json({
		"id": profile.id,
		"name": profile.agent_name,
		"level": profile.level,
		"xp": profile.xp,
		"tasks_completed": profile.tasks_completed,
		"tasks_failed": profile.tasks_failed,
		"total_work_time_hours": profile.get_work_time_hours(),
		"badges": profile.badges,
		"skills": profile.skills,
		"tools": profile.tools,
		"total_chats": profile.get_total_chats()
	})

func _tool_move_furniture(args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var item = str(args.get("item", "")).strip_edges().to_lower()
	var x = float(args.get("x", 0))
	var y = float(args.get("y", 0))

	# Clamp to valid bounds
	x = clamp(x, 30, 1250)
	y = clamp(y, 100, 620)
	var new_pos = Vector2(x, y)

	# Check for dynamic furniture by ID first (furniture_9, etc.)
	if item.begins_with("furniture_"):
		for f in office_manager.placed_furniture:
			if not f is Dictionary:
				continue
			if not f.has("id") or not f.has("node") or not f.has("position"):
				continue
			if f["id"] == item:
				f["node"].position = new_pos
				f["position"] = new_pos
				office_manager._save_positions()
				return _tool_ok("Moved %s to (%d, %d)" % [item, int(x), int(y)])
		return _tool_error("Dynamic furniture not found: %s" % item)

	match item:
		"water_cooler":
			if office_manager.draggable_water_cooler:
				office_manager.draggable_water_cooler.position = new_pos
				office_manager.water_cooler_position = new_pos
		"plant":
			if office_manager.draggable_plant:
				office_manager.draggable_plant.position = new_pos
				office_manager.plant_position = new_pos
		"filing_cabinet":
			if office_manager.draggable_filing_cabinet:
				office_manager.draggable_filing_cabinet.position = new_pos
				office_manager.filing_cabinet_position = new_pos
		"shredder":
			if office_manager.draggable_shredder:
				office_manager.draggable_shredder.position = new_pos
				office_manager.shredder_position = new_pos
		"cat_bed":
			if office_manager.draggable_cat_bed:
				office_manager.draggable_cat_bed.position = new_pos
				office_manager.cat_bed_position = new_pos
				if office_manager.office_cat and office_manager.office_cat.has_method("set_cat_bed_position"):
					office_manager.office_cat.set_cat_bed_position(new_pos)
		"meeting_table":
			if office_manager.meeting_table:
				office_manager.meeting_table.position = new_pos
				office_manager.meeting_table_position = new_pos
		_:
			return _tool_error("Unknown furniture: %s. Valid: water_cooler, plant, filing_cabinet, shredder, cat_bed, meeting_table, or furniture_<id>" % item)

	# Update navigation grid
	if office_manager.has_method("_register_with_navigation_grid"):
		office_manager._register_with_navigation_grid()

	return _tool_ok("Moved %s to (%d, %d)" % [item, int(x), int(y)])

func _tool_move_desk(args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var desk_index = int(args.get("desk_index", -1))
	var x = float(args.get("x", 0))
	var y = float(args.get("y", 0))

	if desk_index < 0 or desk_index >= office_manager.desks.size():
		return _tool_error("Invalid desk_index. Valid range: 0-%d" % (office_manager.desks.size() - 1))

	x = clamp(x, 50, 1200)
	y = clamp(y, 150, 550)

	var desk = office_manager.desks[desk_index]
	var new_pos = Vector2(x, y)
	desk.position = new_pos

	# Trigger position change handling (updates navigation, saves)
	if desk.has_signal("position_changed"):
		desk.position_changed.emit(desk, new_pos)

	return _tool_ok("Moved desk %d to (%d, %d)" % [desk_index, int(x), int(y)])

func _tool_remove_desk(args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var desk_index = int(args.get("desk_index", -1))
	if desk_index < 0 or desk_index >= office_manager.desks.size():
		return _tool_error("Invalid desk_index. Valid range: 0-%d" % (office_manager.desks.size() - 1))

	var desk = office_manager.desks[desk_index]
	if not desk.is_empty():
		return _tool_error("Cannot remove desk %d - it is occupied by an agent" % desk_index)

	if office_manager.has_method("_remove_desk"):
		var success = office_manager._remove_desk(desk_index)
		if success:
			return _tool_ok("Removed desk %d" % desk_index)
		else:
			return _tool_error("Failed to remove desk %d" % desk_index)
	else:
		return _tool_error("Desk removal not supported")

func _tool_add_desk(args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var x = float(args.get("x", 0))
	var y = float(args.get("y", 0))

	x = clamp(x, 50, 1200)
	y = clamp(y, 150, 550)

	if office_manager.has_method("_add_desk"):
		var new_index = office_manager._add_desk(Vector2(x, y))
		if new_index >= 0:
			return _tool_ok("Added desk at (%d, %d) - index %d" % [int(x), int(y), new_index])
		else:
			return _tool_error("Failed to add desk at (%d, %d)" % [int(x), int(y)])
	else:
		return _tool_error("Desk addition not supported")

func _tool_pet_cat(_args: Dictionary) -> Dictionary:
	if not office_manager or not office_manager.office_cat:
		return _tool_error("Cat not available")

	var cat = office_manager.office_cat
	if cat.has_method("pet"):
		cat.pet()
		var count = cat.pet_count if "pet_count" in cat else 0
		return _tool_ok("Petted the cat! (Total pets: %d) 🐱" % count)
	else:
		return _tool_error("Cat cannot be petted")

func _tool_spawn_agent(args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var agent_type = str(args.get("agent_type", "worker")).strip_edges()
	var description = str(args.get("description", "")).strip_edges()

	# Generate a unique agent ID
	var agent_id = "mcp_%d" % Time.get_ticks_msec()

	var event_data = {
		"event": "agent_spawn",
		"agent_id": agent_id,
		"agent_type": agent_type,
		"description": description,
		"source": "mcp"
	}

	record_event(event_data)
	event_received.emit(event_data)

	return _tool_ok("Spawned agent: %s (%s)" % [agent_type, agent_id])

func _tool_remove_furniture(args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var furniture_id = str(args.get("furniture_id", "")).strip_edges()
	if furniture_id.is_empty():
		return _tool_error("furniture_id is required")

	# Check if it exists before removing
	var found = false

	# Check dynamic furniture
	for f in office_manager.placed_furniture:
		if f.id == furniture_id:
			found = true
			break

	# Check default furniture
	if not found and furniture_id.begins_with("default_"):
		match furniture_id:
			"default_water_cooler":
				found = office_manager.draggable_water_cooler != null
			"default_plant":
				found = office_manager.draggable_plant != null
			"default_filing_cabinet":
				found = office_manager.draggable_filing_cabinet != null
			"default_shredder":
				found = office_manager.draggable_shredder != null
			"default_cat_bed":
				found = office_manager.draggable_cat_bed != null
			"default_taskboard":
				found = office_manager.draggable_taskboard != null
			"default_meeting_table":
				found = office_manager.meeting_table != null

	if not found:
		return _tool_error("Furniture not found: %s" % furniture_id)

	office_manager._remove_furniture(furniture_id)
	return _tool_ok("Removed furniture: %s" % furniture_id)

func _tool_add_furniture(args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("Office manager not available")

	var ftype = str(args.get("type", "")).strip_edges()
	var x = float(args.get("x", 0))
	var y = float(args.get("y", 0))

	if ftype.is_empty():
		return _tool_error("type is required")

	var valid_types = ["water_cooler", "potted_plant", "filing_cabinet", "shredder", "cat_bed", "meeting_table", "taskboard"]
	if not ftype in valid_types:
		return _tool_error("Invalid type: %s. Valid: %s" % [ftype, ", ".join(valid_types)])

	# Call the internal add furniture method
	office_manager._add_furniture(ftype, Vector2(x, y))
	return _tool_ok("Added %s at (%d, %d)" % [ftype, int(x), int(y)])

# Appearance constants - must match AgentVisuals arrays
const HAIR_COLOR_COUNT: int = 6
const SKIN_TONE_COUNT: int = 5
const HAIR_STYLE_COUNT: int = 4
const TOP_COLOR_COUNT: int = 4
const BOTTOM_COLOR_COUNT: int = 4

# Color name mappings for appearance updates
const HAIR_NAMES: Dictionary = {"brown": 0, "black": 1, "auburn": 2, "blonde": 3, "dark_brown": 4, "very_dark": 5}
const SKIN_NAMES: Dictionary = {"light": 0, "medium": 1, "tan": 2, "dark": 3, "very_light": 4}

func _parse_color_index(value, name_map: Dictionary, max_index: int) -> Array:
	# Returns [success: bool, index: int, error: String]
	if value is String:
		var key = value.to_lower().replace(" ", "_")
		if name_map.has(key):
			return [true, name_map[key], ""]
		return [false, -1, "Unknown color name '%s'. Valid: %s" % [value, ", ".join(name_map.keys())]]
	elif value is int or value is float:
		var idx = int(value)
		if idx >= 0 and idx < max_index:
			return [true, idx, ""]
		return [false, -1, "Index %d out of range (0-%d)" % [idx, max_index - 1]]
	return [false, -1, "Invalid type for color value"]

func _find_agent_profile(args: Dictionary) -> Array:
	# Returns [profile: AgentProfile or null, error: String]
	if not office_manager or not office_manager.agent_roster:
		return [null, "No agent roster available"]

	var roster = office_manager.agent_roster
	var search_name = str(args.get("name", "")).strip_edges()
	var search_id_raw = args.get("profile_id", -1)
	var search_id = int(search_id_raw) if (search_id_raw is int or search_id_raw is float) else -1

	if not search_name.is_empty():
		for p in roster.get_all_agents():
			if p.agent_name.to_lower() == search_name.to_lower():
				return [p, ""]
		# Sanitize name for error message (remove control chars)
		var safe_name = search_name.substr(0, 32).replace("\n", "").replace("\r", "")
		return [null, "Agent not found: '%s'" % safe_name]
	elif search_id >= 0:
		var profile = roster.get_agent(search_id)
		if profile:
			return [profile, ""]
		return [null, "Agent profile not found: %d" % search_id]
	return [null, "Either name or profile_id is required"]

func _refresh_agent_visuals(profile_id: int) -> bool:
	if not office_manager:
		return false
	var refreshed = false
	var agent_keys = office_manager.active_agents.keys().duplicate()
	for aid in agent_keys:
		if not office_manager.active_agents.has(aid):
			continue
		var agent = office_manager.active_agents[aid]
		if agent == null or agent.profile_id != profile_id:
			continue
		if agent.visuals and agent.visuals.has_method("refresh_appearance"):
			agent.visuals.refresh_appearance(office_manager.agent_roster.get_agent(profile_id))
			refreshed = true
	return refreshed

func _tool_update_agent_appearance(args: Dictionary) -> Dictionary:
	if not office_manager:
		return _tool_error("No office_manager")

	# Find agent profile
	var result = _find_agent_profile(args)
	var profile: AgentProfile = result[0]
	if not profile:
		return _tool_error(result[1])

	var changes: Array[String] = []
	var errors: Array[String] = []

	# Hair color
	if args.has("hair_color"):
		var parsed = _parse_color_index(args["hair_color"], HAIR_NAMES, HAIR_COLOR_COUNT)
		if parsed[0]:
			profile.hair_color_index = parsed[1]
			changes.append("hair_color=%d" % parsed[1])
		else:
			errors.append("hair_color: " + parsed[2])

	# Skin color
	if args.has("skin_color"):
		var parsed = _parse_color_index(args["skin_color"], SKIN_NAMES, SKIN_TONE_COUNT)
		if parsed[0]:
			profile.skin_color_index = parsed[1]
			changes.append("skin_color=%d" % parsed[1])
		else:
			errors.append("skin_color: " + parsed[2])

	# Hair style (numeric only)
	if args.has("hair_style"):
		var hs_raw = args["hair_style"]
		if hs_raw is int or hs_raw is float:
			var hs = int(hs_raw)
			if hs >= 0 and hs < HAIR_STYLE_COUNT:
				profile.hair_style_index = hs
				changes.append("hair_style=%d" % hs)
			else:
				errors.append("hair_style: Index %d out of range (0-%d)" % [hs, HAIR_STYLE_COUNT - 1])
		else:
			errors.append("hair_style: Must be integer")

	# Gender presentation
	if args.has("is_female"):
		profile.is_female = bool(args["is_female"])
		changes.append("is_female=%s" % str(profile.is_female))

	# Top color
	if args.has("top_color"):
		var tc_raw = args["top_color"]
		if tc_raw is int or tc_raw is float:
			var tc = int(tc_raw)
			if tc >= 0 and tc < TOP_COLOR_COUNT:
				profile.blouse_color_index = tc
				changes.append("top_color=%d" % tc)
			else:
				errors.append("top_color: Index %d out of range (0-%d)" % [tc, TOP_COLOR_COUNT - 1])
		else:
			errors.append("top_color: Must be integer")

	# Bottom type
	if args.has("bottom_type"):
		var bt = args["bottom_type"]
		if bt is String:
			var bt_lower = bt.to_lower()
			if bt_lower == "skirt":
				profile.bottom_type = 1
			elif bt_lower == "pants":
				profile.bottom_type = 0
			else:
				errors.append("bottom_type: Must be 'pants' or 'skirt'")
				bt = null
			if bt != null:
				changes.append("bottom_type=%d" % profile.bottom_type)
		elif bt is int or bt is float:
			var bti = int(bt)
			if bti == 0 or bti == 1:
				profile.bottom_type = bti
				changes.append("bottom_type=%d" % bti)
			else:
				errors.append("bottom_type: Must be 0 (pants) or 1 (skirt)")
		else:
			errors.append("bottom_type: Invalid type")

	# Bottom color
	if args.has("bottom_color"):
		var bc_raw = args["bottom_color"]
		if bc_raw is int or bc_raw is float:
			var bc = int(bc_raw)
			if bc >= 0 and bc < BOTTOM_COLOR_COUNT:
				profile.bottom_color_index = bc
				changes.append("bottom_color=%d" % bc)
			else:
				errors.append("bottom_color: Index %d out of range (0-%d)" % [bc, BOTTOM_COLOR_COUNT - 1])
		else:
			errors.append("bottom_color: Must be integer")

	# Report errors if any properties failed
	if not errors.is_empty():
		return _tool_error("Validation failed: " + "; ".join(errors))

	if changes.is_empty():
		return _tool_error("No appearance properties specified to update")

	# Save and refresh
	office_manager.agent_roster.save_profile(profile)
	var refreshed = _refresh_agent_visuals(profile.id)
	if office_manager.has_method("_update_vip_photo"):
		office_manager._update_vip_photo()

	var msg = "Updated %s: %s" % [profile.agent_name, ", ".join(changes)]
	if refreshed:
		msg += " (visuals refreshed)"
	return _tool_ok(msg)

func _tool_json(data: Dictionary) -> Dictionary:
	return {
		"content": [{
			"type": "text",
			"text": JSON.stringify(data, "  ")
		}]
	}

func _tool_ok(message: String) -> Dictionary:
	return {
		"content": [{
			"type": "text",
			"text": message
		}]
	}

func _tool_error(message: String) -> Dictionary:
	return {
		"content": [{
			"type": "text",
			"text": "Error: " + message
		}],
		"isError": true
	}

func _build_summary() -> Dictionary:
	if office_manager == null:
		return {"status": "unavailable"}
	var summary = {
		"agents_active": office_manager.active_agents.size(),
		"sessions": office_manager.agents_by_session.size(),
		"timestamp": Time.get_datetime_string_from_system()
	}
	if office_manager.transcript_watcher and office_manager.transcript_watcher.has_method("get_harness_summary"):
		summary["watchers"] = office_manager.transcript_watcher.get_harness_summary()
	return summary

func _build_agents() -> Dictionary:
	var agents: Array = []
	if office_manager:
		for agent_id in office_manager.active_agents.keys():
			var agent = office_manager.active_agents[agent_id]
			if agent:
				agents.append(_snapshot_agent(agent))
	return {"agents": agents}

func _snapshot_agent(agent) -> Dictionary:
	var state_name = str(agent.state)
	if agent is Agent:
		state_name = Agent.State.keys()[agent.state]
	return {
		"agent_id": agent.agent_id,
		"agent_type": agent.agent_type,
		"description": agent.description,
		"state": state_name,
		"session_id": agent.session_id,
		"profile_name": agent.profile_name,
		"profile_level": agent.profile_level,
		"position": {"x": agent.position.x, "y": agent.position.y}
	}

func _build_watchers() -> Dictionary:
	var data: Dictionary = {}
	if office_manager:
		if office_manager.transcript_watcher and office_manager.transcript_watcher.has_method("get_harness_summary"):
			data["harnesses"] = office_manager.transcript_watcher.get_harness_summary()
		data["mcp"] = get_mcp_config()
	return data

func _build_sessions() -> Dictionary:
	var sessions: Array = []
	if office_manager and office_manager.transcript_watcher:
		for path in office_manager.transcript_watcher.watched_sessions.keys():
			var session = office_manager.transcript_watcher.watched_sessions[path]
			sessions.append({
				"path": path,
				"harness_id": session.get("harness_id", "unknown"),
				"last_modified": session.get("last_modified", 0)
			})
	return {"sessions": sessions}

func _load_mcp_config() -> void:
	enabled = true
	port = DEFAULT_PORT
	bind_address = DEFAULT_BIND_ADDRESS
	if not FileAccess.file_exists(WATCHER_CONFIG_FILE):
		return
	var file = FileAccess.open(WATCHER_CONFIG_FILE, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		return
	var data = json.data
	if not data is Dictionary:
		return
	var mcp = data.get("mcp", {})
	if mcp is Dictionary:
		enabled = bool(mcp.get("enabled", enabled))
		port = int(mcp.get("port", port))
		bind_address = str(mcp.get("bind_address", bind_address)).strip_edges()
		if bind_address.is_empty():
			bind_address = DEFAULT_BIND_ADDRESS

func _save_mcp_config() -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(WATCHER_CONFIG_FILE):
		var file = FileAccess.open(WATCHER_CONFIG_FILE, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				data = json.data
			file.close()

	data["version"] = 1
	data["mcp"] = {
		"enabled": enabled,
		"port": port,
		"bind_address": bind_address
	}
	if not data.has("harnesses"):
		data["harnesses"] = {}
	if not data.has("tcp"):
		data["tcp"] = {}

	var out = FileAccess.open(WATCHER_CONFIG_FILE, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(data, "\t"))
		out.close()
