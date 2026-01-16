extends Node2D
class_name OfficeManager

const AgentScene = preload("res://scenes/Agent.tscn")
const TranscriptWatcherScript = preload("res://scripts/TranscriptWatcher.gd")

@export var spawn_point: Vector2 = Vector2(100, 400)

var desks: Array[Desk] = []
var active_agents: Dictionary = {}  # agent_id -> Agent
var agent_by_type: Dictionary = {}  # agent_type -> Array of agent_ids (for fallback)
var completed_count: int = 0
var inbox_position: Vector2 = Vector2(750, 550)

# UI elements
var inbox_label: Label
var status_label: Label
var inbox_visual: Node2D
var taskboard: Node2D
var session_labels: Dictionary = {}  # session_path -> Label

# Connection lines (parent to child)
var connection_lines: Array[Line2D] = []

# Track agents by session
var agents_by_session: Dictionary = {}  # session_id -> [agent_ids]

# Main orchestrator agent (always present)
var main_agent: Agent = null

# Event sources
@onready var event_server: EventServer = $EventServer
var transcript_watcher: Node = null

func _ready() -> void:
	_setup_ui()
	_create_desks()
	_create_inbox()
	_create_taskboard()
	_create_main_agent()

	# Connect TCP server (for external tools/hooks)
	event_server.event_received.connect(_on_event_received)

	# Create and connect transcript watcher (monitors .jsonl files directly)
	transcript_watcher = TranscriptWatcherScript.new()
	add_child(transcript_watcher)
	transcript_watcher.event_received.connect(_on_event_received)

	print("[OfficeManager] Ready. Desks: %d" % desks.size())

func _process(_delta: float) -> void:
	_update_taskboard()

func _setup_ui() -> void:
	# Title
	var title = Label.new()
	title.text = "AGENT OFFICE"
	title.position = Vector2(540, 20)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.2, 0.2, 0.3))
	add_child(title)

	# Status
	status_label = Label.new()
	status_label.text = "Waiting for events on port 9999..."
	status_label.position = Vector2(20, 680)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	add_child(status_label)

func _create_desks() -> void:
	# Create a tighter grid of desks (left side of screen)
	var desk_positions = [
		Vector2(220, 180),
		Vector2(370, 180),
		Vector2(520, 180),
		Vector2(670, 180),
		Vector2(220, 350),
		Vector2(370, 350),
		Vector2(520, 350),
		Vector2(670, 350),
	]

	for pos in desk_positions:
		var desk = Desk.new()
		desk.position = pos
		add_child(desk)
		desks.append(desk)

func _create_inbox() -> void:
	# Create inbox visual
	inbox_visual = Node2D.new()
	inbox_visual.position = inbox_position
	add_child(inbox_visual)

	# Inbox tray
	var tray = ColorRect.new()
	tray.size = Vector2(80, 30)
	tray.position = Vector2(-40, 0)
	tray.color = Color(0.4, 0.35, 0.3)
	inbox_visual.add_child(tray)

	# Inbox label
	inbox_label = Label.new()
	inbox_label.text = "INBOX: 0"
	inbox_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inbox_label.position = Vector2(-50, -30)
	inbox_label.size = Vector2(100, 25)
	inbox_label.add_theme_font_size_override("font_size", 16)
	inbox_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.2))
	inbox_visual.add_child(inbox_label)

	# Stack of completed documents (grows as work is delivered)
	var stack_base = ColorRect.new()
	stack_base.name = "DocumentStack"
	stack_base.size = Vector2(60, 5)
	stack_base.position = Vector2(-30, -5)
	stack_base.color = Color(1.0, 1.0, 0.9)
	inbox_visual.add_child(stack_base)

func _create_taskboard() -> void:
	taskboard = Node2D.new()
	taskboard.position = Vector2(820, 120)
	add_child(taskboard)

	# Taskboard background
	var bg = ColorRect.new()
	bg.size = Vector2(350, 400)
	bg.position = Vector2(0, 0)
	bg.color = Color(0.25, 0.25, 0.28, 0.9)
	taskboard.add_child(bg)

	# Taskboard header
	var header = Label.new()
	header.text = "SESSIONS"
	header.position = Vector2(10, 10)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	taskboard.add_child(header)

	# Divider line
	var divider = ColorRect.new()
	divider.size = Vector2(330, 2)
	divider.position = Vector2(10, 40)
	divider.color = Color(0.5, 0.5, 0.5)
	taskboard.add_child(divider)

func _update_taskboard() -> void:
	if not transcript_watcher:
		return

	var watched = transcript_watcher.watched_sessions
	var y_offset = 55

	# Clear old labels
	for path in session_labels.keys():
		if not watched.has(path):
			session_labels[path].queue_free()
			session_labels.erase(path)

	# Update/create labels for each session
	for path in watched.keys():
		var session_id = path.get_file().get_basename()
		var short_id = session_id.substr(0, 8)

		# Count agents for this session
		var agent_count = 0
		if agents_by_session.has(session_id):
			agent_count = agents_by_session[session_id].size()

		var text = "%s...  [%d agents]" % [short_id, agent_count]

		if session_labels.has(path):
			# Update existing
			session_labels[path].text = text
		else:
			# Create new label
			var label = Label.new()
			label.text = text
			label.position = Vector2(15, y_offset)
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			taskboard.add_child(label)
			session_labels[path] = label

		y_offset += 25

