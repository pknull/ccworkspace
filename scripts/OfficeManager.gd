extends Node2D
class_name OfficeManager

const AgentScene = preload("res://scenes/Agent.tscn")
const TranscriptWatcherScript = preload("res://scripts/TranscriptWatcher.gd")

@export var spawn_point: Vector2 = Vector2(100, 400)

var desks: Array[Desk] = []
var active_agents: Dictionary = {}  # agent_id -> Agent
var agent_by_type: Dictionary = {}  # agent_type -> Array of agent_ids (for fallback)
var completed_count: int = 0
var inbox_position: Vector2 = Vector2(370, 520)

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
	# Office floor (carpet tiles)
	var floor_bg = ColorRect.new()
	floor_bg.size = Vector2(1280, 720)
	floor_bg.position = Vector2(0, 0)
	floor_bg.color = Color(0.55, 0.52, 0.48)  # Gray-brown office carpet
	floor_bg.z_index = -10
	add_child(floor_bg)

	# Add some carpet tile lines for texture
	for i in range(0, 1280, 80):
		var vline = ColorRect.new()
		vline.size = Vector2(1, 720)
		vline.position = Vector2(i, 0)
		vline.color = Color(0.50, 0.47, 0.43, 0.3)
		vline.z_index = -9
		add_child(vline)
	for i in range(0, 720, 80):
		var hline = ColorRect.new()
		hline.size = Vector2(1280, 1)
		hline.position = Vector2(0, i)
		hline.color = Color(0.50, 0.47, 0.43, 0.3)
		hline.z_index = -9
		add_child(hline)

	# Wall at top
	var wall = ColorRect.new()
	wall.size = Vector2(1280, 60)
	wall.position = Vector2(0, 0)
	wall.color = Color(0.85, 0.82, 0.78)  # Beige wall
	wall.z_index = -8
	add_child(wall)

	# Skirting board
	var skirting = ColorRect.new()
	skirting.size = Vector2(1280, 8)
	skirting.position = Vector2(0, 60)
	skirting.color = Color(0.45, 0.40, 0.35)
	skirting.z_index = -7
	add_child(skirting)

	# Office decor - Water cooler (left side)
	_create_water_cooler(Vector2(50, 200))

	# Office decor - Potted plant (corner)
	_create_potted_plant(Vector2(50, 400))

	# Office decor - Filing cabinet
	_create_filing_cabinet(Vector2(50, 550))

	# Title - like a wall sign
	var sign_bg = ColorRect.new()
	sign_bg.size = Vector2(200, 40)
	sign_bg.position = Vector2(540, 10)
	sign_bg.color = Color(0.3, 0.35, 0.45)
	add_child(sign_bg)

	var title = Label.new()
	title.text = "AGENT OFFICE"
	title.position = Vector2(545, 15)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	add_child(title)

	# Status bar at bottom
	var status_bg = ColorRect.new()
	status_bg.size = Vector2(1280, 30)
	status_bg.position = Vector2(0, 690)
	status_bg.color = Color(0.25, 0.25, 0.28)
	add_child(status_bg)

	status_label = Label.new()
	status_label.text = "Waiting for events..."
	status_label.position = Vector2(20, 695)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(status_label)

func _create_water_cooler(pos: Vector2) -> void:
	var cooler = Node2D.new()
	cooler.position = pos
	add_child(cooler)

	# Base
	var base = ColorRect.new()
	base.size = Vector2(30, 20)
	base.position = Vector2(-15, 30)
	base.color = Color(0.75, 0.75, 0.78)
	cooler.add_child(base)

	# Body
	var body = ColorRect.new()
	body.size = Vector2(26, 35)
	body.position = Vector2(-13, -5)
	body.color = Color(0.85, 0.85, 0.88)
	cooler.add_child(body)

	# Water bottle (blue tinted)
	var bottle = ColorRect.new()
	bottle.size = Vector2(20, 30)
	bottle.position = Vector2(-10, -35)
	bottle.color = Color(0.7, 0.85, 0.95, 0.8)
	cooler.add_child(bottle)

	# Tap
	var tap = ColorRect.new()
	tap.size = Vector2(8, 6)
	tap.position = Vector2(-4, 10)
	tap.color = Color(0.5, 0.5, 0.55)
	cooler.add_child(tap)

func _create_potted_plant(pos: Vector2) -> void:
	var plant = Node2D.new()
	plant.position = pos
	add_child(plant)

	# Pot
	var pot = ColorRect.new()
	pot.size = Vector2(30, 25)
	pot.position = Vector2(-15, 20)
	pot.color = Color(0.6, 0.35, 0.25)  # Terracotta
	plant.add_child(pot)

	# Soil
	var soil = ColorRect.new()
	soil.size = Vector2(26, 6)
	soil.position = Vector2(-13, 18)
	soil.color = Color(0.3, 0.25, 0.2)
	plant.add_child(soil)

	# Leaves (simple green rectangles at angles)
	var leaf1 = ColorRect.new()
	leaf1.size = Vector2(20, 8)
	leaf1.position = Vector2(-18, 0)
	leaf1.color = Color(0.3, 0.55, 0.3)
	leaf1.rotation = -0.4
	plant.add_child(leaf1)

	var leaf2 = ColorRect.new()
	leaf2.size = Vector2(22, 8)
	leaf2.position = Vector2(-5, -10)
	leaf2.color = Color(0.35, 0.6, 0.35)
	leaf2.rotation = 0.3
	plant.add_child(leaf2)

	var leaf3 = ColorRect.new()
	leaf3.size = Vector2(18, 8)
	leaf3.position = Vector2(0, 5)
	leaf3.color = Color(0.3, 0.5, 0.3)
	leaf3.rotation = 0.5
	plant.add_child(leaf3)

