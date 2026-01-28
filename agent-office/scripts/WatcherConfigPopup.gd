extends CanvasLayer
class_name WatcherConfigPopup

# =============================================================================
# WATCHER CONFIG POPUP - Configure harness watchers
# =============================================================================

signal close_requested()

const HARNESS_ORDER = ["claude", "codex", "clawdbot", "opencode", "gemini"]
const HARNESS_LABELS = {
	"claude": "Claude Code",
	"codex": "Codex",
	"clawdbot": "Clawdbot",
	"opencode": "OpenCode",
	"gemini": "Gemini",
}
const HARNESS_PATH_HINTS = {
	"claude": "Leave empty for auto-detect",
	"codex": "Leave empty for auto-detect",
	"clawdbot": "Leave empty for auto-detect",
	"opencode": "JSONL folder (required)",
	"gemini": "JSONL file or folder (required)",
}

# Layout constants
const PANEL_WIDTH: float = 560
const PANEL_HEIGHT: float = 440
const HEADER_HEIGHT: float = 130
const FOOTER_HEIGHT: float = 50

# Visual elements
var container: Control
var background: ColorRect
var border: ColorRect
var panel: ColorRect
var title_label: Label
var subtitle_label: Label
var help_label: Label
var close_button: Button
var save_button: Button
var cancel_button: Button
var rows_scroll: ScrollContainer
var rows_container: VBoxContainer

# Data
var transcript_watcher = null
var mcp_server = null
var harness_rows: Dictionary = {}  # harness_id -> {enabled: CheckBox, path: LineEdit}
var mcp_enabled: CheckBox
var mcp_port_input: LineEdit

func _init() -> void:
	layer = OfficeConstants.Z_UI_POPUP_LAYER

func _ready() -> void:
	if container:
		return
	_create_visuals()

func _create_visuals() -> void:
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	var screen_center = Vector2(OfficeConstants.SCREEN_WIDTH / 2, OfficeConstants.SCREEN_HEIGHT / 2)
	var panel_x = screen_center.x - PANEL_WIDTH / 2
	var panel_y = screen_center.y - PANEL_HEIGHT / 2

	background = ColorRect.new()
	background.size = Vector2(OfficeConstants.SCREEN_WIDTH, OfficeConstants.SCREEN_HEIGHT)
	background.position = Vector2.ZERO
	background.color = Color(0, 0, 0, 0.75)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(background)

	border = ColorRect.new()
	border.size = Vector2(PANEL_WIDTH + 4, PANEL_HEIGHT + 4)
	border.position = Vector2(panel_x - 2, panel_y - 2)
	border.color = OfficePalette.GRUVBOX_YELLOW
	container.add_child(border)

	panel = ColorRect.new()
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.position = Vector2(panel_x, panel_y)
	panel.color = OfficePalette.GRUVBOX_BG
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(panel)

	title_label = Label.new()
	title_label.text = "WATCHER CONFIG"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(panel_x, panel_y + 12)
	title_label.size = Vector2(PANEL_WIDTH, 24)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	container.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Configure session paths. Empty = auto-detect (Claude/Codex)."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.position = Vector2(panel_x, panel_y + 36)
	subtitle_label.size = Vector2(PANEL_WIDTH, 20)
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	container.add_child(subtitle_label)

	help_label = Label.new()
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help_label.position = Vector2(panel_x + 20, panel_y + 54)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	help_label.add_theme_font_size_override("font_size", 9)
	help_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT4)
	container.add_child(help_label)
	_update_help_text()

	rows_scroll = ScrollContainer.new()
	rows_scroll.position = Vector2(panel_x + 20, panel_y + HEADER_HEIGHT)
	rows_scroll.size = Vector2(PANEL_WIDTH - 40, PANEL_HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT)
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(rows_scroll)

	rows_container = VBoxContainer.new()
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_container.add_theme_constant_override("separation", 8)
	rows_container.mouse_filter = Control.MOUSE_FILTER_STOP
	rows_scroll.add_child(rows_container)

	_build_rows()
	_create_footer(panel_x, panel_y)

