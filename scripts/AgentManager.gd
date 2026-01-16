extends Node
class_name AgentManager

# Manages agent lifecycle: spawning, tracking, completion, and cleanup
# Extracts agent management logic from OfficeManager for better separation of concerns

signal agent_spawned(agent: Agent)
signal agent_completed(agent: Agent)

const AgentScene = preload("res://scenes/Agent.tscn")

# Agent tracking
var active_agents: Dictionary = {}  # agent_id -> Agent
var agent_by_type: Dictionary = {}  # agent_type -> Array of agent_ids (for fallback)
var agents_by_session: Dictionary = {}  # session_id -> [agent_ids]
var completed_count: int = 0

# Session orchestrator agents (one per active session)
var session_orchestrators: Dictionary = {}  # session_id -> Agent
var idle_orchestrators: Array[Agent] = []

# References set by OfficeManager
var desks: Array[Desk] = []
var spawn_point: Vector2 = Vector2(640, 620)
var office_obstacles: Array[Rect2] = []

# Item positions (kept in sync with OfficeManager)
var shredder_position: Vector2 = Vector2(1200, 520)
var water_cooler_position: Vector2 = Vector2(50, 200)
var plant_position: Vector2 = Vector2(50, 400)
var filing_cabinet_position: Vector2 = Vector2(50, 550)

# Table mapping item names to position setter method names
const POSITION_SETTERS = {
	"water_cooler": "set_water_cooler_position",
	"plant": "set_plant_position",
	"filing_cabinet": "set_filing_cabinet_position",
	"shredder": "set_shredder_position",
}

func spawn_agent(data: Dictionary, parent_node: Node2D) -> Agent:
	var agent_id = data.get("agent_id", "agent_%d" % Time.get_ticks_msec())
	var parent_id = data.get("parent_id", "main")
	var agent_type = data.get("agent_type", "default")
	var description = data.get("description", "")
	var session_path = data.get("session_path", "")
	var session_id = session_path.get_file().get_basename() if session_path else "unknown"

	print("[AgentManager] Spawning agent: %s (%s) from parent %s" % [agent_type, agent_id, parent_id])

	# Find available desk
	var desk = _find_available_desk()
	if desk == null:
		push_warning("No available desks!")
		return null

	# Track by session
	if not agents_by_session.has(session_id):
		agents_by_session[session_id] = []
	agents_by_session[session_id].append(agent_id)

	# Determine spawn position
	var spawn_pos = spawn_point
	if session_id and session_orchestrators.has(session_id):
		spawn_pos = session_orchestrators[session_id].position + Vector2(50, 0)
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
	_configure_agent_positions(agent)
	agent.set_obstacles(office_obstacles)
	agent.assign_desk(desk)
	agent.work_completed.connect(_on_agent_completed)
	parent_node.add_child(agent)

	# Track agent
	active_agents[agent_id] = agent

	# Track by type for fallback completion matching
	if not agent_by_type.has(agent_type):
		agent_by_type[agent_type] = []
	agent_by_type[agent_type].append(agent_id)

	agent_spawned.emit(agent)
	return agent

func complete_agent(agent_id: String) -> void:
	# Try to find agent by ID
	if active_agents.has(agent_id):
		var agent = active_agents[agent_id] as Agent
		agent.force_complete()
		print("[AgentManager] Completed agent: %s" % agent_id)
	else:
		# Log active agents for debugging
		print("[AgentManager] Agent %s not found. Active agents: %s" % [agent_id, active_agents.keys()])
		# Fallback: complete any active agent (not just WORKING - could be SPAWNING/WALKING)
		var completed_fallback = false
		for aid in active_agents.keys():
			var agent = active_agents[aid] as Agent
			# Skip agents already completing/delivering
			if agent.state != Agent.State.COMPLETING and agent.state != Agent.State.DELIVERING:
				agent.force_complete()
				print("[AgentManager] Completed agent (fallback): %s (state was %d)" % [aid, agent.state])
				completed_fallback = true
				break
		if not completed_fallback:
			print("[AgentManager] WARNING: No agent to complete!")

func show_tool_on_agent(tool_name: String, agent_id: String, session_path: String) -> void:
	var session_id = session_path.get_file().get_basename() if session_path else ""

	# Find the agent and show tool indicator
	if active_agents.has(agent_id):
		var agent = active_agents[agent_id] as Agent
		agent.show_tool(tool_name)
	elif session_id and session_orchestrators.has(session_id):
		session_orchestrators[session_id].show_tool(tool_name)
	else:
		# Fallback: show on most recently spawned working agent
		for aid in active_agents.keys():
			var agent = active_agents[aid] as Agent
			if agent.state == Agent.State.WORKING:
				agent.show_tool(tool_name)
				break