func _create_filing_cabinet(pos: Vector2) -> void:
	var cabinet = Node2D.new()
	cabinet.position = pos
	add_child(cabinet)

	# Cabinet body
	var body = ColorRect.new()
	body.size = Vector2(40, 80)
	body.position = Vector2(-20, -40)
	body.color = Color(0.5, 0.5, 0.52)  # Gray metal
	cabinet.add_child(body)

	# Drawers (3 of them)
	for i in range(3):
		var drawer = ColorRect.new()
		drawer.size = Vector2(36, 22)
		drawer.position = Vector2(-18, -36 + i * 26)
		drawer.color = Color(0.55, 0.55, 0.58)
		cabinet.add_child(drawer)

		# Drawer handle
		var handle = ColorRect.new()
		handle.size = Vector2(12, 4)
		handle.position = Vector2(-6, -30 + i * 26)
		handle.color = Color(0.4, 0.4, 0.42)
		cabinet.add_child(handle)

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
	# Create inbox visual - office desk tray style
	inbox_visual = Node2D.new()
	inbox_visual.position = inbox_position
	add_child(inbox_visual)

	# Tray base (dark plastic)
	var tray_base = ColorRect.new()
	tray_base.size = Vector2(80, 12)
	tray_base.position = Vector2(-40, 15)
	tray_base.color = Color(0.2, 0.2, 0.22)
	inbox_visual.add_child(tray_base)

	# Tray back
	var tray_back = ColorRect.new()
	tray_back.size = Vector2(80, 35)
	tray_back.position = Vector2(-40, -20)
	tray_back.color = Color(0.25, 0.25, 0.28)
	inbox_visual.add_child(tray_back)

	# Tray sides
	var tray_left = ColorRect.new()
	tray_left.size = Vector2(6, 35)
	tray_left.position = Vector2(-40, -20)
	tray_left.color = Color(0.22, 0.22, 0.25)
	inbox_visual.add_child(tray_left)

	var tray_right = ColorRect.new()
	tray_right.size = Vector2(6, 35)
	tray_right.position = Vector2(34, -20)
	tray_right.color = Color(0.22, 0.22, 0.25)
	inbox_visual.add_child(tray_right)

	# Some papers in the tray
	var paper1 = ColorRect.new()
	paper1.size = Vector2(60, 4)
	paper1.position = Vector2(-30, 5)
	paper1.color = Color(0.95, 0.95, 0.92)
	inbox_visual.add_child(paper1)

	var paper2 = ColorRect.new()
	paper2.size = Vector2(58, 4)
	paper2.position = Vector2(-28, 0)
	paper2.color = Color(0.92, 0.92, 0.88)
	inbox_visual.add_child(paper2)

	# Count badge (red circle with number)
	var badge_bg = ColorRect.new()
	badge_bg.size = Vector2(28, 28)
	badge_bg.position = Vector2(25, -35)
	badge_bg.color = Color(0.75, 0.25, 0.2)
	inbox_visual.add_child(badge_bg)

	inbox_label = Label.new()
	inbox_label.text = "0"
	inbox_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inbox_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inbox_label.position = Vector2(25, -35)
	inbox_label.size = Vector2(28, 28)
	inbox_label.add_theme_font_size_override("font_size", 16)
	inbox_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	inbox_visual.add_child(inbox_label)

	# "IN" label on tray
	var title = Label.new()
	title.text = "IN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-40, -15)
	title.size = Vector2(80, 20)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	inbox_visual.add_child(title)

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
	main_agent.position = Vector2(220, 520)  # Below worker desks, left of inbox
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

	# Find available desk FIRST (before tracking)
	var desk = _find_available_desk()
	if desk == null:
		push_warning("No available desks!")
		return

	# Track by session (only after confirming desk available)
	if not agents_by_session.has(session_id):
		agents_by_session[session_id] = []
	agents_by_session[session_id].append(agent_id)

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
		# Log active agents for debugging
		print("[OfficeManager] Agent %s not found. Active agents: %s" % [agent_id, active_agents.keys()])
		# Fallback: complete any active agent (not just WORKING - could be SPAWNING/WALKING)
		var completed_fallback = false
		for aid in active_agents.keys():
			var agent = active_agents[aid] as Agent
			# Skip agents already completing/delivering
			if agent.state != Agent.State.COMPLETING and agent.state != Agent.State.DELIVERING:
				agent.force_complete()
				print("[OfficeManager] Completed agent (fallback): %s (state was %d)" % [aid, agent.state])
				completed_fallback = true
				break
		if not completed_fallback:
			print("[OfficeManager] WARNING: No agent to complete!")

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
	inbox_label.text = str(completed_count)

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