func _build_rows() -> void:
	harness_rows.clear()

	# --- Harness Watchers Section ---
	var harness_section = Label.new()
	harness_section.text = "Harness Watchers"
	harness_section.add_theme_font_size_override("font_size", 12)
	harness_section.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	rows_container.add_child(harness_section)

	_add_spacer(4)

	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_container.add_child(header)

	var header_harness = Label.new()
	header_harness.text = "Harness"
	header_harness.custom_minimum_size = Vector2(160, 18)
	header_harness.add_theme_font_size_override("font_size", 11)
	header_harness.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	header.add_child(header_harness)

	var header_path = Label.new()
	header_path.text = "Path (empty = auto-detect)"
	header_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_path.add_theme_font_size_override("font_size", 11)
	header_path.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	header.add_child(header_path)

	_add_spacer(2)

	for harness_id in HARNESS_ORDER:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 28)
		rows_container.add_child(row)

		var checkbox = CheckBox.new()
		checkbox.text = HARNESS_LABELS.get(harness_id, harness_id)
		checkbox.custom_minimum_size = Vector2(160, 26)
		checkbox.add_theme_font_size_override("font_size", 12)
		row.add_child(checkbox)

		var row_entry = {"enabled": checkbox}

		var path_input = LineEdit.new()
		path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_input.placeholder_text = HARNESS_PATH_HINTS.get(harness_id, "JSONL file or folder")
		path_input.add_theme_font_size_override("font_size", 12)
		path_input.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
		row.add_child(path_input)
		row_entry["path"] = path_input

		harness_rows[harness_id] = row_entry

	# --- Separator ---
	_add_separator()

	# --- External Inputs Section ---
	var ext_section = Label.new()
	ext_section.text = "External Inputs"
	ext_section.add_theme_font_size_override("font_size", 12)
	ext_section.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
	rows_container.add_child(ext_section)

	_add_spacer(6)

	var mcp_row = HBoxContainer.new()
	mcp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mcp_row.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 28)
	rows_container.add_child(mcp_row)

	mcp_enabled = CheckBox.new()
	mcp_enabled.text = "MCP Server"
	mcp_enabled.custom_minimum_size = Vector2(160, 26)
	mcp_enabled.add_theme_font_size_override("font_size", 12)
	mcp_row.add_child(mcp_enabled)

	var mcp_port_label = Label.new()
	mcp_port_label.text = "Port:"
	mcp_port_label.custom_minimum_size = Vector2(40, 26)
	mcp_port_label.add_theme_font_size_override("font_size", 11)
	mcp_port_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT3)
	mcp_row.add_child(mcp_port_label)

	mcp_port_input = LineEdit.new()
	mcp_port_input.custom_minimum_size = Vector2(70, 26)
	mcp_port_input.placeholder_text = "9999"
	mcp_port_input.add_theme_font_size_override("font_size", 12)
	mcp_port_input.add_theme_color_override("font_color", OfficePalette.GRUVBOX_LIGHT1)
	mcp_row.add_child(mcp_port_input)

func _add_spacer(height: int) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	rows_container.add_child(spacer)

func _add_separator() -> void:
	_add_spacer(10)
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 1)
	sep.color = OfficePalette.GRUVBOX_LIGHT4
	sep.color.a = 0.3
	rows_container.add_child(sep)
	_add_spacer(10)

func _create_footer(panel_x: float, panel_y: float) -> void:
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel_x + PANEL_WIDTH - 30, panel_y + 8)
	close_button.size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

	var button_y = panel_y + PANEL_HEIGHT - 36
	save_button = Button.new()
	save_button.text = "Save"
	save_button.position = Vector2(panel_x + PANEL_WIDTH - 180, button_y)
	save_button.size = Vector2(70, 26)
	save_button.add_theme_font_size_override("font_size", 12)
	save_button.pressed.connect(_on_save_pressed)
	container.add_child(save_button)

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.position = Vector2(panel_x + PANEL_WIDTH - 95, button_y)
	cancel_button.size = Vector2(70, 26)
	cancel_button.add_theme_font_size_override("font_size", 12)
	cancel_button.pressed.connect(_on_cancel_pressed)
	container.add_child(cancel_button)

