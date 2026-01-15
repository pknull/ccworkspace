extends Node2D
class_name Agent

signal work_completed(agent: Agent)

enum State { SPAWNING, WALKING_TO_DESK, WORKING, DELIVERING, COMPLETING, IDLE }

const AGENT_COLORS = {
	"main": Color(0.9, 0.75, 0.3),           # Gold - main orchestrator
	"Explore": Color(0.2, 0.6, 1.0),         # Blue - researcher
	"Coder": Color(0.2, 0.8, 0.4),           # Green - developer
	"full-stack-developer": Color(0.2, 0.8, 0.4),  # Green - developer
	"debugger": Color(1.0, 0.4, 0.4),        # Red - bug hunter
	"refactoring-specialist": Color(0.8, 0.6, 1.0),  # Purple - architect
	"test-automator": Color(1.0, 0.8, 0.2),  # Yellow - QA
	"research-assistant": Color(0.4, 0.8, 0.8),  # Cyan - librarian
	"Plan": Color(0.9, 0.5, 0.2),            # Orange - planner
	"code-reviewer": Color(0.6, 0.4, 0.8),   # Purple - reviewer
	"default": Color(0.6, 0.6, 0.6)          # Gray - generic
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
	"Bash": Color(0.2, 0.8, 0.2),      # Green - terminal
	"Read": Color(0.4, 0.6, 1.0),      # Blue - reading
	"Edit": Color(1.0, 0.8, 0.2),      # Yellow - editing
	"Write": Color(1.0, 0.6, 0.2),     # Orange - writing
	"Glob": Color(0.8, 0.4, 1.0),      # Purple - search
	"Grep": Color(0.8, 0.4, 1.0),      # Purple - search
	"WebFetch": Color(0.2, 0.8, 0.8),  # Cyan - web
	"WebSearch": Color(0.2, 0.8, 0.8), # Cyan - web
	"Task": Color(0.9, 0.5, 0.2),      # Orange - task
	"NotebookEdit": Color(1.0, 0.6, 0.2)  # Orange - notebook
}

@export var agent_type: String = "default"
@export var description: String = ""

var agent_id: String = ""
var parent_id: String = ""
var state: State = State.SPAWNING
var target_position: Vector2
var assigned_desk: Node2D = null
var inbox_position: Vector2 = Vector2(1100, 550)  # Where to deliver work
var work_timer: float = 0.0
var spawn_timer: float = 0.0
var is_waiting_for_completion: bool = true  # Don't auto-complete, wait for event

# Document being carried (shown during DELIVERING)
var document: ColorRect = null

# Visual nodes (created in _ready)
var body: ColorRect
var head: ColorRect
var status_label: Label
var type_label: Label
var tool_label: Label
var tool_bg: ColorRect

# Tool display
var current_tool: String = ""
var tool_display_timer: float = 0.0

var _visuals_created: bool = false

func _init() -> void:
	# Create visuals immediately so they exist before _ready
	_create_visuals()
	_visuals_created = true

func _ready() -> void:
	if not _visuals_created:
		_create_visuals()
		_visuals_created = true
	_update_appearance()
	# Apply description if it was set before _ready
	if description and status_label:
		set_description(description)
	spawn_timer = 0.5  # Brief spawn animation

func _create_visuals() -> void:
	# Body (torso)
	body = ColorRect.new()
	body.size = Vector2(30, 40)
	body.position = Vector2(-15, -20)
	add_child(body)

	# Head
	head = ColorRect.new()
	head.size = Vector2(20, 20)
	head.position = Vector2(-10, -45)
	add_child(head)

	# Type label (above head)
	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.position = Vector2(-50, -70)
	type_label.size = Vector2(100, 20)
	type_label.add_theme_font_size_override("font_size", 12)
	add_child(type_label)

	# Status label (speech bubble style)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(-60, -90)
	status_label.size = Vector2(120, 20)
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	add_child(status_label)

	# Tool indicator (floats to the right of agent)
	tool_bg = ColorRect.new()
	tool_bg.size = Vector2(36, 22)
	tool_bg.position = Vector2(20, -40)
	tool_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	tool_bg.visible = false
	add_child(tool_bg)

	tool_label = Label.new()
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tool_label.position = Vector2(20, -40)
	tool_label.size = Vector2(36, 22)
	tool_label.add_theme_font_size_override("font_size", 14)
	tool_label.visible = false
	add_child(tool_label)

