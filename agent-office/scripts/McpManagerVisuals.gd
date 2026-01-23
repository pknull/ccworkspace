extends RefCounted
class_name McpManagerVisuals

# =============================================================================
# MCP MANAGER VISUALS
# =============================================================================
# Visual creation for the MCP Manager entity - a professional manager figure
# with gold tie (MCP branding), clipboard, and glasses.

var manager: Node2D

# Visual nodes
var shadow: ColorRect = null
var body: ColorRect = null
var shirt: ColorRect = null
var tie: ColorRect = null
var head: ColorRect = null
var hair: ColorRect = null
var eyes: Array[ColorRect] = []
var glasses_frame: ColorRect = null
var glasses_lens_left: ColorRect = null
var glasses_lens_right: ColorRect = null
var trousers: ColorRect = null
var clipboard: Node2D = null
var clipboard_paper: ColorRect = null
var clipboard_lines: Array[ColorRect] = []

# Appearance
var skin_color: Color = OfficePalette.SKIN_LIGHT
var hair_color: Color = Color(0.35, 0.25, 0.20)  # Brown hair
var is_facing_left: bool = true

func _init(p_manager: Node2D) -> void:
	manager = p_manager
	# Randomize appearance slightly
	var skin_tones = [
		OfficePalette.SKIN_LIGHT,
		OfficePalette.SKIN_MEDIUM,
		OfficePalette.SKIN_TAN,
	]
	skin_color = skin_tones[randi() % skin_tones.size()]

	var hair_colors = [
		Color(0.35, 0.25, 0.20),  # Brown
		Color(0.25, 0.20, 0.18),  # Dark brown
		Color(0.45, 0.35, 0.28),  # Light brown
		Color(0.15, 0.12, 0.10),  # Black
	]
	hair_color = hair_colors[randi() % hair_colors.size()]

func create_visuals() -> void:
	# Shadow
	shadow = ColorRect.new()
	shadow.size = Vector2(20, 8)
	shadow.position = Vector2(-10, 18)
	shadow.color = OfficePalette.SHADOW
	shadow.z_index = -4
	manager.add_child(shadow)

	# Trousers (below body)
	trousers = ColorRect.new()
	trousers.size = Vector2(16, 12)
	trousers.position = Vector2(-8, 8)
	trousers.color = OfficePalette.MCP_MANAGER_TROUSERS
	trousers.z_index = -2
	manager.add_child(trousers)

	# Body/Shirt
	body = ColorRect.new()
	body.size = Vector2(18, 16)
	body.position = Vector2(-9, -8)
	body.color = OfficePalette.MCP_MANAGER_SHIRT
	body.z_index = -1
	manager.add_child(body)
	shirt = body  # Alias

	# Gold Tie (MCP branding)
	tie = ColorRect.new()
	tie.size = Vector2(4, 14)
	tie.position = Vector2(-2, -6)
	tie.color = OfficePalette.MCP_MANAGER_TIE
	tie.z_index = 0
	manager.add_child(tie)

	# Head
	head = ColorRect.new()
	head.size = Vector2(14, 14)
	head.position = Vector2(-7, -22)
	head.color = skin_color
	head.z_index = 1
	manager.add_child(head)

	# Hair (manager style - neat, short)
	hair = ColorRect.new()
	hair.size = Vector2(14, 5)
	hair.position = Vector2(-7, -24)
	hair.color = hair_color
	hair.z_index = 2
	manager.add_child(hair)

	# Side hair (parted)
	var side_hair = ColorRect.new()
	side_hair.size = Vector2(3, 8)
	side_hair.position = Vector2(-7, -22)
	side_hair.color = hair_color.darkened(0.1)
	side_hair.z_index = 2
	manager.add_child(side_hair)

	# Eyes
	var eye_left = ColorRect.new()
	eye_left.size = Vector2(3, 3)
	eye_left.position = Vector2(-5, -17)
	eye_left.color = OfficePalette.EYE_COLOR
	eye_left.z_index = 3
	manager.add_child(eye_left)
	eyes.append(eye_left)

	var eye_right = ColorRect.new()
	eye_right.size = Vector2(3, 3)
	eye_right.position = Vector2(2, -17)
	eye_right.color = OfficePalette.EYE_COLOR
	eye_right.z_index = 3
	manager.add_child(eye_right)
	eyes.append(eye_right)

	# Glasses
	_create_glasses()

	# Clipboard (held in hand)
	_create_clipboard()

func _create_glasses() -> void:
	# Glasses frame - bridge
	glasses_frame = ColorRect.new()
	glasses_frame.size = Vector2(14, 2)
	glasses_frame.position = Vector2(-7, -17)
	glasses_frame.color = OfficePalette.MCP_MANAGER_GLASSES_FRAME
	glasses_frame.z_index = 4
	manager.add_child(glasses_frame)

	# Left lens
	glasses_lens_left = ColorRect.new()
	glasses_lens_left.size = Vector2(5, 4)
	glasses_lens_left.position = Vector2(-6, -18)
	glasses_lens_left.color = OfficePalette.MCP_MANAGER_GLASSES_LENS
	glasses_lens_left.z_index = 4
	manager.add_child(glasses_lens_left)

	# Left lens frame
	var frame_left = ColorRect.new()
	frame_left.size = Vector2(6, 5)
	frame_left.position = Vector2(-6.5, -18.5)
	frame_left.color = OfficePalette.MCP_MANAGER_GLASSES_FRAME
	frame_left.z_index = 3
	manager.add_child(frame_left)

	# Right lens
	glasses_lens_right = ColorRect.new()
	glasses_lens_right.size = Vector2(5, 4)
	glasses_lens_right.position = Vector2(1, -18)
	glasses_lens_right.color = OfficePalette.MCP_MANAGER_GLASSES_LENS
	glasses_lens_right.z_index = 4
	manager.add_child(glasses_lens_right)

	# Right lens frame
	var frame_right = ColorRect.new()
	frame_right.size = Vector2(6, 5)
	frame_right.position = Vector2(0.5, -18.5)
	frame_right.color = OfficePalette.MCP_MANAGER_GLASSES_FRAME
	frame_right.z_index = 3
	manager.add_child(frame_right)

