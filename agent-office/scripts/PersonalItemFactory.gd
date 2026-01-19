extends RefCounted
class_name PersonalItemFactory

# =============================================================================
# PERSONAL ITEM FACTORY
# =============================================================================
# Static utility class for creating personal desk items.
# Extracted from Agent.gd for better maintainability.

const ITEM_TYPES: Array[String] = [
	"coffee_mug", "photo_frame", "plant", "pencil_cup",
	"stress_ball", "snack", "water_bottle", "figurine"
]

static func get_random_item_type() -> String:
	return ITEM_TYPES[randi() % ITEM_TYPES.size()]

static func create_item(item_type: String) -> Node2D:
	var item = Node2D.new()

	match item_type:
		"coffee_mug":
			_create_coffee_mug(item)
		"photo_frame":
			_create_photo_frame(item)
		"plant":
			_create_plant(item)
		"pencil_cup":
			_create_pencil_cup(item)
		"stress_ball":
			_create_stress_ball(item)
		"snack":
			_create_snack(item)
		"water_bottle":
			_create_water_bottle(item)
		"figurine":
			_create_figurine(item)
		_:
			item.queue_free()
			return null

	return item

static func _create_coffee_mug(item: Node2D) -> void:
	# Mug body
	var mug = ColorRect.new()
	mug.size = Vector2(10, 14)
	mug.position = Vector2(0, 0)
	# Random mug color (using palette)
	var mug_colors = [OfficePalette.MUG_WHITE, OfficePalette.MUG_RED, OfficePalette.MUG_BLUE, OfficePalette.MUG_GREEN, OfficePalette.MUG_YELLOW]
	mug.color = mug_colors[randi() % mug_colors.size()]
	item.add_child(mug)
	# Handle
	var handle = ColorRect.new()
	handle.size = Vector2(4, 8)
	handle.position = Vector2(10, 3)
	handle.color = mug.color
	item.add_child(handle)

static func _create_photo_frame(item: Node2D) -> void:
	# Frame
	var frame = ColorRect.new()
	frame.size = Vector2(14, 16)
	frame.position = Vector2(0, -4)
	frame.color = OfficePalette.PHOTO_FRAME_WOOD
	item.add_child(frame)
	# Photo inside
	var photo = ColorRect.new()
	photo.size = Vector2(10, 10)
	photo.position = Vector2(2, 2)
	photo.color = OfficePalette.PHOTO_SKY
	item.add_child(photo)

static func _create_plant(item: Node2D) -> void:
	# Small terracotta pot
	var pot = ColorRect.new()
	pot.size = Vector2(14, 10)
	pot.position = Vector2(0, 4)
	pot.color = OfficePalette.POT_TERRACOTTA
	item.add_child(pot)
	# Pot rim
	var rim = ColorRect.new()
	rim.size = Vector2(16, 3)
	rim.position = Vector2(-1, 2)
	rim.color = OfficePalette.POT_TERRACOTTA_DARK
	item.add_child(rim)
	# Soil
	var soil = ColorRect.new()
	soil.size = Vector2(12, 3)
	soil.position = Vector2(1, 3)
	soil.color = OfficePalette.SOIL_DARK
	item.add_child(soil)
	# Succulent/cactus body
	var cactus = ColorRect.new()
	cactus.size = Vector2(8, 10)
	cactus.position = Vector2(3, -6)
	cactus.color = OfficePalette.LEAF_GREEN
	item.add_child(cactus)
	# Small arm/leaf
	var leaf = ColorRect.new()
	leaf.size = Vector2(4, 6)
	leaf.position = Vector2(10, -4)
	leaf.color = OfficePalette.LEAF_GREEN_LIGHT
	item.add_child(leaf)

static func _create_pencil_cup(item: Node2D) -> void:
	# Cup
	var cup = ColorRect.new()
	cup.size = Vector2(10, 14)
	cup.position = Vector2(0, 0)
	cup.color = OfficePalette.PENCIL_CUP
	item.add_child(cup)
	# Pencils
	var pencil1 = ColorRect.new()
	pencil1.size = Vector2(2, 8)
	pencil1.position = Vector2(2, -6)
	pencil1.color = OfficePalette.PENCIL_YELLOW
	item.add_child(pencil1)
	var pencil2 = ColorRect.new()
	pencil2.size = Vector2(2, 6)
	pencil2.position = Vector2(6, -4)
	pencil2.color = OfficePalette.PENCIL_BLUE
	item.add_child(pencil2)

static func _create_stress_ball(item: Node2D) -> void:
	var ball = ColorRect.new()
	ball.size = Vector2(12, 12)
	ball.position = Vector2(0, 2)
	var ball_colors = [OfficePalette.GRUVBOX_RED_BRIGHT, OfficePalette.GRUVBOX_BLUE_BRIGHT, OfficePalette.GRUVBOX_YELLOW_BRIGHT, OfficePalette.GRUVBOX_AQUA_BRIGHT]
	ball.color = ball_colors[randi() % ball_colors.size()]
	item.add_child(ball)

static func _create_snack(item: Node2D) -> void:
	# Snack wrapper/bag
	var wrapper = ColorRect.new()
	wrapper.size = Vector2(14, 10)
	wrapper.position = Vector2(0, 4)
	var snack_colors = [OfficePalette.GRUVBOX_RED_BRIGHT, OfficePalette.GRUVBOX_BLUE, OfficePalette.GRUVBOX_ORANGE_BRIGHT]
	wrapper.color = snack_colors[randi() % snack_colors.size()]
	item.add_child(wrapper)

static func _create_water_bottle(item: Node2D) -> void:
	# Bottle
	var bottle = ColorRect.new()
	bottle.size = Vector2(8, 18)
	bottle.position = Vector2(0, -4)
	bottle.color = OfficePalette.WATER_BOTTLE
	item.add_child(bottle)
	# Cap
	var cap = ColorRect.new()
	cap.size = Vector2(6, 4)
	cap.position = Vector2(1, -6)
	cap.color = OfficePalette.WATER_BOTTLE_CAP
	item.add_child(cap)

static func _create_figurine(item: Node2D) -> void:
	# Base
	var base = ColorRect.new()
	base.size = Vector2(10, 4)
	base.position = Vector2(0, 10)
	base.color = OfficePalette.FIGURINE_BASE
	item.add_child(base)
	# Figure body
	var fig = ColorRect.new()
	fig.size = Vector2(8, 14)
	fig.position = Vector2(1, -4)
	var fig_colors = [OfficePalette.GRUVBOX_RED_BRIGHT, OfficePalette.GRUVBOX_GREEN, OfficePalette.GRUVBOX_BLUE, OfficePalette.GRUVBOX_YELLOW_BRIGHT]
	fig.color = fig_colors[randi() % fig_colors.size()]
	item.add_child(fig)
