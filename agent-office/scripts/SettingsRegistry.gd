extends Node

# Centralized settings registry for dynamic setting discovery and management.
# Components register their settings with metadata (type, range, description).
# MCP can dynamically discover and modify any setting.

signal setting_changed(category: String, key: String, value: Variant)

# Schema: category -> Array[Dictionary] (schema definitions)
var _schemas: Dictionary = {}
# Values: category -> key -> value
var _values: Dictionary = {}
# Persistence files: category -> file_path
var _files: Dictionary = {}
# Callbacks: category -> Callable (optional update callback)
var _callbacks: Dictionary = {}

# Schema field types
const TYPE_FLOAT = "float"
const TYPE_INT = "int"
const TYPE_BOOL = "bool"
const TYPE_STRING = "string"
const TYPE_ENUM = "enum"

func _ready() -> void:
	pass

# Register a settings category with schema and persistence file
func register_category(category: String, file_path: String, schema: Array, callback: Callable = Callable()) -> void:
	_schemas[category] = schema
	_files[category] = file_path
	_values[category] = {}
	if callback.is_valid():
		_callbacks[category] = callback

	# Initialize defaults from schema
	for field in schema:
		var key = str(field.get("key", ""))
		if key.is_empty():
			continue
		_values[category][key] = field.get("default")

	# Load persisted values (overwrite defaults)
	load_category(category)

# Get a single setting value
func get_setting(category: String, key: String) -> Variant:
	if not _values.has(category):
		push_warning("[SettingsRegistry] Unknown category: %s" % category)
		return null
	var cat_values = _values[category]
	if not cat_values.has(key):
		push_warning("[SettingsRegistry] Unknown key %s in category %s" % [key, category])
		return null
	return cat_values[key]

# Set a single setting value with validation
func set_setting(category: String, key: String, value: Variant) -> bool:
	if not _values.has(category):
		push_warning("[SettingsRegistry] Unknown category: %s" % category)
		return false

	# Find schema for this key
	var schema = _get_field_schema(category, key)
	if schema.is_empty():
		push_warning("[SettingsRegistry] Unknown key %s in category %s" % [key, category])
		return false

	# Validate and coerce value
	var validated = _validate_value(value, schema)
	if validated == null and value != null:
		push_warning("[SettingsRegistry] Invalid value for %s.%s: %s" % [category, key, str(value)])
		return false

	var old_value = _values[category].get(key)
	if old_value == validated:
		return true  # No change needed

	_values[category][key] = validated

	# Auto-save
	if not save_category(category):
		_values[category][key] = old_value
		return false

	# Emit change signal
	setting_changed.emit(category, key, validated)

	# Call category callback if registered
	if _callbacks.has(category) and _callbacks[category].is_valid():
		_callbacks[category].call(key, validated)

	return true

# Get all settings for a category
func get_category(category: String) -> Dictionary:
	if not _values.has(category):
		return {}
	return _values[category].duplicate()

# Get schema for a category
func get_schema(category: String) -> Array:
	if not _schemas.has(category):
		return []
	return _schemas[category].duplicate(true)

# List all registered categories
func list_categories() -> Array[String]:
	var cats: Array[String] = []
	for c in _schemas.keys():
		cats.append(str(c))
	return cats

# Get all schemas (for MCP list_settings)
func get_all_schemas() -> Dictionary:
	var result: Dictionary = {}
	for category in _schemas.keys():
		result[category] = {
			"schema": _schemas[category].duplicate(true),
			"values": _values[category].duplicate()
		}
	return result

