extends FurnitureBase
class_name FurnitureFilingCabinet

## Office filing cabinet - agents deliver completed work here.
## Traits: delivery, social

func _init() -> void:
	furniture_type = "filing_cabinet"
	traits = ["delivery", "social"]
	capacity = 4
	delivery_sound = "filing"
	obstacle_size = Vector2(40, 80)

	# Interaction points (where agents stand)
	slots = [
		{"offset": Vector2(-50, 0), "occupied_by": ""},   # Left
		{"offset": Vector2(50, 0), "occupied_by": ""},    # Right
		{"offset": Vector2(0, 50), "occupied_by": ""},    # Front
		{"offset": Vector2(0, -40), "occupied_by": ""},   # Back
	]

func _ready() -> void:
	click_area = Rect2(-25, -30, 50, 70)
	super._ready()

func _build_visuals() -> void:
	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(44, 16)
	shadow.position = Vector2(-22, 30)
	shadow.color = OfficePalette.SHADOW
	add_child(shadow)

	# Cabinet front face (darker - what we see from front)
	var body_front = ColorRect.new()
	body_front.size = Vector2(40, 45)
	body_front.position = Vector2(-20, -15)
	body_front.color = OfficePalette.METAL_GRAY_DARK
	add_child(body_front)

	# Cabinet top surface (lighter - angled view shows top)
	var body_top = ColorRect.new()
	body_top.size = Vector2(40, 12)
	body_top.position = Vector2(-20, -27)
	body_top.color = OfficePalette.METAL_GRAY_LIGHT
	add_child(body_top)

	# Drawers (2 visible from this angle)
	for i in range(2):
		var drawer = ColorRect.new()
		drawer.size = Vector2(36, 18)
		drawer.position = Vector2(-18, -12 + i * 22)
		drawer.color = OfficePalette.METAL_GRAY
		add_child(drawer)

		# Drawer handle
		var handle = ColorRect.new()
		handle.size = Vector2(14, 3)
		handle.position = Vector2(-7, -6 + i * 22)
		handle.color = OfficePalette.METAL_HANDLE
		add_child(handle)
