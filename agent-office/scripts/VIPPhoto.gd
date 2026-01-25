extends Node2D
class_name VIPPhoto

# =============================================================================
# VIP PHOTO - Wall Decoration Showing Top Agent
# =============================================================================
# Displays the highest XP agent's portrait on the wall.
# Clicking opens their full profile.

signal clicked(agent_id: int)

# Visual elements
var frame: ColorRect
var frame_inner: ColorRect
var portrait_bg: ColorRect
var portrait_container: Control  # Container for the mini portrait
var nameplate_bg: ColorRect
var name_label: Label
var title_label: Label
var star_decoration: Label

# Current agent displayed
var current_agent_id: int = -1
var current_profile: AgentProfile = null

# Layout - sized to fit on the wall (wall height ~68px)
const FRAME_WIDTH: float = 36
const FRAME_HEIGHT: float = 48
const PORTRAIT_SIZE: float = 24

# Use centralized arrays from OfficePalette
const HAIR_COLORS = OfficePalette.HAIR_COLORS
const SKIN_TONES = OfficePalette.SKIN_TONES

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	# Outer frame (gold/ornate)
	frame = ColorRect.new()
	frame.size = Vector2(FRAME_WIDTH, FRAME_HEIGHT)
	frame.position = Vector2(-FRAME_WIDTH / 2, -FRAME_HEIGHT / 2)
	frame.color = OfficePalette.GRUVBOX_YELLOW
	add_child(frame)

	# Inner frame
	frame_inner = ColorRect.new()
	frame_inner.size = Vector2(FRAME_WIDTH - 6, FRAME_HEIGHT - 6)
	frame_inner.position = Vector2(-FRAME_WIDTH / 2 + 3, -FRAME_HEIGHT / 2 + 3)
	frame_inner.color = OfficePalette.GRUVBOX_BG1
	add_child(frame_inner)

	# Star decoration at top (smaller)
	star_decoration = Label.new()
	star_decoration.text = "*"
	star_decoration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_decoration.position = Vector2(-8, -FRAME_HEIGHT / 2 - 8)
	star_decoration.size = Vector2(16, 10)
	star_decoration.add_theme_font_size_override("font_size", 8)
	star_decoration.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW_BRIGHT)
	add_child(star_decoration)

	# Portrait background
	portrait_bg = ColorRect.new()
	portrait_bg.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_bg.position = Vector2(-PORTRAIT_SIZE / 2, -FRAME_HEIGHT / 2 + 8)
	portrait_bg.color = OfficePalette.GRUVBOX_BG2
	add_child(portrait_bg)

	# Portrait container for mini head
	portrait_container = Control.new()
	portrait_container.position = Vector2(-PORTRAIT_SIZE / 2, -FRAME_HEIGHT / 2 + 8)
	portrait_container.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	add_child(portrait_container)

	# Nameplate background
	nameplate_bg = ColorRect.new()
	nameplate_bg.size = Vector2(FRAME_WIDTH - 6, 14)
	nameplate_bg.position = Vector2(-FRAME_WIDTH / 2 + 3, FRAME_HEIGHT / 2 - 17)
	nameplate_bg.color = OfficePalette.GRUVBOX_BG
	add_child(nameplate_bg)

	# Name label
	name_label = Label.new()
	name_label.text = "---"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-FRAME_WIDTH / 2 + 3, FRAME_HEIGHT / 2 - 17)
	name_label.size = Vector2(FRAME_WIDTH - 6, 14)
	name_label.add_theme_font_size_override("font_size", 7)
	name_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	add_child(name_label)

	# Title label (hidden at this size - too small to read)
	title_label = Label.new()
	title_label.text = ""
	title_label.visible = false  # Too small to be readable
	add_child(title_label)

	# Create placeholder portrait
	_create_placeholder_portrait()