func get_or_create_session_orchestrator(session_id: String, session_path: String, parent_node: Node2D) -> Agent:
	if session_orchestrators.has(session_id):
		return session_orchestrators[session_id]

	# Check for idle orchestrator to reuse
	if not idle_orchestrators.is_empty():
		var orchestrator = idle_orchestrators.pop_back()
		if is_instance_valid(orchestrator):
			var desk = _find_available_desk()
			if desk:
				orchestrator.agent_id = "orch_" + session_id.substr(0, 8)
				orchestrator.session_id = session_id
				orchestrator.description = "Session: " + session_id.substr(0, 8)
				orchestrator.assign_desk(desk)
				orchestrator.state = Agent.State.WALKING_TO_DESK
				session_orchestrators[session_id] = orchestrator
				print("[AgentManager] Reusing idle orchestrator for session: %s" % session_id.substr(0, 8))
				return orchestrator

	var desk = _find_available_desk()
	if desk == null:
		push_warning("No desk available for session orchestrator!")
		return null

	var orchestrator = AgentScene.instantiate() as Agent
	orchestrator.agent_type = "orchestrator"
	orchestrator.agent_id = "orch_" + session_id.substr(0, 8)
	orchestrator.session_id = session_id
	orchestrator.description = "Session: " + session_id.substr(0, 8)
	orchestrator.position = spawn_point
	_configure_agent_positions(orchestrator)
	orchestrator.set_obstacles(office_obstacles)
	orchestrator.assign_desk(desk)
	parent_node.add_child(orchestrator)

	orchestrator.is_waiting_for_completion = false
	orchestrator.min_work_time = 999999

	session_orchestrators[session_id] = orchestrator
	print("[AgentManager] Created session orchestrator: %s" % session_id.substr(0, 8))
	return orchestrator

func send_orchestrator_to_cooler(session_id: String) -> void:
	if not session_orchestrators.has(session_id):
		return

	var orchestrator = session_orchestrators[session_id] as Agent
	session_orchestrators.erase(session_id)

	if orchestrator and is_instance_valid(orchestrator):
		if orchestrator.assigned_desk:
			orchestrator.assigned_desk.set_occupied(false)
			orchestrator.assigned_desk = null
		orchestrator.state = Agent.State.IDLE
		var cooler_pos = water_cooler_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		orchestrator.position = cooler_pos
		idle_orchestrators.append(orchestrator)

func update_item_position(item_name: String, new_position: Vector2) -> void:
	# Update internal position tracking
	match item_name:
		"water_cooler":
			water_cooler_position = new_position
		"plant":
			plant_position = new_position
		"filing_cabinet":
			filing_cabinet_position = new_position
		"shredder":
			shredder_position = new_position

	# Update all agents
	var method_name = POSITION_SETTERS.get(item_name, "")
	if method_name.is_empty():
		return

	for agent in active_agents.values():
		if agent.has_method(method_name):
			agent.call(method_name, new_position)

	for orch in session_orchestrators.values():
		if orch.has_method(method_name):
			orch.call(method_name, new_position)

func update_obstacles(obstacles: Array[Rect2]) -> void:
	office_obstacles = obstacles
	for agent in active_agents.values():
		if agent.has_method("set_obstacles"):
			agent.set_obstacles(obstacles)
	for orch in session_orchestrators.values():
		if orch.has_method("set_obstacles"):
			orch.set_obstacles(obstacles)

func get_agent_count_for_session(session_id: String) -> int:
	if agents_by_session.has(session_id):
		return agents_by_session[session_id].size()
	return 0

func _find_available_desk() -> Desk:
	for desk in desks:
		if desk.is_available():
			return desk
	return null

func _configure_agent_positions(agent: Agent) -> void:
	agent.set_shredder_position(shredder_position)
	agent.set_water_cooler_position(water_cooler_position)
	agent.set_plant_position(plant_position)
	agent.set_filing_cabinet_position(filing_cabinet_position)

func _on_agent_completed(agent: Agent) -> void:
	completed_count += 1

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

	agent_completed.emit(agent)
	# Queue free after fade out
	agent.queue_free()