# Save settings for a category to its persistence file
func save_category(category: String) -> bool:
	if not _files.has(category):
		return false
	var file_path = _files[category]
	if file_path.is_empty():
		return false

	# Multiple categories may intentionally share one persistence file. Preserve
	# unknown legacy keys, then overlay every registered category targeting it.
	var data: Dictionary = {}
	if FileAccess.file_exists(file_path):
		var existing = FileAccess.open(file_path, FileAccess.READ)
		if existing:
			var parsed = JSON.parse_string(existing.get_as_text())
			existing.close()
			if parsed is Dictionary:
				data = parsed
	for registered_category in _files.keys():
		if _files[registered_category] != file_path:
			continue
		data.erase(registered_category)
		for key in _values.get(registered_category, {}).keys():
			data[key] = _values[registered_category][key]
	# Remove the former shapes once their registered replacements are present.
	if _files.get("watchers", "") == file_path:
		data.erase("harnesses")
	if _files.get("mcp", "") == file_path:
		data.erase("mcp")
		data.erase("tcp")
	var temp_path = file_path + ".tmp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.flush()
		var write_error = file.get_error()
		file.close()
		if write_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			push_warning("[SettingsRegistry] Could not write %s: %s" % [file_path, error_string(write_error)])
			return false
		var rename_error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(temp_path),
			ProjectSettings.globalize_path(file_path)
		)
		if rename_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			push_warning("[SettingsRegistry] Could not replace %s: %s" % [file_path, error_string(rename_error)])
			return false
		return true
	else:
		push_warning("[SettingsRegistry] Could not write %s" % file_path)
		return false

# Load settings for a category from its persistence file
func load_category(category: String) -> void:
	if not _files.has(category):
		return
	var file_path = _files[category]
	if file_path.is_empty():
		return

	if not FileAccess.file_exists(file_path):
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return

	var data = json.get_data()
	if not data is Dictionary:
		return

	# Accept the former nested layouts during migration.
	var source: Dictionary = {}
	if data.get(category) is Dictionary:
		source.merge(data[category], true)
	elif category == "watchers" and data.get("harnesses") is Dictionary:
		for harness_name in data["harnesses"].keys():
			var harness = data["harnesses"][harness_name]
			if harness is Dictionary:
				source["%s_enabled" % harness_name] = harness.get("enabled", true)
				source["%s_path" % harness_name] = harness.get("path", "")
	# Canonical flat keys win over migrated values.
	for key in data.keys():
		source[key] = data[key]

	# Merge loaded values (validate each against schema)
	if not _values.has(category):
		_values[category] = {}

	for key in source.keys():
		var schema = _get_field_schema(category, str(key))
		if schema.is_empty():
			continue  # Skip unknown keys
		var validated = _validate_value(source[key], schema)
		if validated != null or source[key] == null:
			_values[category][str(key)] = validated

# Get field schema for a specific key
func _get_field_schema(category: String, key: String) -> Dictionary:
	if not _schemas.has(category):
		return {}
	for field in _schemas[category]:
		if field.get("key", "") == key:
			return field
	return {}

# Validate and coerce value based on schema
func _validate_value(value: Variant, schema: Dictionary) -> Variant:
	var field_type = str(schema.get("type", TYPE_STRING))

	match field_type:
		TYPE_FLOAT:
			var f = _to_float(value)
			if is_nan(f):
				return schema.get("default")
			var min_val = schema.get("min", -INF)
			var max_val = schema.get("max", INF)
			return clampf(f, float(min_val), float(max_val))

		TYPE_INT:
			var i = _to_int(value)
			if i == null:
				return schema.get("default")
			var min_val = schema.get("min", -2147483648)
			var max_val = schema.get("max", 2147483647)
			return clampi(i, int(min_val), int(max_val))

		TYPE_BOOL:
			return _to_bool(value)

		TYPE_STRING:
			return str(value) if value != null else ""

		TYPE_ENUM:
			var options = schema.get("options", [])
			var str_val = str(value)
			if str_val in options:
				return str_val
			# Return default if invalid option
			return schema.get("default", options[0] if not options.is_empty() else "")

	return value

func _to_float(value: Variant) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String:
		if value.is_valid_float():
			return float(value)
		if value.is_valid_int():
			return float(int(value))
	return NAN

func _to_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return int(value)
	return null

func _to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		var lower = value.to_lower()
		return lower == "true" or lower == "1" or lower == "yes"
	return false
