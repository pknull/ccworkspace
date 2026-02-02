extends RefCounted
class_name FurnitureRegistry

## Registry of available furniture types for spawning.
## Maintains catalog of furniture scripts and handles instantiation.

# Dictionary of type name -> script path
var _types: Dictionary = {}

# Reference to navigation grid for obstacle setup
var navigation_grid: NavigationGrid = null

func _init() -> void:
	_register_default_types()

func _register_default_types() -> void:
	# Register built-in furniture types
	register("desk", "res://furniture/desk.gd")
	register("terminal_furniture", "res://furniture/terminal_furniture.gd")
	register("shredder", "res://furniture/shredder.gd")
	register("filing_cabinet", "res://furniture/filing_cabinet.gd")
	register("water_cooler", "res://furniture/water_cooler.gd")
	register("plant", "res://furniture/plant.gd")
	register("cat_bed", "res://furniture/cat_bed.gd")
	register("taskboard", "res://furniture/taskboard.gd")
	register("meeting_table", "res://furniture/meeting_table.gd")

# --- Registration ---

func register(type_name: String, script_path: String) -> void:
	## Register a furniture type by script path
	_types[type_name] = script_path

func register_script(type_name: String, script: GDScript) -> void:
	## Register a furniture type by script reference
	_types[type_name] = script

func unregister(type_name: String) -> void:
	## Remove a furniture type from registry
	_types.erase(type_name)

func is_registered(type_name: String) -> bool:
	return type_name in _types

# --- Queries ---

func get_available_types() -> Array[String]:
	## Returns list of all registered furniture type names
	var result: Array[String] = []
	for key in _types.keys():
		result.append(key)
	return result

func get_type_count() -> int:
	return _types.size()

# --- Spawning ---

func spawn(type_name: String, pos: Vector2) -> FurnitureBase:
	## Create a new furniture instance of the given type at position.
	## Returns null if type not registered or spawn fails.
	if not is_registered(type_name):
		push_warning("FurnitureRegistry: Unknown type '%s'" % type_name)
		return null

	var script_or_path = _types[type_name]
	var script: GDScript

	if script_or_path is String:
		script = load(script_or_path) as GDScript
		if not script:
			push_error("FurnitureRegistry: Failed to load script '%s'" % script_or_path)
			return null
	elif script_or_path is GDScript:
		script = script_or_path
	else:
		push_error("FurnitureRegistry: Invalid type registration for '%s'" % type_name)
		return null

	var furniture: FurnitureBase = script.new()
	if not furniture:
		push_error("FurnitureRegistry: Failed to instantiate '%s'" % type_name)
		return null

	# Set up furniture
	furniture.furniture_type = type_name
	furniture.furniture_id = FurnitureBase.generate_id(type_name)
	furniture.position = pos
	furniture.navigation_grid = navigation_grid

	# item_name for DraggableItem compatibility
	if furniture.item_name.is_empty():
		furniture.item_name = furniture.furniture_id

	return furniture

func spawn_with_id(type_name: String, pos: Vector2, id: String) -> FurnitureBase:
	## Create furniture with a specific ID (for loading saved layouts)
	var furniture := spawn(type_name, pos)
	if furniture:
		furniture.furniture_id = id
		furniture.item_name = id
	return furniture

# --- Persistence helpers ---

func get_type_info(type_name: String) -> Dictionary:
	## Get metadata about a furniture type (for UI display)
	## Spawns a temporary instance to read properties
	if not is_registered(type_name):
		return {}

	var temp := spawn(type_name, Vector2.ZERO)
	if not temp:
		return {}

	var info := {
		"type": type_name,
		"traits": temp.traits.duplicate(),
		"capacity": temp.capacity,
	}

	temp.free()
	return info
