extends Node
class_name EventServer

signal event_received(event_data: Dictionary)

const PORT = 9999
const BIND_ADDRESS = "127.0.0.1"  # Security: localhost only
const MAX_CLIENTS = 50
const MAX_MESSAGE_SIZE = 65536  # 64KB limit

var server: TCPServer
var _clients: Array[StreamPeerTCP] = []
var _client_buffers: Array[String] = []

func _ready() -> void:
	server = TCPServer.new()
	var err = server.listen(PORT, BIND_ADDRESS)
	if err != OK:
		push_error("Failed to start TCP server on %s:%d: %s" % [BIND_ADDRESS, PORT, error_string(err)])
		return
	print("[EventServer] Listening on %s:%d" % [BIND_ADDRESS, PORT])

func _process(_delta: float) -> void:
	if server == null:
		return

	# Accept new connections (with limit)
	while server.is_connection_available():
		if _clients.size() >= MAX_CLIENTS:
			var rejected = server.take_connection()
			if rejected:
				rejected.disconnect_from_host()
			push_warning("[EventServer] Connection rejected: max clients (%d) reached" % MAX_CLIENTS)
			break
		var peer = server.take_connection()
		if peer:
			_clients.append(peer)
			_client_buffers.append("")
			print("[EventServer] Client connected. Total: %d" % _clients.size())

	# Process existing clients
	var to_remove: Array[int] = []
	for i in range(_clients.size()):
		var client = _clients[i]
		client.poll()

		var status = client.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			to_remove.append(i)
			continue

		if status != StreamPeerTCP.STATUS_CONNECTED:
			continue

		# Read available data (with size limit)
		var available = client.get_available_bytes()
		if available > MAX_MESSAGE_SIZE:
			push_warning("[EventServer] Client exceeded max message size, disconnecting")
			to_remove.append(i)
			continue
		if available > 0:
			var data = client.get_data(available)
			if data[0] == OK:
				var buffer = _client_buffers[i] + data[1].get_string_from_utf8()
				if buffer.length() > MAX_MESSAGE_SIZE:
					push_warning("[EventServer] Client buffer exceeded max message size, disconnecting")
					to_remove.append(i)
					continue
				_process_buffer(i, buffer)

	# Remove disconnected clients (reverse order, properly disconnect)
	for i in range(to_remove.size() - 1, -1, -1):
		_clients[to_remove[i]].disconnect_from_host()
		_clients.remove_at(to_remove[i])
		_client_buffers.remove_at(to_remove[i])
		print("[EventServer] Client disconnected. Total: %d" % _clients.size())

func _process_buffer(client_index: int, buffer: String) -> void:
	# Handle multiple JSON objects in the buffer (newline delimited)
	var lines = buffer.split("\n")
	var remainder = ""

	if not buffer.ends_with("\n") and lines.size() > 0:
		remainder = lines.pop_back()
	elif lines.size() > 0 and lines[lines.size() - 1].is_empty():
		lines.pop_back()

	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		_process_line(line)

	_client_buffers[client_index] = remainder

func _process_line(line: String) -> void:
	var json = JSON.new()
	var err = json.parse(line)
	if err != OK:
		push_warning("[EventServer] Failed to parse JSON: %s" % line)
		return

	var data = json.get_data()
	if data is Dictionary:
		print("[EventServer] Event received: %s" % data.get("event", "unknown"))
		event_received.emit(data)

func _exit_tree() -> void:
	if server:
		server.stop()
		print("[EventServer] Server stopped")
