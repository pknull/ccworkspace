extends FurnitureBase
class_name FurnitureTerminalFurniture

## Large terminal station for embedded CLI sessions.

const TERMINAL_COLUMNS := 80
const TERMINAL_ROWS := 24
const TERMINAL_FONT_SIZE := 11  # Gohufont 11px bitmap font
const CELL_WIDTH := 6   # gohufont-11: 6px wide
const CELL_HEIGHT := 11  # gohufont-11: 11px tall
const BORDER_THICKNESS := 10
const TERMINAL_PADDING := 2  # Extra padding for terminal's internal margins
const SHADOW_OFFSET := Vector2(3, 3)

var _terminal_size: Vector2 = Vector2.ZERO
var _frame_size: Vector2 = Vector2.ZERO

const TERMINAL_CLASS := "Terminal"
const PTY_CLASS := "PTY"
const XTERM_GDEXTENSION_PATH := "res://addons/godot_xterm/godot-xterm.gdextension"

static var _xterm_load_attempted := false

var _terminal: Control = null
var _pty: Node = null
var _shadow_rect: ColorRect = null
var _frame_rect: ColorRect = null
var _bezel_rect: ColorRect = null
var _status_indicator: ColorRect = null
var _restart_pending := false
var _last_focus_state := false

func _init() -> void:
	furniture_type = "terminal_furniture"
	traits = []
	capacity = 0
	obstacle_size = Vector2.ZERO
	slots = []

func _ready() -> void:
	drag_bounds_min = Vector2(60, 120)
	drag_bounds_max = Vector2(1220, 580)
	super._ready()
	call_deferred("_sync_terminal_metrics")

func _process(_delta: float) -> void:
	# Update status indicator based on terminal focus
	var is_focused = _terminal != null and _terminal.has_focus()
	if is_focused != _last_focus_state:
		_last_focus_state = is_focused
		if _status_indicator:
			_status_indicator.color = OfficePalette.STATUS_LED_GREEN if is_focused else OfficePalette.STATUS_LED_RED

func _input(event: InputEvent) -> void:
	# Handle mouse clicks to focus/unfocus terminal
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Let popups handle clicks first
			if office_manager and office_manager.has_method("is_any_popup_open") and office_manager.is_any_popup_open():
				super._input(event)
				return

			var local_pos = get_local_mouse_position()
			if _is_inside_terminal(local_pos):
				# Click on terminal - focus it, let terminal handle mouse for selection
				if _terminal:
					_terminal.grab_focus()
				# Don't call super - prevents DraggableItem from starting drag
				# Don't mark as handled - lets terminal receive mouse for text selection
				return
			elif click_area.has_point(local_pos):
				# Click on frame border - release terminal focus, let parent handle drag
				if _terminal and _terminal.has_focus():
					_terminal.release_focus()
				# Don't mark as handled - let DraggableItem start drag
				super._input(event)
				return
			else:
				# Click outside furniture - release focus
				if _terminal and _terminal.has_focus():
					_terminal.release_focus()

	super._input(event)

func _build_visuals() -> void:
	_terminal_size = _calc_terminal_size_fallback()

	# Shadow under frame
	_shadow_rect = ColorRect.new()
	_shadow_rect.color = OfficePalette.SHADOW
	_shadow_rect.z_index = -1
	add_child(_shadow_rect)

	# Cream border frame
	_frame_rect = ColorRect.new()
	_frame_rect.color = OfficePalette.DESK_SURFACE
	add_child(_frame_rect)

	# Inner bezel (slight contrast)
	_bezel_rect = ColorRect.new()
	_bezel_rect.color = OfficePalette.DESK_EDGE
	add_child(_bezel_rect)

	# Status indicator light (top-right corner of frame)
	_status_indicator = ColorRect.new()
	_status_indicator.size = Vector2(12, 12)
	_status_indicator.color = OfficePalette.STATUS_LED_RED
	_status_indicator.z_index = 100
	add_child(_status_indicator)

	_apply_frame_layout(_terminal_size)

	# GodotXterm terminal
	_terminal = _create_terminal()
	if _terminal == null:
		return
	add_child(_terminal)
	_terminal.position = _rounded_vec2(Vector2(-_terminal_size.x / 2, -_terminal_size.y / 2))
	_terminal.size = _rounded_vec2(_terminal_size)
	_terminal.custom_minimum_size = _terminal.size
	# Defer size adjustment to after terminal calculates its cell_size
	# Use a timer to ensure terminal is fully initialized
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(_adjust_terminal_size)

	# PTY node wired to the terminal
	_pty = _create_pty()
	if _pty:
		_terminal.add_child(_pty)
		_pty.set("cols", TERMINAL_COLUMNS)
		_pty.set("rows", TERMINAL_ROWS)
		_pty.set("terminal_path", NodePath(".."))
		if _pty.has_signal("exited"):
			_pty.connect("exited", Callable(self, "_on_pty_exited"))
		else:
			push_warning("TerminalFurniture: PTY has no 'exited' signal")
		_start_shell()

