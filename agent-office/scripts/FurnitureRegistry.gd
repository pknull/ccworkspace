extends RefCounted
class_name FurnitureRegistry

## Registry of available furniture types for spawning.
## Supports both script-based (desk, terminal) and JSON-driven furniture.

const DEFINITIONS_DIR := "res://furniture/definitions"

# Dictionary of type name -> script path (for script-based types)
var _types: Dictionary = {}

# Dictionary of type name -> parsed JSON data (for JSON-driven types)
var _json_data: Dictionary = {}

# Dictionary of type name -> metadata {display_name, category, shelf_preview}
var _metadata: Dictionary = {}

# Reference to navigation grid for obstacle setup
var navigation_grid: NavigationGrid = null

func _init() -> void:
	_register_default_types()
	_scan_json_definitions()

func _register_default_types() -> void:
	# Script-based types (complex behavior that can't be expressed in JSON)
	register("desk", "res://furniture/desk.gd")
	register("terminal_furniture", "res://furniture/terminal_furniture.gd")

func _scan_json_definitions() -> void:
	# Load all JSON definitions from the definitions directory
	var defs := FurnitureJsonLoader.scan_directory(DEFINITIONS_DIR)
	for data in defs:
		var type_name: String = data.get("type", "")
		if type_name.is_empty():
			continue

		_json_data[type_name] = data
		_metadata[type_name] = {
			"display_name": data.get("display_name", type_name),
			"category": data.get("category", ""),
			"shelf_preview": data.get("shelf_preview", {}),
		}

		# JSON-only types are NOT added to _types (they spawn via create_furniture)
		# Script-based types may have sibling .json for metadata only
		if not _types.has(type_name):
			_types[type_name] = "json"  # Sentinel value indicating JSON-driven

	# Load metadata-only JSON for script-based types
	_load_script_metadata("res://furniture/desk.json", "desk")
	_load_script_metadata("res://furniture/terminal_furniture.json", "terminal_furniture")

func _load_script_metadata(path: String, type_name: String) -> void:
	var data := FurnitureJsonLoader.load_definition(path)
	if data.is_empty():
		return
	_metadata[type_name] = {
		"display_name": data.get("display_name", type_name),
		"category": data.get("category", ""),
		"shelf_preview": data.get("shelf_preview", {}),
	}

# --- Registration ---

func register(type_name: String, script_path: String) -> void:
	_types[type_name] = script_path

func register_script(type_name: String, script: GDScript) -> void:
	_types[type_name] = script

func unregister(type_name: String) -> void:
	_types.erase(type_name)
	_json_data.erase(type_name)
	_metadata.erase(type_name)

func is_registered(type_name: String) -> bool:
	return type_name in _types

# --- Queries ---

func get_available_types() -> Array[String]:
	var result: Array[String] = []
	for key in _types.keys():
		result.append(key)
	return result

func get_type_count() -> int:
	return _types.size()

func get_display_name(type_name: String) -> String:
	if _metadata.has(type_name):
		return _metadata[type_name].get("display_name", type_name)
	return type_name

func get_category(type_name: String) -> String:
	if _metadata.has(type_name):
		return _metadata[type_name].get("category", "")
	return ""

func get_shelf_preview(type_name: String) -> Dictionary:
	if _metadata.has(type_name):
		return _metadata[type_name].get("shelf_preview", {})
	return {}

func get_types_by_category(cat: String) -> Array[String]:
	var result: Array[String] = []
	for type_name in _types.keys():
		if get_category(type_name) == cat:
			result.append(type_name)
	return result

func get_all_categories() -> Array[String]:
	## Returns ordered list of unique categories.
	var seen: Dictionary = {}
	var result: Array[String] = []
	# Ordered: workstations, terminals, tables, dropoff, social, pets
	var order := ["workstations", "terminals", "tables", "dropoff", "social", "pets"]
	for cat in order:
		for type_name in _types.keys():
			if get_category(type_name) == cat and not seen.has(cat):
				seen[cat] = true
				result.append(cat)
	# Any categories not in the predefined order
	for type_name in _types.keys():
		var cat := get_category(type_name)
		if not cat.is_empty() and not seen.has(cat):
			seen[cat] = true
			result.append(cat)
	return result

func get_category_display_name(cat: String) -> String:
	match cat:
		"workstations": return "Workstations"
		"terminals": return "Terminals"
		"tables": return "Tables"
		"dropoff": return "Drop-off"
		"social": return "Social"
		"pets": return "Pets"
		_: return cat.capitalize()

# --- Spawning ---

func spawn(type_name: String, pos: Vector2) -> FurnitureBase:
	if not is_registered(type_name):
		push_warning("FurnitureRegistry: Unknown type '%s'" % type_name)
		return null

	var entry = _types[type_name]

	# JSON-driven type
	if entry is String and entry == "json":
		if not _json_data.has(type_name):
			push_error("FurnitureRegistry: No JSON data for '%s'" % type_name)
			return null
		var furniture := FurnitureJsonLoader.create_furniture(_json_data[type_name])
		furniture.furniture_id = FurnitureBase.generate_id(type_name)
		furniture.position = pos
		furniture.navigation_grid = navigation_grid
		if furniture.item_name.is_empty():
			furniture.item_name = furniture.furniture_id
		return furniture

	# Script-based type
	var script: GDScript
	if entry is String:
		script = load(entry) as GDScript
		if not script:
			push_error("FurnitureRegistry: Failed to load script '%s'" % entry)
			return null
	elif entry is GDScript:
		script = entry
	else:
		push_error("FurnitureRegistry: Invalid type registration for '%s'" % type_name)
		return null

	var furniture: FurnitureBase = script.new()
	if not furniture:
		push_error("FurnitureRegistry: Failed to instantiate '%s'" % type_name)
		return null

	furniture.furniture_type = type_name
	furniture.furniture_id = FurnitureBase.generate_id(type_name)
	furniture.position = pos
	furniture.navigation_grid = navigation_grid

	# Merge metadata from JSON if available
	if _metadata.has(type_name):
		var meta = _metadata[type_name]
		if furniture.display_name.is_empty():
			furniture.display_name = meta.get("display_name", "")
		if furniture.category.is_empty():
			furniture.category = meta.get("category", "")

	if furniture.item_name.is_empty():
		furniture.item_name = furniture.furniture_id

	return furniture

func spawn_with_id(type_name: String, pos: Vector2, id: String) -> FurnitureBase:
	var furniture := spawn(type_name, pos)
	if furniture:
		furniture.furniture_id = id
		furniture.item_name = id
	return furniture

# --- Persistence helpers ---

func get_type_info(type_name: String) -> Dictionary:
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
