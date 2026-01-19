extends RefCounted
class_name AgentBubbles

# =============================================================================
# AGENT BUBBLES
# =============================================================================
# Handles all speech bubble rendering and reactions for agents.
# Extracted from Agent.gd for better maintainability.

# Reference to parent agent
var agent: Node2D

# Bubble state
var reaction_bubble: Node2D = null
var reaction_timer: float = 0.0
var reaction_phrases: Array[String] = []
var spontaneous_bubble_timer: float = 0.0
var spontaneous_cooldown: float = 0.0

# Constants for spontaneous bubbles
const SPONTANEOUS_CHECK_INTERVAL: float = 12.0
const SPONTANEOUS_CHANCE: float = 0.25
const SPONTANEOUS_COOLDOWN: float = 30.0

# Phrase constants
const WORKING_PHRASES = [
	"Hmm...", "Interesting...", "Almost there!", "Let me think...",
	"Ah, I see!", "That's clever.", "One sec...", "Getting close!",
	"Just a bit more...", "Oh!", "Eureka!", "Compiling...",
	"Debugging...", "Reading docs...", "Found it!", "Nice!",
]

const SOCIALIZING_PHRASES = [
	"Great weather!", "Monday, huh?", "Coffee?", "Nice plant!",
	"Did you see that?", "How's it going?", "Break time!", "Ah, refreshing!",
	"Love this cooler.", "Quick break!", "Busy day!", "Same here.",
]

const MEETING_PHRASES = [
	"Good point.", "Let's sync up.", "Action items?", "Any blockers?",
	"Per my last...", "Circling back...", "Take it offline?", "Synergies!",
	"Moving forward...", "Aligned.", "Let's table that.", "Deep dive?",
	"Bandwidth?", "EOD works.", "Ping me later.", "Noted.",
	"That's a stretch.", "Can we scope it?", "Dependencies?", "Ship it!",
]

const SMALL_TALK_PHRASES = [
	"Hey!", "Oh, hi!", "Fancy meeting you!", "How's your day?",
	"Nice tie!", "Love your work!", "Quick chat?", "What's up?",
	"Busy day?", "Tell me about it!", "Ha, right?", "Same here!",
	"I know, right?", "Totally.", "For real!", "Big mood.",
	"Coffee later?", "Heading out soon?", "Almost done!", "Hang in there!",
]

const CAT_PHRASES = [
	"Aww, kitty!", "Hey there!", "Pspspsps!", "Good kitty!",
	"Nice cat!", "Who's fluffy?", "Office mascot!", "*pets*",
	"Hello, friend!", "Meow to you too!", "So soft!", "Cute!",
]

const TOOL_PHRASES_WORKING = [
	"Working on {tool}...", "This {tool}...", "Hmm, {tool}...",
	"Almost done with {tool}", "{tool} looks good", "Running {tool}...",
	"Checking {tool}...", "{tool} is tricky", "Nice {tool} result!",
]

const TOOL_PHRASES_MEETING = [
	"The {tool} shows...", "Per the {tool}...", "Based on {tool}...",
	"Running {tool} here", "{tool} says...", "Let me {tool} that",
	"My {tool} found...", "The {tool} output...", "Checking {tool}...",
]

const COMPLETION_PHRASES = [
	"Task complete! Time for a break.",
	"All done here!",
	"Wrapped that up nicely.",
	"Another one in the books.",
	"Mission accomplished!",
	"That should do it.",
	"Finished and filed!",
	"Work's done, heading out.",
	"Nailed it!",
	"Off to the next thing.",
	"That was a good one.",
	"Signed, sealed, delivered.",
	"Task conquered!",
	"And... done!",
	"Time to celebrate!",
]

