extends Node2D
class_name AchievementBoard

# =============================================================================
# ACHIEVEMENT BOARD - Wall Decoration Showing Achievement Progress
# =============================================================================
# Displays achievement count on a small board. Clicking opens full popup.

signal clicked()

# Visual elements
var board_bg: ColorRect
var frame: ColorRect
var icon_label: Label
var count_label: Label

# Data
var achievement_system: AchievementSystem = null

# Layout - sized to fit on the wall
const BOARD_WIDTH: float = 40
const BOARD_HEIGHT: float = 50

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	# Frame
	frame = ColorRect.new()
	frame.size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	frame.position = Vector2(-BOARD_WIDTH / 2, -BOARD_HEIGHT / 2)
	frame.color = OfficePalette.GRUVBOX_YELLOW
	add_child(frame)

	# Board background
	board_bg = ColorRect.new()
	board_bg.size = Vector2(BOARD_WIDTH - 4, BOARD_HEIGHT - 4)
	board_bg.position = Vector2(-BOARD_WIDTH / 2 + 2, -BOARD_HEIGHT / 2 + 2)
	board_bg.color = OfficePalette.GRUVBOX_BG1
	add_child(board_bg)

	# Trophy icon (ASCII for better font compatibility)
	icon_label = Label.new()
	icon_label.text = "[*]"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.position = Vector2(-BOARD_WIDTH / 2 + 2, -BOARD_HEIGHT / 2 + 6)
	icon_label.size = Vector2(BOARD_WIDTH - 4, 20)
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	add_child(icon_label)

	# Count label
	count_label = Label.new()
	count_label.text = "0/?"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.position = Vector2(-BOARD_WIDTH / 2 + 2, -BOARD_HEIGHT / 2 + 28)
	count_label.size = Vector2(BOARD_WIDTH - 4, 16)
	count_label.add_theme_font_size_override("font_size", 9)
	count_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT)
	add_child(count_label)

func setup(system: AchievementSystem) -> void:
	achievement_system = system
	if achievement_system:
		achievement_system.achievement_unlocked.connect(_on_achievement_unlocked)
	refresh_display()

func _on_achievement_unlocked(_achievement_id: String) -> void:
	refresh_display()

func refresh_display() -> void:
	if achievement_system == null:
		count_label.text = "0/?"
		return

	var unlocked = achievement_system.get_unlocked_count()
	var total = achievement_system.get_total_count()
	count_label.text = "%d/%d" % [unlocked, total]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = get_local_mouse_position()
			var click_rect = Rect2(-BOARD_WIDTH / 2, -BOARD_HEIGHT / 2, BOARD_WIDTH, BOARD_HEIGHT)
			if click_rect.has_point(local_pos):
				clicked.emit()
