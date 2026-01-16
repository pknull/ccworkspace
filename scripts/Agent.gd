extends Node2D
class_name Agent

signal work_completed(agent: Agent)

enum State { SPAWNING, WALKING_TO_DESK, WORKING, DELIVERING, COMPLETING, IDLE }

# Shirt/tie colors by agent type (more muted, office-appropriate)
const AGENT_COLORS = {
	"main": Color(0.85, 0.75, 0.55),          # Tan/khaki - the boss
	"Explore": Color(0.45, 0.55, 0.70),       # Dusty blue - researcher
	"Coder": Color(0.50, 0.60, 0.50),         # Sage green - developer
	"full-stack-developer": Color(0.50, 0.60, 0.50),
	"debugger": Color(0.70, 0.45, 0.45),      # Dusty red - bug hunter
	"refactoring-specialist": Color(0.60, 0.50, 0.65),  # Muted purple
	"test-automator": Color(0.70, 0.65, 0.45),  # Mustard - QA
	"research-assistant": Color(0.50, 0.65, 0.65),  # Teal
	"Plan": Color(0.70, 0.55, 0.45),          # Terracotta - planner
	"code-reviewer": Color(0.55, 0.50, 0.60), # Mauve - reviewer
	"default": Color(0.55, 0.55, 0.55)        # Gray
}

const AGENT_LABELS = {
	"main": "Claude",
	"Explore": "Explorer",
	"Coder": "Coder",
	"full-stack-developer": "Developer",
	"debugger": "Debugger",
	"refactoring-specialist": "Architect",
	"test-automator": "QA",
	"research-assistant": "Researcher",
	"Plan": "Planner",
	"code-reviewer": "Reviewer",
	"default": "Worker"
}

const TOOL_ICONS = {
	"Bash": "[>_]",
	"Read": "[R]",
	"Edit": "[E]",
	"Write": "[W]",
	"Glob": "[*]",
	"Grep": "[?]",
	"WebFetch": "[W]",
	"WebSearch": "[S]",
	"Task": "[T]",
	"NotebookEdit": "[N]"
}

const TOOL_COLORS = {
	"Bash": Color(0.2, 0.8, 0.2),
	"Read": Color(0.4, 0.6, 1.0),
	"Edit": Color(1.0, 0.8, 0.2),
	"Write": Color(1.0, 0.6, 0.2),
	"Glob": Color(0.8, 0.4, 1.0),
	"Grep": Color(0.8, 0.4, 1.0),
	"WebFetch": Color(0.2, 0.8, 0.8),
	"WebSearch": Color(0.2, 0.8, 0.8),
	"Task": Color(0.9, 0.5, 0.2),
	"NotebookEdit": Color(1.0, 0.6, 0.2)
}

@export var agent_type: String = "default"
@export var description: String = ""

var agent_id: String = ""
var parent_id: String = ""
var session_id: String = ""
var state: State = State.SPAWNING
var target_position: Vector2
var assigned_desk: Node2D = null
var inbox_position: Vector2 = Vector2(1100, 550)
var work_timer: float = 0.0
var spawn_timer: float = 0.0
var is_waiting_for_completion: bool = true
var pending_completion: bool = false
var min_work_time: float = 3.0  # Minimum seconds to show working at desk
var work_elapsed: float = 0.0

# Document being carried
var document: ColorRect = null

# Visual nodes
var body: ColorRect
var shirt: ColorRect
var tie: ColorRect
var head: ColorRect
var hair: ColorRect
var status_label: Label
var type_label: Label
var tool_label: Label
var tool_bg: ColorRect

# Hover tooltip
var tooltip_panel: ColorRect
var tooltip_label: Label
var is_hovered: bool = false

# Tool display
var current_tool: String = ""
var tool_display_timer: float = 0.0

var _visuals_created: bool = false

func _init() -> void:
	_create_visuals()
	_visuals_created = true

func _ready() -> void:
	if not _visuals_created:
		_create_visuals()
		_visuals_created = true
	_update_appearance()
	if description and status_label:
		set_description(description)
	spawn_timer = 0.5

