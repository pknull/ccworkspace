extends FurnitureBase
class_name FurnitureWaterCooler

## Office water cooler - agents socialize here.
## Traits: social

func _init() -> void:
	furniture_type = "water_cooler"
	traits = ["social"]
	capacity = 4
	obstacle_size = Vector2(40, 60)

	# Interaction points (where agents stand)
	slots = [
		{"offset": Vector2(-40, 0), "occupied_by": ""},   # Left
		{"offset": Vector2(40, 0), "occupied_by": ""},    # Right
		{"offset": Vector2(0, 50), "occupied_by": ""},    # Front
		{"offset": Vector2(0, -40), "occupied_by": ""},   # Back
	]

func _ready() -> void:
	click_area = Rect2(-20, -30, 40, 70)
	super._ready()

func _build_visuals() -> void:
	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(32, 12)
	shadow.position = Vector2(-16, 32)
	shadow.color = OfficePalette.SHADOW
	add_child(shadow)

	# Base (top-down view - see the top surface)
	var base_front = ColorRect.new()
	base_front.size = Vector2(28, 12)
	base_front.position = Vector2(-14, 24)
	base_front.color = OfficePalette.COOLER_BASE_DARK
	add_child(base_front)

	var base_top = ColorRect.new()
	base_top.size = Vector2(28, 8)
	base_top.position = Vector2(-14, 16)
	base_top.color = OfficePalette.COOLER_BASE
	add_child(base_top)

	# Body (main unit - show top and front)
	var body_front = ColorRect.new()
	body_front.size = Vector2(24, 20)
	body_front.position = Vector2(-12, -4)
	body_front.color = OfficePalette.COOLER_BODY_FRONT
	add_child(body_front)

	var body_top = ColorRect.new()
	body_top.size = Vector2(24, 8)
	body_top.position = Vector2(-12, -12)
	body_top.color = OfficePalette.COOLER_BODY_TOP
	add_child(body_top)

	# Water bottle (top-down - see circular top)
	var bottle_body = ColorRect.new()
	bottle_body.size = Vector2(18, 18)
	bottle_body.position = Vector2(-9, -30)
	bottle_body.color = OfficePalette.COOLER_BOTTLE
	add_child(bottle_body)

	var bottle_top = ColorRect.new()
	bottle_top.size = Vector2(14, 6)
	bottle_top.position = Vector2(-7, -34)
	bottle_top.color = OfficePalette.COOLER_BOTTLE_TOP
	add_child(bottle_top)

	# Tap (small detail on front)
	var tap = ColorRect.new()
	tap.size = Vector2(6, 4)
	tap.position = Vector2(-3, 4)
	tap.color = OfficePalette.COOLER_TAP
	add_child(tap)
