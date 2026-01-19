extends RefCounted
class_name AgentSocial

# Social spot selection and cooldown management for agents

const SOCIAL_SPOT_COOLDOWN: float = 30.0

var social_spot_cooldowns: Dictionary = {}

func _init(_agent_ref: Node2D) -> void:
	pass

func update_cooldowns(delta: float) -> void:
	if social_spot_cooldowns.is_empty():
		return
	var to_clear: Array[String] = []
	for key in social_spot_cooldowns.keys():
		var remaining = float(social_spot_cooldowns[key]) - delta
		if remaining <= 0.0:
			to_clear.append(key)
		else:
			social_spot_cooldowns[key] = remaining
	for key in to_clear:
		social_spot_cooldowns.erase(key)

func mark_cooldown(option: Dictionary) -> void:
	var key = option.get("cooldown_key", "")
	if key.is_empty():
		return
	social_spot_cooldowns[key] = SOCIAL_SPOT_COOLDOWN

func choose_social_spot(options: Array) -> Dictionary:
	var available: Array = []
	for option in options:
		if option.get("type", "") == "exit":
			available.append(option)
			continue
		var key = option.get("cooldown_key", "")
		if key.is_empty() or not social_spot_cooldowns.has(key):
			available.append(option)

	if available.is_empty():
		available = options

	var total_weight = 0.0
	for option in available:
		total_weight += float(option.get("weight", 1.0))

	var roll = randf() * total_weight
	for option in available:
		roll -= float(option.get("weight", 1.0))
		if roll <= 0.0:
			return option

	return available[available.size() - 1]

func is_tracked_furniture(furniture_name: String) -> bool:
	return furniture_name in ["water_cooler", "plant", "filing_cabinet", "shredder", "taskboard"]