func show_config(watcher, mcp) -> void:
	transcript_watcher = watcher
	mcp_server = mcp
	if not transcript_watcher:
		return
	if not container:
		_create_visuals()
	var config = transcript_watcher.get_harness_config()
	for harness_id in HARNESS_ORDER:
		var entry = config.get(harness_id, {})
		var row = harness_rows.get(harness_id, {})
		var enabled = bool(entry.get("enabled", true))
		if row.has("enabled"):
			row["enabled"].button_pressed = enabled
		if row.has("path"):
			var saved_path = str(entry.get("path", "")).strip_edges()
			var default_path = _get_default_path_for_harness(harness_id)
			# For claude/codex/clawdbot: show auto-detected path as placeholder, only fill if custom
			if harness_id in ["claude", "codex", "clawdbot"]:
				if not default_path.is_empty():
					row["path"].placeholder_text = default_path
				row["path"].text = saved_path  # Empty if no custom path
			else:
				# For opencode/gemini: fill with default if no saved path
				if saved_path.is_empty():
					row["path"].text = default_path
				else:
					row["path"].text = saved_path
	if mcp_server and mcp_server.has_method("get_mcp_config"):
		var mcp_config = mcp_server.get_mcp_config()
		if mcp_enabled:
			mcp_enabled.button_pressed = bool(mcp_config.get("enabled", true))
		if mcp_port_input:
			mcp_port_input.text = str(mcp_config.get("port", ""))
	_update_help_text()

func _on_save_pressed() -> void:
	if not transcript_watcher:
		close_requested.emit()
		return
	# Implemented harnesses in TranscriptWatcher
	var supported_harnesses = ["claude", "codex", "clawdbot"]
	for harness_id in HARNESS_ORDER:
		var row = harness_rows.get(harness_id, {})
		if harness_id in supported_harnesses:
			var enabled_box = row.get("enabled", null)
			if enabled_box:
				transcript_watcher.set_harness_enabled(harness_id, bool(enabled_box.button_pressed))
			if row.has("path"):
				transcript_watcher.set_harness_path(harness_id, row.get("path").text.strip_edges())
	_apply_external_config()
	close_requested.emit()

func _on_cancel_pressed() -> void:
	close_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()

func _apply_external_config() -> void:
	if mcp_server and mcp_server.has_method("set_mcp_config"):
		var base_mcp = mcp_server.get_mcp_config() if mcp_server.has_method("get_mcp_config") else {}
		var mcp_port = _parse_port(mcp_port_input.text, int(base_mcp.get("port", 9999)))
		var mcp_enabled_state = mcp_enabled.button_pressed if mcp_enabled else true
		mcp_server.set_mcp_config({
			"enabled": mcp_enabled_state,
			"port": mcp_port
		})

func _parse_port(raw: String, fallback: int) -> int:
	var trimmed = raw.strip_edges()
	if trimmed.is_empty():
		return fallback
	var value = int(trimmed)
	if value <= 0 or value > 65535:
		return fallback
	return value