func _create_clipboard() -> void:
	clipboard = Node2D.new()
	clipboard.position = Vector2(12, -2)  # Held at side
	clipboard.z_index = 5
	manager.add_child(clipboard)

	# Clipboard backing
	var backing = ColorRect.new()
	backing.size = Vector2(12, 16)
	backing.position = Vector2(0, -8)
	backing.color = OfficePalette.MCP_MANAGER_CLIPBOARD
	clipboard.add_child(backing)

	# Metal clip at top
	var clip = ColorRect.new()
	clip.size = Vector2(6, 3)
	clip.position = Vector2(3, -10)
	clip.color = OfficePalette.MCP_MANAGER_CLIPBOARD_CLIP
	clipboard.add_child(clip)

	# Paper
	clipboard_paper = ColorRect.new()
	clipboard_paper.size = Vector2(10, 13)
	clipboard_paper.position = Vector2(1, -6)
	clipboard_paper.color = OfficePalette.MCP_MANAGER_PAPER
	clipboard.add_child(clipboard_paper)

	# Lines on paper (representing notes)
	for i in range(4):
		var line = ColorRect.new()
		line.size = Vector2(8, 1)
		line.position = Vector2(2, -4 + i * 3)
		line.color = OfficePalette.MCP_MANAGER_PAPER_LINES
		clipboard.add_child(line)
		clipboard_lines.append(line)

func set_facing(left: bool) -> void:
	if is_facing_left == left:
		return
	is_facing_left = left

	# Flip clipboard position
	if clipboard:
		clipboard.position.x = -12 if left else 12
		clipboard.scale.x = -1 if left else 1

func animate_walk(animation_timer: float) -> void:
	# Subtle bobbing while walking
	if body:
		body.position.y = -8 + sin(animation_timer * 10.0) * 1.5
	if head:
		head.position.y = -22 + sin(animation_timer * 10.0) * 1.0
	if hair:
		hair.position.y = -24 + sin(animation_timer * 10.0) * 1.0
	if clipboard:
		clipboard.position.y = -2 + sin(animation_timer * 10.0 + 0.5) * 1.0
		clipboard.rotation = sin(animation_timer * 5.0) * 0.05

func animate_idle(animation_timer: float) -> void:
	# Subtle idle animation - clipboard tapping
	if clipboard:
		clipboard.rotation = sin(animation_timer * 2.0) * 0.03

func animate_checking(animation_timer: float) -> void:
	# Looking at clipboard animation
	if head:
		head.rotation = sin(animation_timer * 1.5) * 0.1
	if clipboard:
		# Clipboard raised for reading
		clipboard.position.y = -8 + sin(animation_timer * 1.0) * 2.0

func animate_scribbling(animation_timer: float) -> void:
	# Writing on clipboard animation
	if clipboard:
		clipboard.position.y = -6
		# Rapid small movements like writing
		clipboard.rotation = sin(animation_timer * 15.0) * 0.02
	# Extend random lines to simulate writing
	if clipboard_lines.size() > 0:
		var line_idx = int(animation_timer * 3.0) % clipboard_lines.size()
		for i in range(clipboard_lines.size()):
			var target_width = 8.0 if i <= line_idx else 4.0 + randf() * 4.0
			clipboard_lines[i].size.x = lerp(clipboard_lines[i].size.x, target_width, 0.1)

func animate_looking_up(animation_timer: float) -> void:
	# Looking up at something (weather change)
	if head:
		head.position.y = -24  # Head tilted up
	if glasses_frame:
		glasses_frame.position.y = -19  # Glasses adjust

func reset_animations() -> void:
	# Reset to default positions
	if body:
		body.position.y = -8
	if head:
		head.position.y = -22
		head.rotation = 0
	if hair:
		hair.position.y = -24
	if clipboard:
		clipboard.position.y = -2
		clipboard.rotation = 0
	if glasses_frame:
		glasses_frame.position.y = -17
	for line in clipboard_lines:
		line.size.x = 8

func show_speech_bubble(text: String) -> Node2D:
	var bubble = Node2D.new()
	bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	manager.add_child(bubble)

	var text_width = text.length() * 6 + 10
	var bubble_bg = ColorRect.new()
	bubble_bg.size = Vector2(max(text_width, 45), 18)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -45)
	bubble_bg.color = OfficePalette.SPEECH_BUBBLE
	bubble.add_child(bubble_bg)

	var border = ColorRect.new()
	border.size = bubble_bg.size + Vector2(2, 2)
	border.position = bubble_bg.position - Vector2(1, 1)
	border.color = OfficePalette.SPEECH_BUBBLE_BORDER
	border.z_index = -1
	bubble.add_child(border)

	var pointer = ColorRect.new()
	pointer.size = Vector2(6, 6)
	pointer.position = Vector2(-3, -28)
	pointer.color = OfficePalette.SPEECH_BUBBLE
	bubble.add_child(pointer)

	var label = Label.new()
	label.text = text
	label.position = bubble_bg.position + Vector2(5, 1)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	bubble.add_child(label)

	return bubble
