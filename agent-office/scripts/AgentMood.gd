extends RefCounted
class_name AgentMood

# Mood tracking and idle fidget animations for agents

enum Mood { CONTENT, TIRED, FRUSTRATED, IRATE }

# Mood thresholds (in seconds)
const MOOD_TIRED_THRESHOLD: float = 1800.0      # 30 minutes
const MOOD_FRUSTRATED_THRESHOLD: float = 3600.0  # 1 hour
const MOOD_IRATE_THRESHOLD: float = 7200.0       # 2 hours

var agent: Node2D
var current_mood: Mood = Mood.CONTENT
var time_on_floor: float = 0.0
var mood_indicator: Label = null

# Fidget state
var fidget_timer: float = 0.0
var next_fidget_time: float = 0.0
var current_fidget: String = ""
var fidget_progress: float = 0.0
var base_head_y: float = -35
var base_body_y: float = -15

func _init(agent_ref: Node2D) -> void:
	agent = agent_ref
	next_fidget_time = randf_range(OfficeConstants.FIDGET_TIME_MIN, OfficeConstants.FIDGET_TIME_MAX)

func update_time(delta: float) -> void:
	time_on_floor += delta

func update_mood() -> Mood:
	var old_mood = current_mood
	if time_on_floor >= MOOD_IRATE_THRESHOLD:
		current_mood = Mood.IRATE
	elif time_on_floor >= MOOD_FRUSTRATED_THRESHOLD:
		current_mood = Mood.FRUSTRATED
	elif time_on_floor >= MOOD_TIRED_THRESHOLD:
		current_mood = Mood.TIRED
	else:
		current_mood = Mood.CONTENT

	if old_mood != current_mood:
		_update_mood_indicator()

	return current_mood

func _update_mood_indicator() -> void:
	if not mood_indicator:
		mood_indicator = Label.new()
		mood_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mood_indicator.position = Vector2(-10, -70)
		mood_indicator.size = Vector2(20, 16)
		mood_indicator.add_theme_font_size_override("font_size", 12)
		agent.add_child(mood_indicator)

	match current_mood:
		Mood.CONTENT:
			mood_indicator.text = ""
			mood_indicator.visible = false
		Mood.TIRED:
			mood_indicator.text = "~"
			mood_indicator.add_theme_color_override("font_color", OfficePalette.GRUVBOX_YELLOW)
			mood_indicator.visible = true
		Mood.FRUSTRATED:
			mood_indicator.text = "!"
			mood_indicator.add_theme_color_override("font_color", OfficePalette.GRUVBOX_ORANGE)
			mood_indicator.visible = true
		Mood.IRATE:
			mood_indicator.text = "!!"
			mood_indicator.add_theme_color_override("font_color", OfficePalette.GRUVBOX_RED)
			mood_indicator.visible = true

func get_mood_text() -> String:
	match current_mood:
		Mood.TIRED:
			return "Tired"
		Mood.FRUSTRATED:
			return "Frustrated"
		Mood.IRATE:
			return "IRATE"
		_:
			return ""

func get_floor_time_text() -> String:
	var hours = int(time_on_floor / 3600)
	var minutes = int(fmod(time_on_floor, 3600) / 60)
	if hours > 0:
		return "%dh %dm on floor" % [hours, minutes]
	elif minutes > 0:
		return "%dm on floor" % minutes
	return ""

func start_random_fidget() -> void:
	var fidgets = ["head_scratch", "stretch", "look_around", "lean_back", "sip_drink", "adjust_posture"]
	current_fidget = fidgets[randi() % fidgets.size()]
	fidget_progress = 0.0
	next_fidget_time = randf_range(OfficeConstants.NEXT_FIDGET_MIN, OfficeConstants.NEXT_FIDGET_MAX)

func process_fidget(delta: float, visuals) -> void:
	if current_fidget == "":
		return

	fidget_progress += delta
	var fidget_duration = OfficeConstants.FIDGET_DURATION
	var t = fidget_progress / fidget_duration

	match current_fidget:
		"head_scratch":
			if visuals.head:
				var tilt = sin(t * PI) * 4
				visuals.head.position.x = -9 + tilt
				visuals.head.rotation = sin(t * PI) * 0.1

		"stretch":
			if visuals.body:
				var lean = sin(t * PI) * 3
				visuals.body.position.y = base_body_y - lean
			if visuals.head:
				var head_tilt = sin(t * PI) * 4
				visuals.head.position.y = base_head_y - head_tilt
				visuals.head.rotation = sin(t * PI) * -0.15

		"look_around":
			if visuals.head:
				if t < 0.33:
					visuals.head.position.x = -9 + (t / 0.33) * 3
				elif t < 0.66:
					visuals.head.position.x = -9 + 3 - ((t - 0.33) / 0.33) * 6
				else:
					visuals.head.position.x = -9 - 3 + ((t - 0.66) / 0.34) * 3

		"lean_back":
			if visuals.body:
				visuals.body.position.y = base_body_y - sin(t * PI) * 2
			if visuals.head:
				visuals.head.position.y = base_head_y - sin(t * PI) * 3

		"sip_drink":
			if visuals.head:
				var tilt_back = sin(t * PI) * 5
				visuals.head.position.y = base_head_y - tilt_back * 0.5
				visuals.head.rotation = sin(t * PI) * -0.2

		"adjust_posture":
			if visuals.body:
				if t < 0.3:
					visuals.body.position.y = base_body_y + (t / 0.3) * 2
				else:
					visuals.body.position.y = base_body_y + 2 - ((t - 0.3) / 0.7) * 2

	if fidget_progress >= fidget_duration:
		end_fidget(visuals)

func end_fidget(visuals) -> void:
	current_fidget = ""
	fidget_progress = 0.0
	if visuals.head:
		visuals.head.position = Vector2(-9, base_head_y)
		visuals.head.rotation = 0
	if visuals.body:
		visuals.body.position.y = base_body_y

func is_fidgeting() -> bool:
	return current_fidget != ""

func update_fidget_timer(delta: float) -> bool:
	fidget_timer += delta
	if fidget_timer >= next_fidget_time:
		fidget_timer = 0.0
		return true
	return false