# Mood-specific phrases (reference from agent's mood constants)
const TIRED_PHRASES = [
	"*yawn*", "Need coffee...", "Getting tired.", "Long day...",
	"*stretches*", "How much longer?", "Break soon?",
]
const FRUSTRATED_PHRASES = [
	"Ugh.", "Really?", "*sigh*", "Come on...", "Why...",
	"This again?", "Seriously?", "Not ideal.",
]
const IRATE_PHRASES = [
	"ENOUGH!", "I'M DONE.", "*grumble*", "UGH!",
	"GET ME OUT.", "THIS IS RIDICULOUS", "WHY.",
]

func _init(p_agent: Node2D) -> void:
	agent = p_agent

func generate_reaction_phrases() -> void:
	var all_phrases = [
		["Can't talk now, on deadline!", "Super busy here!", "In the zone!", "Working on it!"],
		["Hey there!", "Hi! Nice office, huh?", "Great to see you!", "How's it going?"],
		["Another meeting?", "Is it Friday yet?", "Need more coffee...", "Who moved my stapler?"],
		["Just reviewing the specs.", "Making progress!", "Almost done here.", "Back to work!"],
		["*yawn*", "Long day...", "Is it 5 yet?", "Coffee break soon?"],
		["Love this project!", "Crushing it today!", "Let's go!", "Productivity mode!"],
	]

	reaction_phrases.clear()
	all_phrases.shuffle()
	for i in range(randi_range(2, 3)):
		if i < all_phrases.size():
			var group = all_phrases[i]
			group.shuffle()
			for j in range(min(randi_range(2, 3), group.size())):
				reaction_phrases.append(group[j])

func get_tool_aware_phrase(tool_name: String, is_meeting: bool) -> String:
	var templates = TOOL_PHRASES_MEETING if is_meeting else TOOL_PHRASES_WORKING
	var template = templates[randi() % templates.size()]
	var short_tool = tool_name
	if short_tool.length() > 12:
		short_tool = short_tool.substr(0, 10) + ".."
	return template.replace("{tool}", short_tool)

func show_reaction() -> void:
	if reaction_timer > 0:
		return

	if reaction_phrases.is_empty():
		generate_reaction_phrases()

	var phrase = reaction_phrases[randi() % reaction_phrases.size()]
	_create_speech_bubble(phrase, 2.5, true)

func show_speech_bubble(phrase: String) -> void:
	if reaction_timer > 0:
		return
	_create_speech_bubble(phrase, 2.5, true)

func show_small_talk_bubble() -> void:
	var phrase = SMALL_TALK_PHRASES[randi() % SMALL_TALK_PHRASES.size()]
	show_speech_bubble(phrase)

func show_cat_reaction() -> void:
	var phrase = CAT_PHRASES[randi() % CAT_PHRASES.size()]
	show_speech_bubble(phrase)

func _create_speech_bubble(phrase: String, duration: float, large: bool = true) -> void:
	if reaction_bubble:
		reaction_bubble.queue_free()

	reaction_bubble = Node2D.new()
	reaction_bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	agent.add_child(reaction_bubble)

	var text_width = phrase.length() * (7 if large else 6) + (16 if large else 12)
	var bubble_size = Vector2(max(text_width, 60 if large else 50), 24 if large else 20)
	var y_offset = -95 if large else -90

	# Background
	var bubble_bg = ColorRect.new()
	bubble_bg.size = bubble_size
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, y_offset)
	bubble_bg.color = OfficePalette.SPEECH_BUBBLE
	reaction_bubble.add_child(bubble_bg)

	# Border
	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(4, 4)
	bubble_border.position = bubble_bg.position - Vector2(2, 2)
	bubble_border.color = OfficePalette.SPEECH_BUBBLE_BORDER
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	# Pointer
	var pointer = ColorRect.new()
	pointer.size = Vector2(8, 8)
	pointer.position = Vector2(-4, y_offset + 22)
	pointer.color = OfficePalette.SPEECH_BUBBLE
	reaction_bubble.add_child(pointer)

	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(10, 10)
	pointer_border.position = Vector2(-5, y_offset + 21)
	pointer_border.color = OfficePalette.SPEECH_BUBBLE_BORDER
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	# Text
	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(8, 3)
	text_label.add_theme_font_size_override("font_size", 11 if large else 10)
	text_label.add_theme_color_override("font_color", OfficePalette.UI_TEXT_DARK)
	reaction_bubble.add_child(text_label)

	reaction_timer = duration