func _create_visuals() -> void:
	# Legs (dark trousers)
	var left_leg = ColorRect.new()
	left_leg.size = Vector2(10, 18)
	left_leg.position = Vector2(-12, 15)
	left_leg.color = Color(0.25, 0.25, 0.28)
	add_child(left_leg)

	var right_leg = ColorRect.new()
	right_leg.size = Vector2(10, 18)
	right_leg.position = Vector2(2, 15)
	right_leg.color = Color(0.25, 0.25, 0.28)
	add_child(right_leg)

	# Body/torso (white shirt)
	body = ColorRect.new()
	body.size = Vector2(26, 32)
	body.position = Vector2(-13, -15)
	body.color = Color(0.95, 0.95, 0.93)  # Off-white shirt
	add_child(body)

	# Shirt collar points
	var collar_left = ColorRect.new()
	collar_left.size = Vector2(8, 6)
	collar_left.position = Vector2(-11, -15)
	collar_left.color = Color(0.95, 0.95, 0.93)
	add_child(collar_left)

	var collar_right = ColorRect.new()
	collar_right.size = Vector2(8, 6)
	collar_right.position = Vector2(3, -15)
	collar_right.color = Color(0.95, 0.95, 0.93)
	add_child(collar_right)

	# Tie (colored by agent type)
	tie = ColorRect.new()
	tie.size = Vector2(6, 22)
	tie.position = Vector2(-3, -12)
	add_child(tie)

	# Tie knot
	var tie_knot = ColorRect.new()
	tie_knot.name = "TieKnot"
	tie_knot.size = Vector2(8, 5)
	tie_knot.position = Vector2(-4, -15)
	add_child(tie_knot)

	# Head (skin tone)
	head = ColorRect.new()
	head.size = Vector2(18, 18)
	head.position = Vector2(-9, -35)
	head.color = Color(0.87, 0.75, 0.65)  # Skin tone
	add_child(head)

	# Hair
	hair = ColorRect.new()
	hair.size = Vector2(20, 8)
	hair.position = Vector2(-10, -40)
	hair.color = Color(0.35, 0.25, 0.20)  # Brown hair
	add_child(hair)

	# Eyes (simple dots)
	var left_eye = ColorRect.new()
	left_eye.size = Vector2(3, 3)
	left_eye.position = Vector2(-6, -30)
	left_eye.color = Color(0.2, 0.2, 0.2)
	add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(3, 3)
	right_eye.position = Vector2(3, -30)
	right_eye.color = Color(0.2, 0.2, 0.2)
	add_child(right_eye)

	# Type label (small, above head)
	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.position = Vector2(-40, -55)
	type_label.size = Vector2(80, 16)
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	add_child(type_label)

	# Status label background
	var status_bg = ColorRect.new()
	status_bg.name = "StatusBg"
	status_bg.size = Vector2(120, 16)
	status_bg.position = Vector2(-60, -72)
	status_bg.color = Color(0.2, 0.2, 0.22, 0.9)
	add_child(status_bg)

	# Status label
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(-60, -73)
	status_label.size = Vector2(120, 16)
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	add_child(status_label)

	# Tool indicator
	tool_bg = ColorRect.new()
	tool_bg.size = Vector2(32, 20)
	tool_bg.position = Vector2(18, -30)
	tool_bg.color = Color(0.15, 0.15, 0.18, 0.9)
	tool_bg.visible = false
	add_child(tool_bg)

	tool_label = Label.new()
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tool_label.position = Vector2(18, -30)
	tool_label.size = Vector2(32, 20)
	tool_label.add_theme_font_size_override("font_size", 12)
	tool_label.visible = false
	add_child(tool_label)

	# Hover tooltip (hidden by default)
	_create_tooltip()

