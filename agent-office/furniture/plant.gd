extends FurnitureBase
class_name FurniturePlant

## Office potted plant - agents socialize here.
## Traits: social

func _init() -> void:
	furniture_type = "plant"
	traits = ["social"]
	capacity = 4
	obstacle_size = Vector2(40, 50)

	# Interaction points (where agents stand)
	slots = [
		{"offset": Vector2(-40, 0), "occupied_by": ""},   # Left
		{"offset": Vector2(40, 0), "occupied_by": ""},    # Right
		{"offset": Vector2(0, 40), "occupied_by": ""},    # Front
		{"offset": Vector2(0, -35), "occupied_by": ""},   # Back
	]

func _ready() -> void:
	click_area = Rect2(-25, -25, 50, 60)
	super._ready()

func _build_visuals() -> void:
	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(36, 14)
	shadow.position = Vector2(-18, 28)
	shadow.color = OfficePalette.SHADOW
	add_child(shadow)

	# Pot front face (darker)
	var pot_front = ColorRect.new()
	pot_front.size = Vector2(32, 16)
	pot_front.position = Vector2(-16, 14)
	pot_front.color = OfficePalette.POT_TERRACOTTA_DARK
	add_child(pot_front)

	# Pot top rim (lighter, shows depth)
	var pot_rim = ColorRect.new()
	pot_rim.size = Vector2(34, 6)
	pot_rim.position = Vector2(-17, 8)
	pot_rim.color = OfficePalette.POT_RIM
	add_child(pot_rim)

	# Soil (visible from top)
	var soil = ColorRect.new()
	soil.size = Vector2(28, 10)
	soil.position = Vector2(-14, -2)
	soil.color = OfficePalette.SOIL_DARK
	add_child(soil)

	# Leaves spreading out from center (top-down view)
	var leaf1 = ColorRect.new()
	leaf1.size = Vector2(24, 10)
	leaf1.position = Vector2(-22, -12)
	leaf1.color = OfficePalette.LEAF_GREEN_DARK
	leaf1.rotation = -0.3
	add_child(leaf1)

	var leaf2 = ColorRect.new()
	leaf2.size = Vector2(26, 10)
	leaf2.position = Vector2(-8, -22)
	leaf2.color = OfficePalette.LEAF_GREEN_LIGHT
	leaf2.rotation = 0.2
	add_child(leaf2)

	var leaf3 = ColorRect.new()
	leaf3.size = Vector2(22, 10)
	leaf3.position = Vector2(4, -8)
	leaf3.color = OfficePalette.LEAF_GREEN
	leaf3.rotation = 0.6
	add_child(leaf3)

	var leaf4 = ColorRect.new()
	leaf4.size = Vector2(20, 8)
	leaf4.position = Vector2(-4, -16)
	leaf4.color = OfficePalette.LEAF_GREEN_LIGHT
	leaf4.rotation = -0.5
	add_child(leaf4)
