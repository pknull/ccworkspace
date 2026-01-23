extends FurnitureBase
class_name FurnitureShredder

## Office paper shredder - agents deliver completed work here.
## Traits: delivery, social

func _init() -> void:
	furniture_type = "shredder"
	traits = ["delivery", "social"]
	capacity = 4
	delivery_sound = "shredder"
	obstacle_size = Vector2(30, 40)

	# Interaction points (where agents stand)
	slots = [
		{"offset": Vector2(-50, 0), "occupied_by": ""},   # Left
		{"offset": Vector2(50, 0), "occupied_by": ""},    # Right
		{"offset": Vector2(0, 45), "occupied_by": ""},    # Front
		{"offset": Vector2(0, -35), "occupied_by": ""},   # Back
	]

func _ready() -> void:
	# Set click area before parent _ready
	click_area = Rect2(-30, -25, 60, 60)
	super._ready()

func _build_visuals() -> void:
	# Shadow
	var shadow = ColorRect.new()
	shadow.size = Vector2(52, 16)
	shadow.position = Vector2(-26, 28)
	shadow.color = OfficePalette.SHADOW
	add_child(shadow)

	# Shredder bin front (darker)
	var bin_front = ColorRect.new()
	bin_front.size = Vector2(48, 24)
	bin_front.position = Vector2(-24, 4)
	bin_front.color = OfficePalette.SHREDDER_BIN
	add_child(bin_front)

	# Shredder main body front
	var body_front = ColorRect.new()
	body_front.size = Vector2(48, 20)
	body_front.position = Vector2(-24, -16)
	body_front.color = OfficePalette.SHREDDER_BODY
	add_child(body_front)

	# Shredder top surface (lighter - shows the paper slot)
	var body_top = ColorRect.new()
	body_top.size = Vector2(48, 12)
	body_top.position = Vector2(-24, -28)
	body_top.color = OfficePalette.SHREDDER_TOP
	add_child(body_top)

	# Paper slot on top (dark opening)
	var slot_visual = ColorRect.new()
	slot_visual.size = Vector2(36, 6)
	slot_visual.position = Vector2(-18, -26)
	slot_visual.color = OfficePalette.SHREDDER_SLOT
	add_child(slot_visual)

	# Shredded paper visible in bin (from angled view)
	var shreds1 = ColorRect.new()
	shreds1.size = Vector2(40, 4)
	shreds1.position = Vector2(-20, 18)
	shreds1.color = OfficePalette.SHREDDED_PAPER
	add_child(shreds1)

	var shreds2 = ColorRect.new()
	shreds2.size = Vector2(36, 3)
	shreds2.position = Vector2(-18, 14)
	shreds2.color = OfficePalette.SHREDDED_PAPER_DARK
	add_child(shreds2)

	# Power light (green LED on top)
	var led = ColorRect.new()
	led.size = Vector2(5, 5)
	led.position = Vector2(16, -24)
	led.color = OfficePalette.STATUS_LED_GREEN_BRIGHT
	add_child(led)
