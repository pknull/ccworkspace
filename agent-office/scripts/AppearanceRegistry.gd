extends RefCounted
class_name AppearanceRegistry

## Registry for JSON-driven agent appearance items.
## Scans directories for tops, bottoms, hair colors, and hair styles.

const TOPS_DIR := "res://appearance/tops"
const BOTTOMS_DIR := "res://appearance/bottoms"
const HAIR_COLORS_DIR := "res://appearance/hair_colors"
const HAIR_STYLES_DIR := "res://appearance/hair_styles"

var _tops: Dictionary = {}           # id -> Dictionary
var _bottoms: Dictionary = {}        # id -> Dictionary
var _hair_colors: Dictionary = {}    # id -> Dictionary
var _hair_styles: Dictionary = {}    # id -> Dictionary

# Ordered arrays preserve directory scan order for UI display
var _top_ids: Array[String] = []
var _bottom_ids: Array[String] = []
var _hair_color_ids: Array[String] = []
var _hair_style_ids: Array[String] = []

func _init() -> void:
	_scan_all()

func _scan_all() -> void:
	_scan_category(TOPS_DIR, _tops, _top_ids)
	_scan_category(BOTTOMS_DIR, _bottoms, _bottom_ids)
	_scan_category(HAIR_COLORS_DIR, _hair_colors, _hair_color_ids)
	_scan_category(HAIR_STYLES_DIR, _hair_styles, _hair_style_ids)

func _scan_category(dir_path: String, target: Dictionary, id_list: Array[String]) -> void:
	var defs := FurnitureJsonLoader.scan_directory(dir_path)
	for data in defs:
		var item_id: String = data.get("id", "")
		if item_id.is_empty():
			push_warning("AppearanceRegistry: Item missing 'id' in %s" % dir_path)
			continue
		target[item_id] = data
		id_list.append(item_id)

# --- Tops ---

func get_top(id: String) -> Dictionary:
	return _tops.get(id, {})

func get_all_tops() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in _top_ids:
		result.append(_tops[item_id])
	return result

func get_all_top_ids() -> Array[String]:
	return _top_ids

func get_top_color(id: String) -> Color:
	var item := get_top(id)
	if item.is_empty():
		return Color.MAGENTA
	return FurnitureJsonLoader.resolve_color(item.get("color", null))

func has_top(id: String) -> bool:
	return _tops.has(id)

# --- Bottoms ---

func get_bottom(id: String) -> Dictionary:
	return _bottoms.get(id, {})

func get_all_bottoms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in _bottom_ids:
		result.append(_bottoms[item_id])
	return result

func get_all_bottom_ids() -> Array[String]:
	return _bottom_ids

func get_bottom_color(id: String) -> Color:
	var item := get_bottom(id)
	if item.is_empty():
		return Color.MAGENTA
	return FurnitureJsonLoader.resolve_color(item.get("color", null))

func has_bottom(id: String) -> bool:
	return _bottoms.has(id)

# --- Hair Colors ---

func get_hair_color(id: String) -> Dictionary:
	return _hair_colors.get(id, {})

func get_all_hair_colors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in _hair_color_ids:
		result.append(_hair_colors[item_id])
	return result

func get_all_hair_color_ids() -> Array[String]:
	return _hair_color_ids

func get_hair_color_value(id: String) -> Color:
	var item := get_hair_color(id)
	if item.is_empty():
		return Color.MAGENTA
	return FurnitureJsonLoader.resolve_color(item.get("color", null))

func has_hair_color(id: String) -> bool:
	return _hair_colors.has(id)

# --- Hair Styles ---

func get_hair_style(id: String) -> Dictionary:
	return _hair_styles.get(id, {})

func get_all_hair_styles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in _hair_style_ids:
		result.append(_hair_styles[item_id])
	return result

func get_all_hair_style_ids() -> Array[String]:
	return _hair_style_ids

func has_hair_style(id: String) -> bool:
	return _hair_styles.has(id)

# --- Migration Helpers ---

## Map old index-based values to default item IDs for profile migration.

const TOP_INDEX_MAP: Array[String] = ["white_shirt", "pink_blouse", "blue_blouse", "lavender_blouse"]
const BOTTOM_INDEX_MAP: Array[String] = ["dark_pants", "dark_skirt", "charcoal_pants", "charcoal_skirt", "navy_pants", "navy_skirt", "burgundy_skirt"]
const HAIR_COLOR_INDEX_MAP: Array[String] = ["brown", "black", "auburn", "blonde", "dark_brown", "very_dark"]
const HAIR_STYLE_INDEX_MAP: Array[String] = ["short", "long", "bob", "updo"]

static func top_id_from_index(index: int, is_female: bool) -> String:
	## Convert old blouse_color_index + is_female to a top ID.
	if is_female:
		# Female tops: 0=pink_blouse, 1=blue_blouse, 2=lavender_blouse, 3=pink_blouse(wrap)
		var female_tops: Array[String] = ["pink_blouse", "blue_blouse", "lavender_blouse"]
		return female_tops[index % female_tops.size()]
	else:
		return "white_shirt"

static func bottom_id_from_index(bottom_type: int, bottom_color: int) -> String:
	## Convert old bottom_type + bottom_color_index to a bottom ID.
	if bottom_type == 1:
		# Skirts: dark_skirt, charcoal_skirt, navy_skirt, burgundy_skirt
		var skirts: Array[String] = ["dark_skirt", "charcoal_skirt", "navy_skirt", "burgundy_skirt"]
		return skirts[bottom_color % skirts.size()]
	else:
		# Pants: dark_pants, charcoal_pants, navy_pants
		var pants: Array[String] = ["dark_pants", "charcoal_pants", "navy_pants"]
		return pants[bottom_color % pants.size()]

static func hair_color_id_from_index(index: int) -> String:
	if index >= 0 and index < HAIR_COLOR_INDEX_MAP.size():
		return HAIR_COLOR_INDEX_MAP[index]
	return HAIR_COLOR_INDEX_MAP[0]

static func hair_style_id_from_index(index: int) -> String:
	if index >= 0 and index < HAIR_STYLE_INDEX_MAP.size():
		return HAIR_STYLE_INDEX_MAP[index]
	return HAIR_STYLE_INDEX_MAP[0]

# --- Reverse Lookups (for legacy MCP compat) ---

func top_index_from_id(id: String) -> int:
	var idx := TOP_INDEX_MAP.find(id)
	return idx if idx >= 0 else 0

func hair_color_index_from_id(id: String) -> int:
	var idx := HAIR_COLOR_INDEX_MAP.find(id)
	return idx if idx >= 0 else 0

func hair_style_index_from_id(id: String) -> int:
	var idx := HAIR_STYLE_INDEX_MAP.find(id)
	return idx if idx >= 0 else 0