func _create_tooltip() -> void:
	tooltip_panel = ColorRect.new()
	tooltip_panel.size = Vector2(200, 80)
	tooltip_panel.position = Vector2(30, -60)
	tooltip_panel.color = Color(0.95, 0.93, 0.85, 0.98)  # Cream paper
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100  # Always on top
	add_child(tooltip_panel)

	# Tooltip border
	var border = ColorRect.new()
	border.size = Vector2(200, 80)
	border.position = Vector2(0, 0)
	border.color = Color(0.6, 0.55, 0.45)
	tooltip_panel.add_child(border)

	var inner = ColorRect.new()
	inner.size = Vector2(196, 76)
	inner.position = Vector2(2, 2)
	inner.color = Color(0.95, 0.93, 0.85)
	tooltip_panel.add_child(inner)

	# Tooltip header
	var header = Label.new()
	header.name = "Header"
	header.position = Vector2(8, 6)
	header.size = Vector2(184, 18)
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	tooltip_panel.add_child(header)

	# Divider line
	var divider = ColorRect.new()
	divider.size = Vector2(184, 1)
	divider.position = Vector2(8, 24)
	divider.color = Color(0.7, 0.65, 0.55)
	tooltip_panel.add_child(divider)

	# Tooltip content
	tooltip_label = Label.new()
	tooltip_label.position = Vector2(8, 28)
	tooltip_label.size = Vector2(184, 48)
	tooltip_label.add_theme_font_size_override("font_size", 11)
	tooltip_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_panel.add_child(tooltip_label)

func _update_appearance() -> void:
	var color = AGENT_COLORS.get(agent_type, AGENT_COLORS["default"])
	tie.color = color
	var tie_knot_node = get_node_or_null("TieKnot")
	if tie_knot_node:
		tie_knot_node.color = color.darkened(0.1)
	type_label.text = AGENT_LABELS.get(agent_type, AGENT_LABELS["default"])

func _process(delta: float) -> void:
	_check_mouse_hover()

	if tool_display_timer > 0:
		tool_display_timer -= delta
		if tool_display_timer <= 0:
			_hide_tool()
		elif tool_display_timer < 0.5:
			var alpha = tool_display_timer / 0.5
			if tool_bg:
				tool_bg.modulate.a = alpha
			if tool_label:
				tool_label.modulate.a = alpha

	match state:
		State.SPAWNING:
			_process_spawning(delta)
		State.WALKING_TO_DESK:
			_process_walking_to_desk(delta)
		State.WORKING:
			_process_working(delta)
		State.DELIVERING:
			_process_delivering(delta)
		State.COMPLETING:
			_process_completing(delta)
		State.IDLE:
			pass

func _check_mouse_hover() -> void:
	var mouse_pos = get_local_mouse_position()
	# Check if mouse is within agent bounds (roughly -15 to 15 x, -45 to 30 y)
	var in_bounds = mouse_pos.x > -20 and mouse_pos.x < 20 and mouse_pos.y > -50 and mouse_pos.y < 35

	if in_bounds and not is_hovered:
		is_hovered = true
		_show_tooltip()
	elif not in_bounds and is_hovered:
		is_hovered = false
		_hide_tooltip()

func _show_tooltip() -> void:
	if tooltip_panel:
		var header = tooltip_panel.get_node_or_null("Header")
		if header:
			header.text = AGENT_LABELS.get(agent_type, "Worker") + " (" + agent_id.substr(0, 8) + ")"
		if tooltip_label:
			var state_text = ""
			match state:
				State.SPAWNING: state_text = "Spawning..."
				State.WALKING_TO_DESK: state_text = "Walking to desk"
				State.WORKING: state_text = "Working"
				State.DELIVERING: state_text = "Delivering work"
				State.COMPLETING: state_text = "Done!"
				State.IDLE: state_text = "Idle"

			tooltip_label.text = description if description else "(no description)"
			tooltip_label.text += "\n\nStatus: " + state_text
		tooltip_panel.visible = true

func _hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false

