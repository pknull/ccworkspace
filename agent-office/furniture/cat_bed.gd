extends FurnitureBase
class_name FurnitureCatBed

## Cat bed - where the office cat rests.
## Traits: cat_rest

func _init() -> void:
	furniture_type = "cat_bed"
	traits = ["cat_rest"]
	capacity = 1
	obstacle_size = Vector2(60, 36)

	# Single slot for the cat
	slots = [
		{"offset": Vector2(0, 0), "occupied_by": ""},
	]

func _ready() -> void:
	click_area = Rect2(-30, -18, 60, 36)
	# Cat bed renders below the cat
	use_dynamic_z_index = false
	z_index = OfficeConstants.Z_CAT - 5
	super._ready()

func _build_visuals() -> void:
	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(46, 10)
	shadow.position = Vector2(-23, 10)
	shadow.color = OfficePalette.SHADOW
	add_child(shadow)

	# Bed base
	var base = ColorRect.new()
	base.size = Vector2(60, 28)
	base.position = Vector2(-30, -14)
	base.color = OfficePalette.WOOD_DOOR
	add_child(base)

	# Inner rim
	var rim = ColorRect.new()
	rim.size = Vector2(56, 24)
	rim.position = Vector2(-28, -12)
	rim.color = OfficePalette.WOOD_DOOR_LIGHT
	add_child(rim)

	# Cushion
	var cushion = ColorRect.new()
	cushion.size = Vector2(50, 18)
	cushion.position = Vector2(-25, -9)
	cushion.color = OfficePalette.GRUVBOX_RED_FADED
	add_child(cushion)

	# Pillow
	var pillow = ColorRect.new()
	pillow.size = Vector2(16, 10)
	pillow.position = Vector2(-8, -7)
	pillow.color = OfficePalette.GRUVBOX_LIGHT2
	add_child(pillow)
