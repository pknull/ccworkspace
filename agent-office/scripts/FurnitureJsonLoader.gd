class_name FurnitureJsonLoader

## Static utility for loading furniture definitions from JSON files.
## Handles parsing, color resolution, visual construction, and directory scanning.

const REQUIRED_FIELDS: Array[String] = ["type", "display_name", "category", "traits"]

# --- Loading ---

static func load_definition(path: String) -> Dictionary:
	## Parse and validate a JSON furniture definition file.
	## Returns empty dictionary on failure.
	if not FileAccess.file_exists(path):
		push_warning("FurnitureJsonLoader: File not found: %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("FurnitureJsonLoader: Cannot open: %s" % path)
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("FurnitureJsonLoader: Parse error in %s: %s" % [path, json.get_error_message()])
		return {}

	var data: Dictionary = json.data
	if not _validate(data, path):
		return {}

	return data

static func _validate(data: Dictionary, path: String) -> bool:
	for field in REQUIRED_FIELDS:
		if not data.has(field):
			push_warning("FurnitureJsonLoader: Missing '%s' in %s" % [field, path])
			return false
	return true

# --- Color Resolution ---

static func resolve_color(color_ref) -> Color:
	## Resolve a color reference to a Color value.
	## Accepts: String name, Array [r,g,b] or [r,g,b,a], null (returns transparent).
	if color_ref == null:
		return Color.TRANSPARENT

	if color_ref is String:
		return OfficePalette.get_color(color_ref)

	if color_ref is Array:
		match color_ref.size():
			3:
				return Color(color_ref[0], color_ref[1], color_ref[2])
			4:
				return Color(color_ref[0], color_ref[1], color_ref[2], color_ref[3])

	push_warning("FurnitureJsonLoader: Invalid color reference: %s" % str(color_ref))
	return Color.MAGENTA

# --- Visual Construction ---

static func build_visuals(parent: Node2D, visuals_array: Array) -> void:
	## Create visual child nodes from a JSON visuals array.
	for entry in visuals_array:
		var vtype: String = entry.get("type", "color_rect")
		match vtype:
			"color_rect":
				_build_color_rect(parent, entry)
			"label":
				_build_label(parent, entry)
			_:
				push_warning("FurnitureJsonLoader: Unknown visual type '%s'" % vtype)

static func _build_color_rect(parent: Node2D, entry: Dictionary) -> void:
	var rect := ColorRect.new()
	rect.name = entry.get("name", "rect")

	var size = entry.get("size", [10, 10])
	if not (size is Array and size.size() >= 2):
		push_warning("FurnitureJsonLoader: Invalid size in visual '%s'" % entry.get("name", "?"))
		return
	rect.size = Vector2(size[0], size[1])

	var pos = entry.get("position", [0, 0])
	if not (pos is Array and pos.size() >= 2):
		push_warning("FurnitureJsonLoader: Invalid position in visual '%s'" % entry.get("name", "?"))
		return
	rect.position = Vector2(pos[0], pos[1])

	rect.color = resolve_color(entry.get("color", "SHADOW"))

	var rotation_val = entry.get("rotation", 0)
	if rotation_val != 0:
		rect.rotation = rotation_val

	# Per-element z_index override (for taskboard legs etc.)
	var z_val = entry.get("z_index", null)
	if z_val != null:
		rect.z_as_relative = false
		if z_val is String:
			# Constant name reference
			rect.z_index = _resolve_z_constant(z_val)
		else:
			rect.z_index = int(z_val)

	parent.add_child(rect)

static func _build_label(parent: Node2D, entry: Dictionary) -> void:
	var label := Label.new()
	label.name = entry.get("name", "label")
	label.text = entry.get("text", "")

	var pos = entry.get("position", [0, 0])
	if not (pos is Array and pos.size() >= 2):
		push_warning("FurnitureJsonLoader: Invalid position in label '%s'" % entry.get("name", "?"))
		return
	label.position = Vector2(pos[0], pos[1])

	var size = entry.get("size", null)
	if size != null and size is Array and size.size() >= 2:
		label.size = Vector2(size[0], size[1])

	var font_size = entry.get("font_size", 11)
	label.add_theme_font_size_override("font_size", font_size)

	var color = entry.get("color", null)
	if color != null:
		label.add_theme_color_override("font_color", resolve_color(color))

	var align = entry.get("horizontal_alignment", "")
	if align == "center":
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	parent.add_child(label)

static func _resolve_z_constant(name: String) -> int:
	match name:
		"Z_TASKBOARD_LEGS":
			return OfficeConstants.Z_TASKBOARD_LEGS
		"Z_TASKBOARD":
			return OfficeConstants.Z_TASKBOARD
		"Z_WALL_DECORATION":
			return OfficeConstants.Z_WALL_DECORATION
		"Z_CAT":
			return OfficeConstants.Z_CAT
		_:
			push_warning("FurnitureJsonLoader: Unknown z constant '%s'" % name)
			return 0

# --- Furniture Creation ---

static func create_furniture(data: Dictionary) -> FurnitureBase:
	## Create a fully configured FurnitureBase instance from parsed JSON data.
	var furniture := FurnitureBase.new()
	furniture._json_data = data
	furniture.furniture_type = data.get("type", "")
	furniture.display_name = data.get("display_name", "")
	furniture.category = data.get("category", "")

	# Traits
	var trait_array: Array[String] = []
	for t in data.get("traits", []):
		trait_array.append(str(t))
	furniture.traits = trait_array

	furniture.capacity = int(data.get("capacity", 1))
	furniture.delivery_sound = data.get("delivery_sound", "")

	# Obstacle size
	var obs = data.get("obstacle_size", null)
	if obs != null and obs is Array and obs.size() == 2:
		furniture.obstacle_size = Vector2(obs[0], obs[1])

	# Click area
	var ca = data.get("click_area", null)
	if ca != null and ca is Array and ca.size() == 4:
		furniture.click_area = Rect2(ca[0], ca[1], ca[2], ca[3])

	# Wall mounted
	furniture.wall_mounted = data.get("wall_mounted", false)

	# Visual center offset
	var vco = data.get("visual_center_offset", null)
	if vco != null and vco is Array and vco.size() == 2:
		furniture.visual_center_offset = Vector2(vco[0], vco[1])

	# Drag bounds
	var db = data.get("drag_bounds", null)
	if db != null and db is Dictionary:
		var db_min = db.get("min", null)
		var db_max = db.get("max", null)
		if db_min != null and db_min is Array and db_min.size() == 2:
			furniture.drag_bounds_min = Vector2(db_min[0], db_min[1])
		if db_max != null and db_max is Array and db_max.size() == 2:
			furniture.drag_bounds_max = Vector2(db_max[0], db_max[1])

	# Z-index configuration
	var z_cfg = data.get("z_index", null)
	if z_cfg != null and z_cfg is Dictionary:
		var mode = z_cfg.get("mode", "dynamic")
		if mode == "fixed":
			furniture.use_dynamic_z_index = false
			var val = z_cfg.get("value", 0)
			if val is String:
				furniture._fixed_z_value = _resolve_z_constant(val)
			else:
				furniture._fixed_z_value = int(val)

	# Slots
	var slot_defs = data.get("slots", [])
	if not slot_defs.is_empty():
		var slots: Array = []
		for s in slot_defs:
			var offset = s.get("offset", [0, 40])
			slots.append({
				"offset": Vector2(offset[0], offset[1]),
				"occupied_by": ""
			})
		furniture.slots = slots

	return furniture

# --- Directory Scanning ---

static func scan_directory(dir_path: String) -> Array[Dictionary]:
	## Load all .json files from a directory. Returns array of parsed definitions.
	var results: Array[Dictionary] = []

	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("FurnitureJsonLoader: Cannot open directory: %s" % dir_path)
		return results

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := dir_path.path_join(file_name)
			var data := load_definition(full_path)
			if not data.is_empty():
				results.append(data)
		file_name = dir.get_next()
	dir.list_dir_end()

	return results