func _create_terminal() -> Control:
	_ensure_xterm_loaded()
	if not ClassDB.class_exists(TERMINAL_CLASS):
		push_error("TerminalFurniture: GodotXterm not loaded (Terminal class missing).")
		return null
	var terminal: Control = ClassDB.instantiate(TERMINAL_CLASS)
	terminal.focus_mode = Control.FOCUS_ALL
	terminal.mouse_filter = Control.MOUSE_FILTER_STOP
	# Use default settings - no texture filter overrides
	_apply_terminal_theme(terminal)
	return terminal

func _create_pty() -> Node:
	_ensure_xterm_loaded()
	if not ClassDB.class_exists(PTY_CLASS):
		push_error("TerminalFurniture: GodotXterm not loaded (PTY class missing).")
		return null
	return ClassDB.instantiate(PTY_CLASS)

func _apply_terminal_theme(terminal: Control) -> void:
	# Gohufont 11px - crisp bitmap font, retro aesthetic
	var font_path = "res://third_party/gohufont/gohufont-11.ttf"
	if ResourceLoader.exists(font_path):
		var font_file = load(font_path) as FontFile
		if font_file:
			font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font_file.hinting = TextServer.HINTING_NONE
			font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			terminal.add_theme_font_override("normal_font", font_file)
			terminal.add_theme_font_override("bold_font", font_file)
			terminal.add_theme_font_override("italics_font", font_file)
			terminal.add_theme_font_override("bold_italics_font", font_file)
	terminal.add_theme_font_size_override("font_size", TERMINAL_FONT_SIZE)

	# Monochrome amber/orange retro terminal theme
	var bg = Color(0.06, 0.04, 0.02, 1.0)      # Dark amber background
	var fg = Color(1.0, 0.6, 0.2, 1.0)          # Amber/orange foreground

	terminal.add_theme_color_override("background_color", bg)
	terminal.add_theme_color_override("foreground_color", fg)

	# Map ALL ANSI colors to the same amber - true monochrome
	for i in range(16):
		terminal.add_theme_color_override("ansi_%d_color" % i, fg)

func _calc_terminal_size_fallback() -> Vector2:
	# Use exact pixel dimensions for crisp bitmap font rendering
	var width = TERMINAL_COLUMNS * CELL_WIDTH
	var height = TERMINAL_ROWS * CELL_HEIGHT
	return Vector2(width, height)

func _sync_terminal_metrics() -> void:
	if not _terminal:
		return
	# Use fixed cell dimensions for bitmap font - don't query terminal
	# as it may report wrong sizes for bitmap fonts
	var cell_size = Vector2(CELL_WIDTH, CELL_HEIGHT)
	var terminal_size = Vector2(TERMINAL_COLUMNS * cell_size.x, TERMINAL_ROWS * cell_size.y)
	_apply_frame_layout(terminal_size)
	_terminal.position = _rounded_vec2(Vector2(-terminal_size.x / 2, -terminal_size.y / 2))
	_terminal.size = _rounded_vec2(terminal_size)
	_terminal.custom_minimum_size = _terminal.size

func _adjust_terminal_size() -> void:
	# Query terminal's actual cell_size and resize to get correct cols/rows
	if not _terminal:
		return
	if _terminal.has_method("get_cell_size"):
		var actual_cell_size: Vector2 = _terminal.call("get_cell_size")
		if actual_cell_size.x > 0 and actual_cell_size.y > 0:
			# Resize terminal to get exactly TERMINAL_COLUMNS x TERMINAL_ROWS
			var new_size = Vector2(TERMINAL_COLUMNS * actual_cell_size.x, TERMINAL_ROWS * actual_cell_size.y)
			_terminal_size = _rounded_vec2(new_size)
			_terminal.size = _terminal_size
			_terminal.custom_minimum_size = _terminal.size
			_terminal.position = _rounded_vec2(Vector2(-_terminal_size.x / 2, -_terminal_size.y / 2))

			# Update frame to match new terminal size (add padding for terminal's internal margins)
			var padded_size = _terminal_size + Vector2(TERMINAL_PADDING * 2, TERMINAL_PADDING * 2)
			_frame_size = _rounded_vec2(padded_size + Vector2(BORDER_THICKNESS * 2, BORDER_THICKNESS * 2))

			if _shadow_rect:
				_shadow_rect.size = _rounded_vec2(_frame_size + SHADOW_OFFSET * 2)
				_shadow_rect.position = _rounded_vec2(Vector2(-_frame_size.x / 2, -_frame_size.y / 2) + SHADOW_OFFSET)
			if _frame_rect:
				_frame_rect.size = _frame_size
				_frame_rect.position = _rounded_vec2(Vector2(-_frame_size.x / 2, -_frame_size.y / 2))
			if _bezel_rect:
				_bezel_rect.size = _rounded_vec2(padded_size + Vector2(BORDER_THICKNESS, BORDER_THICKNESS))
				_bezel_rect.position = _rounded_vec2(Vector2(-_bezel_rect.size.x / 2, -_bezel_rect.size.y / 2))
			if _status_indicator:
				_status_indicator.position = _rounded_vec2(Vector2(_frame_size.x / 2 - 16, -_frame_size.y / 2 + 2))

			obstacle_size = _frame_size
			click_area = Rect2(
				-_frame_size.x / 2 - 6,
				-_frame_size.y / 2 - 6,
				_frame_size.x + 12,
				_frame_size.y + 12
			)