func process_spontaneous_bubble(delta: float, is_socializing: bool, is_meeting: bool, current_mood: int, current_tool: String, office_manager: Node) -> void:
	if reaction_timer > 0:
		return

	if spontaneous_cooldown > 0:
		spontaneous_cooldown -= delta
		return

	spontaneous_bubble_timer += delta

	var check_interval = SPONTANEOUS_CHECK_INTERVAL
	var chance = SPONTANEOUS_CHANCE
	if is_meeting:
		check_interval = SPONTANEOUS_CHECK_INTERVAL * 0.5
		chance = SPONTANEOUS_CHANCE * 2.0
	elif is_socializing:
		check_interval = SPONTANEOUS_CHECK_INTERVAL * 0.6
		chance = SPONTANEOUS_CHANCE * 1.5

	if spontaneous_bubble_timer >= check_interval:
		spontaneous_bubble_timer = 0.0
		if randf() < chance:
			if _can_show_spontaneous_globally(office_manager):
				_show_spontaneous_reaction(is_socializing, is_meeting, current_mood, current_tool, office_manager)
				spontaneous_cooldown = SPONTANEOUS_COOLDOWN

func _can_show_spontaneous_globally(office_manager: Node) -> bool:
	if is_instance_valid(office_manager) and office_manager.has_method("can_show_spontaneous_bubble"):
		return office_manager.can_show_spontaneous_bubble()
	return true

func _show_spontaneous_reaction(is_socializing: bool, is_meeting: bool, current_mood: int, current_tool: String, office_manager: Node) -> void:
	var phrase = ""

	# Mood-based phrases
	var use_mood_phrase = false
	if current_mood == 3:  # IRATE
		use_mood_phrase = randf() < 0.7
	elif current_mood == 2:  # FRUSTRATED
		use_mood_phrase = randf() < 0.4
	elif current_mood == 1:  # TIRED
		use_mood_phrase = randf() < 0.25

	if use_mood_phrase:
		match current_mood:
			3:  # IRATE
				phrase = IRATE_PHRASES[randi() % IRATE_PHRASES.size()]
			2:  # FRUSTRATED
				phrase = FRUSTRATED_PHRASES[randi() % FRUSTRATED_PHRASES.size()]
			1:  # TIRED
				phrase = TIRED_PHRASES[randi() % TIRED_PHRASES.size()]
	elif current_tool and not is_socializing and randf() < 0.5:
		phrase = get_tool_aware_phrase(current_tool, is_meeting)
	else:
		var phrases = WORKING_PHRASES
		if is_meeting:
			phrases = MEETING_PHRASES
		elif is_socializing:
			phrases = SOCIALIZING_PHRASES
		phrase = phrases[randi() % phrases.size()]

	if is_instance_valid(office_manager) and office_manager.has_method("register_spontaneous_bubble"):
		office_manager.register_spontaneous_bubble(agent)

	_create_spontaneous_bubble(phrase)