func _create_placeholder_portrait() -> void:
	# Clear existing
	for child in portrait_container.get_children():
		child.queue_free()

	# Question mark placeholder
	var placeholder = Label.new()
	placeholder.text = "?"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.position = Vector2(0, -4)
	placeholder.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	portrait_container.add_child(placeholder)

func _create_mini_portrait(profile: AgentProfile) -> void:
	# Clear existing
	for child in portrait_container.get_children():
		child.queue_free()

	var skin_color = SKIN_TONES[profile.skin_color_index % SKIN_TONES.size()]
	var hair_color = HAIR_COLORS[profile.hair_color_index % HAIR_COLORS.size()]

	# Mini head (centered in portrait area)
	var head = ColorRect.new()
	head.size = Vector2(14, 14)
	head.position = Vector2(5, 6)
	head.color = skin_color
	portrait_container.add_child(head)

	# Eyes
	var left_eye = ColorRect.new()
	left_eye.size = Vector2(2, 2)
	left_eye.position = Vector2(8, 11)
	left_eye.color = OfficePalette.EYE_COLOR
	portrait_container.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.size = Vector2(2, 2)
	right_eye.position = Vector2(14, 11)
	right_eye.color = OfficePalette.EYE_COLOR
	portrait_container.add_child(right_eye)

	# Hair based on gender and style
	if profile.is_female:
		_create_female_hair(profile.hair_style_index, hair_color)
	else:
		_create_male_hair(hair_color)

func _create_male_hair(hair_color: Color) -> void:
	# Short male hair
	var hair = ColorRect.new()
	hair.size = Vector2(16, 6)
	hair.position = Vector2(4, 2)
	hair.color = hair_color
	portrait_container.add_child(hair)

func _create_female_hair(style_index: int, hair_color: Color) -> void:
	match style_index % 3:
		0:
			# Long hair with side parts
			var hair_top = ColorRect.new()
			hair_top.size = Vector2(18, 8)
			hair_top.position = Vector2(3, 1)
			hair_top.color = hair_color
			portrait_container.add_child(hair_top)

			var hair_left = ColorRect.new()
			hair_left.size = Vector2(4, 14)
			hair_left.position = Vector2(2, 5)
			hair_left.color = hair_color
			portrait_container.add_child(hair_left)

			var hair_right = ColorRect.new()
			hair_right.size = Vector2(4, 14)
			hair_right.position = Vector2(18, 5)
			hair_right.color = hair_color
			portrait_container.add_child(hair_right)
		1:
			# Bob cut
			var hair = ColorRect.new()
			hair.size = Vector2(20, 10)
			hair.position = Vector2(2, 0)
			hair.color = hair_color
			portrait_container.add_child(hair)

			var hair_sides = ColorRect.new()
			hair_sides.size = Vector2(22, 6)
			hair_sides.position = Vector2(1, 6)
			hair_sides.color = hair_color
			portrait_container.add_child(hair_sides)
		2:
			# Ponytail/updo
			var hair = ColorRect.new()
			hair.size = Vector2(18, 7)
			hair.position = Vector2(3, 0)
			hair.color = hair_color
			portrait_container.add_child(hair)

			# Bun
			var bun = ColorRect.new()
			bun.size = Vector2(6, 6)
			bun.position = Vector2(9, -4)
			bun.color = hair_color
			portrait_container.add_child(bun)

func update_display(profile: AgentProfile) -> void:
	if profile == null:
		current_agent_id = -1
		current_profile = null
		name_label.text = "---"
		title_label.text = ""
		_create_placeholder_portrait()
		return

	current_agent_id = profile.id
	current_profile = profile
	name_label.text = profile.agent_name
	title_label.text = profile.get_title()

	# Create mini portrait with agent's appearance
	_create_mini_portrait(profile)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = get_local_mouse_position()
			var click_rect = Rect2(-FRAME_WIDTH / 2, -FRAME_HEIGHT / 2, FRAME_WIDTH, FRAME_HEIGHT)
			if click_rect.has_point(local_pos) and current_agent_id >= 0:
				clicked.emit(current_agent_id)