func _create_main_agent() -> void:
	# Create the main orchestrator agent (represents Claude)
	main_agent = AgentScene.instantiate() as Agent
	main_agent.agent_type = "main"
	main_agent.agent_id = "main"
	main_agent.description = "Orchestrator"
	main_agent.position = Vector2(100, 300)
	add_child(main_agent)

	# Main agent doesn't go to desk, just stays visible
	main_agent.state = Agent.State.IDLE
	if main_agent.status_label:
		main_agent.status_label.text = "Orchestrating..."

func _on_event_received(event_data: Dictionary) -> void:
	var event_type = event_data.get("event", "")
	var tool_name = event_data.get("tool", "")
	if tool_name:
		status_label.text = "Tool: %s" % tool_name
	else:
		status_label.text = "Event: %s" % event_type

	match event_type:
		"agent_spawn":
			_handle_agent_spawn(event_data)
		"agent_complete":
			_handle_agent_complete(event_data)
		"tool_use":
			_handle_tool_use(event_data)

func _handle_agent_spawn(data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "agent_%d" % Time.get_ticks_msec())
	var parent_id = data.get("parent_id", "main")
	var agent_type = data.get("agent_type", "default")
	var description = data.get("description", "")
	var session_path = data.get("session_path", "")
	var session_id = session_path.get_file().get_basename() if session_path else "unknown"

	print("[OfficeManager] Spawning agent: %s (%s) from parent %s" % [agent_type, agent_id, parent_id])

	# Track by session
	if not agents_by_session.has(session_id):
		agents_by_session[session_id] = []
	agents_by_session[session_id].append(agent_id)

	# Find available desk
	var desk = _find_available_desk()
	if desk == null:
		push_warning("No available desks!")
		return

	# Determine spawn position (from parent agent if exists)
	var spawn_pos = spawn_point
	if parent_id == "main" and main_agent:
		spawn_pos = main_agent.position + Vector2(50, 0)
	elif active_agents.has(parent_id):
		var parent = active_agents[parent_id] as Agent
		spawn_pos = parent.position + Vector2(30, 0)

	# Create agent
	var agent = AgentScene.instantiate() as Agent
	agent.agent_id = agent_id
	agent.parent_id = parent_id
	agent.agent_type = agent_type
	agent.session_id = session_id
	agent.position = spawn_pos
	agent.set_description(description)
	agent.set_inbox_position(inbox_position)
	agent.assign_desk(desk)
	agent.work_completed.connect(_on_agent_completed)
	add_child(agent)

	# Track agent
	active_agents[agent_id] = agent

	# Track by type for fallback completion matching
	if not agent_by_type.has(agent_type):
		agent_by_type[agent_type] = []
	agent_by_type[agent_type].append(agent_id)

	# Draw connection line from parent
	_draw_spawn_connection(spawn_pos, desk.get_work_position(), agent_type)

	status_label.text = "Spawned: %s" % agent_type

func _handle_agent_complete(data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "")

	# Try to find agent by ID
	if active_agents.has(agent_id):
		var agent = active_agents[agent_id] as Agent
		agent.force_complete()
		print("[OfficeManager] Completed agent: %s" % agent_id)
	else:
		# Fallback: complete the oldest agent of any type
		for aid in active_agents.keys():
			var agent = active_agents[aid] as Agent
			if agent.state == Agent.State.WORKING:
				agent.force_complete()
				print("[OfficeManager] Completed agent (fallback): %s" % aid)
				break

func _handle_tool_use(data: Dictionary) -> void:
	var tool_name = data.get("tool", "")
	var agent_id = data.get("agent_id", "main")

	# Find the agent and show tool indicator
	if agent_id == "main" and main_agent:
		main_agent.show_tool(tool_name)
	elif active_agents.has(agent_id):
		var agent = active_agents[agent_id] as Agent
		agent.show_tool(tool_name)
	else:
		# Fallback: show on most recently spawned working agent
		for aid in active_agents.keys():
			var agent = active_agents[aid] as Agent
			if agent.state == Agent.State.WORKING:
				agent.show_tool(tool_name)
				break

func _find_available_desk() -> Desk:
	for desk in desks:
		if desk.is_available():
			return desk
	return null

func _draw_spawn_connection(from_pos: Vector2, to_pos: Vector2, agent_type: String) -> void:
	# Create a brief line showing where agent came from
	var line = Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 2.0
	line.default_color = Agent.AGENT_COLORS.get(agent_type, Color(0.5, 0.5, 0.5))
	line.default_color.a = 0.5
	add_child(line)
	connection_lines.append(line)

	# Fade out and remove after 2 seconds
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func():
		line.queue_free()
		connection_lines.erase(line)
	)

func _on_agent_completed(agent: Agent) -> void:
	completed_count += 1
	inbox_label.text = "INBOX: %d" % completed_count

	# Grow the document stack visual
	var stack = inbox_visual.get_node_or_null("DocumentStack")
	if stack:
		stack.size.y = min(5 + completed_count * 2, 50)  # Cap at 50px height
		stack.position.y = -5 - stack.size.y + 5

	# Remove from tracking
	var aid = agent.agent_id
	if active_agents.has(aid):
		active_agents.erase(aid)

	# Remove from type tracking
	if agent_by_type.has(agent.agent_type):
		agent_by_type[agent.agent_type].erase(aid)

	# Remove from session tracking
	if agent.session_id and agents_by_session.has(agent.session_id):
		agents_by_session[agent.session_id].erase(aid)

	# Queue free after fade out
	agent.queue_free()