func _create_spontaneous_bubble(phrase: String) -> void:
	if reaction_bubble:
		reaction_bubble.queue_free()

	reaction_bubble = Node2D.new()
	reaction_bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	agent.add_child(reaction_bubble)

	var text_width = phrase.length() * 6 + 12
	var bubble_bg = ColorRect.new()
	bubble_bg.size = Vector2(max(text_width, 50), 20)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -90)
	bubble_bg.color = Color(OfficePalette.GRUVBOX_LIGHT.r, OfficePalette.GRUVBOX_LIGHT.g, OfficePalette.GRUVBOX_LIGHT.b, 0.92)
	reaction_bubble.add_child(bubble_bg)

	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(2, 2)
	bubble_border.position = bubble_bg.position - Vector2(1, 1)
	bubble_border.color = OfficePalette.GRUVBOX_GRAY
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	var pointer = ColorRect.new()
	pointer.size = Vector2(6, 6)
	pointer.position = Vector2(-3, -71)
	pointer.color = Color(OfficePalette.GRUVBOX_LIGHT.r, OfficePalette.GRUVBOX_LIGHT.g, OfficePalette.GRUVBOX_LIGHT.b, 0.92)
	reaction_bubble.add_child(pointer)

	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(8, 8)
	pointer_border.position = Vector2(-4, -72)
	pointer_border.color = OfficePalette.GRUVBOX_GRAY
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = bubble_bg.position + Vector2(6, 2)
	text_label.add_theme_font_size_override("font_size", 10)
	text_label.add_theme_color_override("font_color", OfficePalette.GRUVBOX_BG2)
	reaction_bubble.add_child(text_label)

	reaction_timer = 1.8

func show_result_bubble(agent_id: String) -> void:
	var phrase_idx = hash(agent_id) % COMPLETION_PHRASES.size()
	var phrase = COMPLETION_PHRASES[phrase_idx]

	if reaction_bubble:
		reaction_bubble.queue_free()

	reaction_bubble = Node2D.new()
	reaction_bubble.z_index = OfficeConstants.Z_UI_TOOLTIP
	agent.add_child(reaction_bubble)

	var text_width = phrase.length() * 6 + 20
	var bubble_bg = ColorRect.new()
	bubble_bg.size = Vector2(min(max(text_width, 100), 400), 26)
	bubble_bg.position = Vector2(-bubble_bg.size.x / 2, -100)
	bubble_bg.color = OfficePalette.RESULT_BUBBLE_BG
	reaction_bubble.add_child(bubble_bg)

	var bubble_border = ColorRect.new()
	bubble_border.size = bubble_bg.size + Vector2(4, 4)
	bubble_border.position = bubble_bg.position - Vector2(2, 2)
	bubble_border.color = OfficePalette.RESULT_BUBBLE_BORDER
	reaction_bubble.add_child(bubble_border)
	bubble_border.z_index = -1

	var pointer = ColorRect.new()
	pointer.size = Vector2(8, 8)
	pointer.position = Vector2(-4, -76)
	pointer.color = OfficePalette.RESULT_BUBBLE_BG
	reaction_bubble.add_child(pointer)

	var pointer_border = ColorRect.new()
	pointer_border.size = Vector2(10, 10)
	pointer_border.position = Vector2(-5, -77)
	pointer_border.color = OfficePalette.RESULT_BUBBLE_BORDER
	pointer_border.z_index = -1
	reaction_bubble.add_child(pointer_border)

	var text_container = Control.new()
	text_container.position = bubble_bg.position
	text_container.size = bubble_bg.size
	text_container.clip_contents = true
	reaction_bubble.add_child(text_container)

	var text_label = Label.new()
	text_label.text = phrase
	text_label.position = Vector2(8, 4)
	text_label.size = Vector2(bubble_bg.size.x - 16, 20)
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", OfficePalette.RESULT_BUBBLE_TEXT)
	text_label.clip_text = true
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_container.add_child(text_label)

	reaction_timer = 3.0

func update_reaction_timer(delta: float) -> void:
	if reaction_timer > 0:
		reaction_timer -= delta
		if reaction_timer < 0.5 and reaction_bubble:
			reaction_bubble.modulate.a = reaction_timer / 0.5
		if reaction_timer <= 0:
			if reaction_bubble:
				reaction_bubble.queue_free()
				reaction_bubble = null

func clear_spontaneous_bubble() -> void:
	if reaction_bubble and reaction_timer > 0.5:
		reaction_timer = 0.3

func cleanup() -> void:
	if is_instance_valid(reaction_bubble):
		reaction_bubble.queue_free()
		reaction_bubble = null

func is_showing_bubble() -> bool:
	return reaction_timer > 0