func _apply_frame_layout(terminal_size: Vector2) -> void:
	_terminal_size = _rounded_vec2(terminal_size)
	_frame_size = _rounded_vec2(_terminal_size + Vector2(BORDER_THICKNESS * 2, BORDER_THICKNESS * 2))
	if _shadow_rect:
		_shadow_rect.size = _rounded_vec2(_frame_size + SHADOW_OFFSET * 2)
		_shadow_rect.position = _rounded_vec2(Vector2(-_frame_size.x / 2, -_frame_size.y / 2) + SHADOW_OFFSET)
	if _frame_rect:
		_frame_rect.size = _frame_size
		_frame_rect.position = _rounded_vec2(Vector2(-_frame_size.x / 2, -_frame_size.y / 2))
	if _bezel_rect:
		_bezel_rect.size = _rounded_vec2(_terminal_size + Vector2(BORDER_THICKNESS, BORDER_THICKNESS))
		_bezel_rect.position = _rounded_vec2(Vector2(-_bezel_rect.size.x / 2, -_bezel_rect.size.y / 2))
	if _status_indicator:
		# Position in top-right corner of the frame border
		_status_indicator.position = _rounded_vec2(Vector2(_frame_size.x / 2 - 16, -_frame_size.y / 2 + 2))

	obstacle_size = Vector2(_frame_size.x, _frame_size.y)
	click_area = Rect2(
		-_frame_size.x / 2 - 6,
		-_frame_size.y / 2 - 6,
		_frame_size.x + 12,
		_frame_size.y + 12
	)

func _is_inside_terminal(local_pos: Vector2) -> bool:
	if _terminal == null:
		return false
	return Rect2(_terminal.position, _terminal.size).has_point(local_pos)

func _get_default_shell() -> String:
	if OS.has_environment("SHELL"):
		return OS.get_environment("SHELL")
	return "sh"

func _get_shell_cwd() -> String:
	if OS.has_environment("HOME"):
		return OS.get_environment("HOME")
	return "."

func _start_shell() -> void:
	if _pty == null:
		return
	var shell = _get_default_shell()
	var cwd = _get_shell_cwd()
	var result = _pty.call("fork", shell, PackedStringArray(), cwd, TERMINAL_COLUMNS, TERMINAL_ROWS)
	if result != OK:
		push_warning("TerminalFurniture: PTY fork failed (%s)" % [str(result)])

func _on_pty_exited(_exit_code: int, _signum: int) -> void:
	if _restart_pending:
		return
	_restart_pending = true
	call_deferred("_restart_shell")

func _restart_shell() -> void:
	_restart_pending = false

	# Clear the terminal before restarting
	if _terminal and _terminal.has_method("clear"):
		_terminal.call("clear")

	# Destroy old PTY and create a new one
	if _pty:
		_pty.queue_free()
		_pty = null

	_pty = _create_pty()
	if _pty and _terminal:
		_terminal.add_child(_pty)
		_pty.set("cols", TERMINAL_COLUMNS)
		_pty.set("rows", TERMINAL_ROWS)
		_pty.set("terminal_path", NodePath(".."))
		if _pty.has_signal("exited"):
			_pty.connect("exited", Callable(self, "_on_pty_exited"))
		_start_shell()
		_terminal.grab_focus()

func _rounded_vec2(value: Vector2) -> Vector2:
	return Vector2(round(value.x), round(value.y))

func _ensure_xterm_loaded() -> void:
	if _xterm_load_attempted:
		return
	_xterm_load_attempted = true
	var manager = Engine.get_singleton("GDExtensionManager")
	if manager == null:
		push_warning("TerminalFurniture: GDExtensionManager not available.")
		return
	var err = manager.call("load_extension", XTERM_GDEXTENSION_PATH)
	if err != OK:
		var global_path = ProjectSettings.globalize_path(XTERM_GDEXTENSION_PATH)
		err = manager.call("load_extension", global_path)
	if err != OK:
		push_warning("TerminalFurniture: Failed to load GodotXterm GDExtension (%s)." % [str(err)])