func _update_help_text() -> void:
	if not help_label:
		return
	var os_name = OS.get_name().to_lower()
	var is_windows = os_name == "windows"
	var is_unix = os_name == "macos" or os_name == "linux" or os_name == "x11"
	var unix_home = _get_unix_home()
	var win_home = _get_windows_home()

	var lines: Array[String] = []
	if is_windows:
		lines.append("Examples (Windows):")
		lines.append("Claude: %s\\.claude\\projects\\<project>\\<session>.jsonl" % win_home)
		lines.append("Codex: %s\\.codex\\sessions\\YYYY\\MM\\DD\\<session>.jsonl" % win_home)
		lines.append("Clawdbot: %s\\.clawdbot\\agents\\<agent>\\sessions\\<session>.jsonl" % win_home)
		lines.append("OpenCode: %s\\.local\\share\\opencode\\log" % win_home)
		lines.append("Gemini: %s\\gemini-telemetry.jsonl" % win_home)
		lines.append("Gemini CLI: --telemetry --telemetry-target local --telemetry-outfile <path>")
		lines.append("Gemini settings: %s\\.gemini\\settings.json" % win_home)
	elif is_unix:
		lines.append("Examples (macOS/Linux):")
		lines.append("Claude: %s/.claude/projects/<project>/<session>.jsonl" % unix_home)
		lines.append("Codex: %s/.codex/sessions/YYYY/MM/DD/<session>.jsonl" % unix_home)
		lines.append("Clawdbot: %s/.clawdbot/agents/<agent>/sessions/<session>.jsonl" % unix_home)
		lines.append("OpenCode: %s/.local/share/opencode/log" % unix_home)
		lines.append("Gemini: %s/gemini-telemetry.jsonl" % unix_home)
		lines.append("Gemini CLI: --telemetry --telemetry-target local --telemetry-outfile <path>")
		lines.append("Gemini settings: %s/.gemini/settings.json" % unix_home)
	else:
		lines.append("Examples (macOS/Linux):")
		lines.append("Claude: %s/.claude/projects/<project>/<session>.jsonl" % unix_home)
		lines.append("Codex: %s/.codex/sessions/YYYY/MM/DD/<session>.jsonl" % unix_home)
		lines.append("Clawdbot: %s/.clawdbot/agents/<agent>/sessions/<session>.jsonl" % unix_home)
		lines.append("OpenCode: %s/.local/share/opencode/log" % unix_home)
		lines.append("Gemini: %s/gemini-telemetry.jsonl" % unix_home)
		lines.append("Gemini CLI: --telemetry --telemetry-target local --telemetry-outfile <path>")
		lines.append("Gemini settings: %s/.gemini/settings.json" % unix_home)
		lines.append("Examples (Windows):")
		lines.append("Claude: %s\\.claude\\projects\\<project>\\<session>.jsonl" % win_home)
		lines.append("Codex: %s\\.codex\\sessions\\YYYY\\MM\\DD\\<session>.jsonl" % win_home)
		lines.append("Clawdbot: %s\\.clawdbot\\agents\\<agent>\\sessions\\<session>.jsonl" % win_home)
		lines.append("OpenCode: %s\\.local\\share\\opencode\\log" % win_home)
		lines.append("Gemini: %s\\gemini-telemetry.jsonl" % win_home)
		lines.append("Gemini CLI: --telemetry --telemetry-target local --telemetry-outfile <path>")
		lines.append("Gemini settings: %s\\.gemini\\settings.json" % win_home)

	if mcp_server and mcp_server.has_method("get_mcp_config"):
		var mcp_config = mcp_server.get_mcp_config()
		var host = str(mcp_config.get("bind_address", "127.0.0.1"))
		var port = int(mcp_config.get("port", 8765))
		var transport = "ws"
		if mcp_server.has_method("get_transport"):
			transport = str(mcp_server.get_transport())
		lines.append("")
		if transport == "none":
			lines.append("MCP: disabled")
		else:
			var scheme = "tcp" if transport == "tcp" else "ws"
			lines.append("MCP (%s): %s://%s:%d" % [transport, scheme, host, port])

	help_label.text = "\n".join(lines)
	var line_height = 11.0
	var height = max(60.0, line_height * lines.size() + 4.0)
	help_label.size = Vector2(PANEL_WIDTH - 40, height)
	if rows_scroll and panel:
		var content_top = help_label.position.y + help_label.size.y + 8
		rows_scroll.position = Vector2(panel.position.x + 20, content_top)
		rows_scroll.size = Vector2(PANEL_WIDTH - 40, PANEL_HEIGHT - (content_top - panel.position.y) - FOOTER_HEIGHT)

func _get_unix_home() -> String:
	var home_dir = OS.get_environment("HOME")
	if home_dir.is_empty():
		return "~"
	return home_dir

func _get_windows_home() -> String:
	var home_dir = OS.get_environment("USERPROFILE")
	if home_dir.is_empty():
		return "C:\\Users\\you"
	return home_dir

func _get_default_path_for_harness(harness_id: String) -> String:
	var os_name = OS.get_name().to_lower()
	var is_windows = os_name == "windows"
	if harness_id == "claude":
		var path = _get_windows_home() + "\\.claude\\projects" if is_windows else _get_unix_home() + "/.claude/projects"
		return path
	if harness_id == "codex":
		var codex_home = OS.get_environment("CODEX_HOME")
		if not codex_home.is_empty():
			return codex_home + "/sessions"
		var path = _get_windows_home() + "\\.codex\\sessions" if is_windows else _get_unix_home() + "/.codex/sessions"
		return path
	if harness_id == "clawdbot":
		var path = _get_windows_home() + "\\.clawdbot\\agents" if is_windows else _get_unix_home() + "/.clawdbot/agents"
		return path
	if harness_id == "opencode":
		var path = _get_windows_home() + "\\.local\\share\\opencode\\log" if is_windows else _get_unix_home() + "/.local/share/opencode/log"
		return _path_if_exists(path)
	if harness_id == "gemini":
		var path = _get_windows_home() + "\\gemini-telemetry.jsonl" if is_windows else _get_unix_home() + "/gemini-telemetry.jsonl"
		return _path_if_exists(path)
	return ""

func _path_if_exists(path: String) -> String:
	if path.is_empty():
		return ""
	var probe = path.replace("\\", "/")
	if FileAccess.file_exists(probe) or DirAccess.open(probe) != null:
		return path
	return ""