func _update_appearance() -> void:
	var color = AGENT_COLORS.get(agent_type, AGENT_COLORS["default"])
	body.color = color
	head.color = color.lightened(0.2)
	type_label.text = AGENT_LABELS.get(agent_type, AGENT_LABELS["default"])

func _process(delta: float) -> void:
	# Update tool display timer
	if tool_display_timer > 0:
		tool_display_timer -= delta
		if tool_display_timer <= 0:
			_hide_tool()
		elif tool_display_timer < 0.5:
			# Fade out
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

func _process_spawning(delta: float) -> void:
	spawn_timer -= delta
	# Fade in effect
	modulate.a = 1.0 - (spawn_timer / 0.5)
	if spawn_timer <= 0:
		modulate.a = 1.0
		if assigned_desk:
			state = State.WALKING_TO_DESK
			target_position = assigned_desk.get_work_position()
			if status_label:
				status_label.text = "Going to desk..."
		else:
			state = State.IDLE

func _process_walking_to_desk(delta: float) -> void:
	var direction = target_position - position
	if direction.length() < 5:
		position = target_position
		state = State.WORKING
		if status_label:
			status_label.text = "Working..."
		# Don't use a timer - wait for actual completion event
	else:
		position += direction.normalized() * 200 * delta

func _process_working(delta: float) -> void:
	# Bobbing animation while working
	if body:
		body.position.y = -20 + sin(Time.get_ticks_msec() * 0.005) * 2
	if head:
		head.position.y = -45 + sin(Time.get_ticks_msec() * 0.005) * 2
	# Wait for force_complete() to be called from event

func _process_delivering(delta: float) -> void:
	var direction = inbox_position - position
	if direction.length() < 10:
		# Arrived at inbox
		position = inbox_position
		_deliver_document()
		state = State.COMPLETING
		spawn_timer = 0.5
		if status_label:
			status_label.text = "Delivered!"
	else:
		position += direction.normalized() * 250 * delta  # Walk faster when delivering

func _process_completing(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = spawn_timer / 0.5
	if spawn_timer <= 0:
		work_completed.emit(self)

func complete_work() -> void:
	# Create document to carry
	_create_document()
	# Release the desk
	if assigned_desk:
		assigned_desk.set_occupied(false)
	# Start walking to inbox
	state = State.DELIVERING
	if status_label:
		status_label.text = "Delivering..."

func _create_document() -> void:
	# Create a small document visual that the agent carries
	document = ColorRect.new()
	document.size = Vector2(15, 20)
	document.position = Vector2(-7, -65)  # Above head
	document.color = Color(1.0, 1.0, 0.9)  # Paper color
	add_child(document)

	# Add lines on document
	var line1 = ColorRect.new()
	line1.size = Vector2(10, 2)
	line1.position = Vector2(2, 4)
	line1.color = Color(0.3, 0.3, 0.3)
	document.add_child(line1)

	var line2 = ColorRect.new()
	line2.size = Vector2(8, 2)
	line2.position = Vector2(2, 8)
	line2.color = Color(0.3, 0.3, 0.3)
	document.add_child(line2)

func _deliver_document() -> void:
	# Remove document from agent (it's been delivered)
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
	# Update label if it exists (may be called before _ready)
	if status_label:
		if desc.length() > 30:
			status_label.text = desc.substr(0, 27) + "..."
		else:
			status_label.text = desc

func force_complete() -> void:
	# Called when SubagentStop is received
	if state == State.WORKING:
		complete_work()

func show_tool(tool_name: String) -> void:
	current_tool = tool_name
	tool_display_timer = 2.0  # Show for 2 seconds

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