func _process_spawning(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = 1.0 - (spawn_timer / 0.5)
	if spawn_timer <= 0:
		modulate.a = 1.0
		if assigned_desk:
			state = State.WALKING_TO_DESK
			target_position = assigned_desk.get_work_position()
			if status_label:
				if pending_completion:
					status_label.text = "Finishing up..."
				else:
					status_label.text = "Going to desk..."
		else:
			state = State.IDLE

func _process_walking_to_desk(delta: float) -> void:
	var direction = target_position - position
	if direction.length() < 5:
		position = target_position
		# Start working - reset work timer
		work_elapsed = 0.0
		state = State.WORKING
		print("[Agent %s] Reached desk, starting work (pending_completion=%s)" % [agent_id, pending_completion])
		if status_label:
			status_label.text = "Working..."
	else:
		position += direction.normalized() * 180 * delta

func _process_working(delta: float) -> void:
	# Track work time
	work_elapsed += delta

	# Subtle typing animation
	if body:
		body.position.y = -15 + sin(Time.get_ticks_msec() * 0.008) * 1.5
	if head:
		head.position.y = -35 + sin(Time.get_ticks_msec() * 0.008) * 1.5

	# Check if we have a pending completion and met minimum work time
	if pending_completion:
		if work_elapsed >= min_work_time:
			print("[Agent %s] Min work time reached (%.1f >= %.1f), completing" % [agent_id, work_elapsed, min_work_time])
			pending_completion = false
			complete_work()

func _process_delivering(delta: float) -> void:
	var direction = inbox_position - position
	if direction.length() < 10:
		position = inbox_position
		_deliver_document()
		state = State.COMPLETING
		spawn_timer = 0.5
		if status_label:
			status_label.text = "Delivered!"
	else:
		position += direction.normalized() * 220 * delta

func _process_completing(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = spawn_timer / 0.5
	if spawn_timer <= 0:
		work_completed.emit(self)

func complete_work() -> void:
	_create_document()
	if assigned_desk:
		assigned_desk.set_occupied(false)
	state = State.DELIVERING
	if status_label:
		status_label.text = "Delivering..."

func _create_document() -> void:
	# Manila folder
	document = ColorRect.new()
	document.size = Vector2(18, 24)
	document.position = Vector2(-9, -65)
	document.color = Color(0.85, 0.78, 0.55)  # Manila folder color
	add_child(document)

	# Folder tab
	var tab = ColorRect.new()
	tab.size = Vector2(8, 4)
	tab.position = Vector2(5, -2)
	tab.color = Color(0.85, 0.78, 0.55)
	document.add_child(tab)

	# Paper sticking out
	var paper = ColorRect.new()
	paper.size = Vector2(14, 4)
	paper.position = Vector2(2, 2)
	paper.color = Color(0.98, 0.98, 0.95)
	document.add_child(paper)

func _deliver_document() -> void:
	if document:
		document.queue_free()
		document = null

func assign_desk(desk: Node2D) -> void:
	assigned_desk = desk
	desk.set_occupied(true)
	if state == State.IDLE or state == State.SPAWNING:
		if spawn_timer <= 0:
			state = State.WALKING_TO_DESK
			target_position = desk.get_work_position()
			if status_label:
				status_label.text = "Going to desk..."

func set_inbox_position(pos: Vector2) -> void:
	inbox_position = pos

func set_description(desc: String) -> void:
	description = desc
	if status_label:
		if desc.length() > 25:
			status_label.text = desc.substr(0, 22) + "..."
		else:
			status_label.text = desc

func force_complete() -> void:
	match state:
		State.WORKING:
			# If we haven't worked long enough, delay completion
			if work_elapsed >= min_work_time:
				complete_work()
			else:
				pending_completion = true
				if status_label:
					status_label.text = "Wrapping up..."
		State.SPAWNING, State.WALKING_TO_DESK:
			pending_completion = true
			if status_label:
				status_label.text = "Finishing up..."
		State.IDLE:
			state = State.COMPLETING
			spawn_timer = 0.5
		State.DELIVERING, State.COMPLETING:
			pass

func show_tool(tool_name: String) -> void:
	current_tool = tool_name
	tool_display_timer = 2.0

	if tool_label and tool_bg:
		var icon = TOOL_ICONS.get(tool_name, "[" + tool_name.substr(0, 1) + "]")
		var color = TOOL_COLORS.get(tool_name, Color(0.5, 0.5, 0.5))

		tool_label.text = icon
		tool_label.add_theme_color_override("font_color", color)
		tool_bg.color = Color(0.1, 0.1, 0.1, 0.9)

		tool_label.visible = true
		tool_bg.visible = true
		tool_label.modulate.a = 1.0
		tool_bg.modulate.a = 1.0

func _hide_tool() -> void:
	current_tool = ""
	if tool_label:
		tool_label.visible = false
	if tool_bg:
		tool_bg.visible = false
