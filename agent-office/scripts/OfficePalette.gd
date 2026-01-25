class_name OfficePalette

# =============================================================================
# GRUVBOX COLOR PALETTE
# Based on https://github.com/morhetz/gruvbox
# =============================================================================

# --- Gruvbox Dark Backgrounds ---
const GRUVBOX_BG_HARD = Color(0.114, 0.118, 0.106)      # #1d2021
const GRUVBOX_BG = Color(0.157, 0.157, 0.157)           # #282828
const GRUVBOX_BG_SOFT = Color(0.196, 0.188, 0.184)      # #32302f
const GRUVBOX_BG1 = Color(0.235, 0.220, 0.212)          # #3c3836
const GRUVBOX_BG2 = Color(0.314, 0.286, 0.271)          # #504945
const GRUVBOX_BG3 = Color(0.400, 0.361, 0.329)          # #665c54
const GRUVBOX_BG4 = Color(0.486, 0.435, 0.392)          # #7c6f64

# --- Gruvbox Light Backgrounds ---
const GRUVBOX_LIGHT_HARD = Color(0.976, 0.961, 0.890)   # #f9f5d7
const GRUVBOX_LIGHT = Color(0.984, 0.945, 0.780)        # #fbf1c7
const GRUVBOX_LIGHT_SOFT = Color(0.949, 0.914, 0.773)   # #f2e5c6
const GRUVBOX_LIGHT1 = Color(0.922, 0.859, 0.698)       # #ebdbb2
const GRUVBOX_LIGHT2 = Color(0.835, 0.769, 0.631)       # #d5c4a1
const GRUVBOX_LIGHT3 = Color(0.741, 0.682, 0.576)       # #bdae93
const GRUVBOX_LIGHT4 = Color(0.659, 0.600, 0.518)       # #a89984

# --- Gruvbox Accent Colors (Normal) ---
const GRUVBOX_RED = Color(0.800, 0.141, 0.114)          # #cc241d
const GRUVBOX_GREEN = Color(0.596, 0.592, 0.102)        # #98971a
const GRUVBOX_YELLOW = Color(0.843, 0.600, 0.129)       # #d79921
const GRUVBOX_BLUE = Color(0.271, 0.522, 0.533)         # #458588
const GRUVBOX_PURPLE = Color(0.694, 0.384, 0.525)       # #b16286
const GRUVBOX_AQUA = Color(0.408, 0.616, 0.416)         # #689d6a
const GRUVBOX_ORANGE = Color(0.839, 0.365, 0.055)       # #d65d0e
const GRUVBOX_GRAY = Color(0.573, 0.514, 0.455)         # #928374

# --- Gruvbox Accent Colors (Bright) ---
const GRUVBOX_RED_BRIGHT = Color(0.984, 0.286, 0.204)   # #fb4934
const GRUVBOX_GREEN_BRIGHT = Color(0.722, 0.733, 0.149) # #b8bb26
const GRUVBOX_YELLOW_BRIGHT = Color(0.980, 0.741, 0.184) # #fabd2f
const GRUVBOX_BLUE_BRIGHT = Color(0.514, 0.647, 0.596)  # #83a598
const GRUVBOX_PURPLE_BRIGHT = Color(0.827, 0.525, 0.608) # #d3869b
const GRUVBOX_AQUA_BRIGHT = Color(0.557, 0.753, 0.486)  # #8ec07c
const GRUVBOX_ORANGE_BRIGHT = Color(0.996, 0.502, 0.098) # #fe8019

# --- Gruvbox Faded Accent Colors ---
const GRUVBOX_RED_FADED = Color(0.616, 0.176, 0.157)    # #9d0006
const GRUVBOX_GREEN_FADED = Color(0.478, 0.478, 0.031)  # #79740e
const GRUVBOX_YELLOW_FADED = Color(0.710, 0.482, 0.082) # #b57614
const GRUVBOX_BLUE_FADED = Color(0.043, 0.408, 0.420)   # #076678
const GRUVBOX_PURPLE_FADED = Color(0.533, 0.255, 0.400) # #8f3f71
const GRUVBOX_AQUA_FADED = Color(0.259, 0.494, 0.314)   # #427b58
const GRUVBOX_ORANGE_FADED = Color(0.686, 0.247, 0.016) # #af3a03

# =============================================================================
# ENVIRONMENT - Walls, Floor, Structural Elements
# =============================================================================

# Floor (warm gruvbox tan/brown)
const FLOOR_CARPET = GRUVBOX_BG3
const FLOOR_LINE_LIGHT = GRUVBOX_BG4
const FLOOR_LINE_DARK = GRUVBOX_BG2

# Walls (gruvbox cream/light)
const WALL_BEIGE = GRUVBOX_LIGHT1
const WALL_SEAM_DARK = GRUVBOX_BG

# Shadows (use with alpha)
const SHADOW = Color(0.157, 0.157, 0.157, 0.15)
const SHADOW_MEDIUM = Color(0.157, 0.157, 0.157, 0.25)

# =============================================================================
# FURNITURE - Wood and Metal Tones
# =============================================================================

# Wood (gruvbox browns/oranges)
const WOOD_FRAME = GRUVBOX_BG2
const WOOD_DOOR = Color(0.45, 0.35, 0.25)  # Warm brown
const WOOD_DOOR_DARK = GRUVBOX_BG2
const WOOD_DOOR_LIGHT = GRUVBOX_BG4

# Desk (gruvbox light tones)
const DESK_SURFACE = GRUVBOX_LIGHT2
const DESK_EDGE = GRUVBOX_LIGHT4

# Meeting Table (darker gruvbox)
const MEETING_TABLE_SURFACE = GRUVBOX_BG2
const MEETING_TABLE_EDGE = GRUVBOX_BG1
const MEETING_TABLE_LEG = GRUVBOX_BG

# Metal (gruvbox grays - lighter for visibility against floor)
const METAL_GRAY = GRUVBOX_LIGHT4
const METAL_GRAY_LIGHT = GRUVBOX_LIGHT3
const METAL_GRAY_DARK = GRUVBOX_GRAY
const METAL_HANDLE = GRUVBOX_BG4

# =============================================================================
# OFFICE EQUIPMENT - Computers, Shredder
# =============================================================================

# Monitor (dark gruvbox)
const MONITOR_FRAME = GRUVBOX_BG
const MONITOR_STAND = GRUVBOX_BG1
const MONITOR_SCREEN_OFF = GRUVBOX_BG_HARD
const MONITOR_SCREEN_ON = Color(0.15, 0.20, 0.12)  # Gruvbox-tinted green
const MONITOR_SCREEN_GLOW = Color(0.286, 0.431, 0.291)  # GRUVBOX_AQUA darkened 0.3
const MONITOR_SCREEN_WAITING = Color(0.25, 0.08, 0.06)  # Gruvbox-tinted red (waiting for input)
const MONITOR_SCREEN_WAITING_GLOW = Color(0.56, 0.18, 0.14)  # GRUVBOX_RED_BRIGHT darkened

# Status indicators (gruvbox accents)
const STATUS_LED_RED = GRUVBOX_RED
const STATUS_LED_GREEN = GRUVBOX_GREEN
const STATUS_LED_GREEN_BRIGHT = GRUVBOX_GREEN_BRIGHT

# Keyboard/mouse
const KEYBOARD_DARK = GRUVBOX_BG1
const KEYBOARD_KEYS = GRUVBOX_BG2
const MOUSE_HIGHLIGHT = GRUVBOX_BG3

# Shredder (lighter for visibility against floor)
const SHREDDER_BODY = GRUVBOX_GRAY
const SHREDDER_BODY_FRONT = GRUVBOX_LIGHT4
const SHREDDER_TOP = GRUVBOX_LIGHT3
const SHREDDER_BIN = GRUVBOX_LIGHT4
const SHREDDER_BIN_FRONT = GRUVBOX_LIGHT3
const SHREDDER_SLOT = GRUVBOX_BG_HARD
const SHREDDED_PAPER = GRUVBOX_LIGHT
const SHREDDED_PAPER_DARK = GRUVBOX_LIGHT1

# =============================================================================
# WATER COOLER
# =============================================================================

const COOLER_BASE = GRUVBOX_LIGHT3
const COOLER_BASE_DARK = GRUVBOX_LIGHT4
const COOLER_BODY = GRUVBOX_LIGHT1
const COOLER_BODY_FRONT = GRUVBOX_LIGHT2
const COOLER_BODY_TOP = GRUVBOX_LIGHT
const COOLER_BOTTLE = Color(GRUVBOX_BLUE_BRIGHT.r, GRUVBOX_BLUE_BRIGHT.g, GRUVBOX_BLUE_BRIGHT.b, 0.65)
const COOLER_BOTTLE_TOP = Color(GRUVBOX_BLUE_BRIGHT.r, GRUVBOX_BLUE_BRIGHT.g, GRUVBOX_BLUE_BRIGHT.b, 0.8)
const COOLER_TAP = GRUVBOX_GRAY

# =============================================================================
# PLANT
# =============================================================================

const POT_TERRACOTTA = GRUVBOX_ORANGE
const POT_TERRACOTTA_DARK = GRUVBOX_ORANGE_FADED
const POT_RIM = GRUVBOX_ORANGE_BRIGHT
const SOIL_DARK = GRUVBOX_BG2
const LEAF_GREEN = GRUVBOX_AQUA
const LEAF_GREEN_LIGHT = GRUVBOX_AQUA_BRIGHT
const LEAF_GREEN_DARK = GRUVBOX_AQUA_FADED

# =============================================================================
# WINDOWS - Sky and Outdoors
# =============================================================================

const SKY_BLUE = GRUVBOX_BLUE_BRIGHT
const CLOUD_WHITE = Color(GRUVBOX_LIGHT.r, GRUVBOX_LIGHT.g, GRUVBOX_LIGHT.b, 0.85)
const TREE_GREEN = GRUVBOX_AQUA_FADED
const SUN_YELLOW = Color(1.0, 0.9, 0.3)       # Bright yellow sun
const MOON_SILVER = Color(0.9, 0.9, 0.95)     # Pale silver moon

# Day/Night cycle sky colors
const SKY_DAWN = Color(0.95, 0.65, 0.55)       # Warm pink/orange sunrise
const SKY_MORNING = Color(0.65, 0.80, 0.90)   # Light blue morning
const SKY_DAY = GRUVBOX_BLUE_BRIGHT           # Bright day blue
const SKY_AFTERNOON = Color(0.55, 0.70, 0.85) # Slightly warmer afternoon
const SKY_DUSK = Color(0.90, 0.55, 0.45)      # Orange/pink sunset
const SKY_EVENING = Color(0.35, 0.30, 0.55)   # Purple twilight
const SKY_NIGHT = Color(0.12, 0.12, 0.22)     # Dark night blue

# Ambient lighting overlay (applied to whole office)
const AMBIENT_DAWN = Color(1.0, 0.9, 0.85, 0.1)    # Warm morning tint
const AMBIENT_DAY = Color(1.0, 1.0, 1.0, 0.0)      # No tint during day
const AMBIENT_DUSK = Color(1.0, 0.85, 0.75, 0.15)  # Warm evening tint
const AMBIENT_NIGHT = Color(0.7, 0.75, 0.9, 0.2)   # Cool blue night tint

# =============================================================================
# UI ELEMENTS
# =============================================================================

# Labels and tooltips
const UI_BG_DARK = Color(GRUVBOX_BG.r, GRUVBOX_BG.g, GRUVBOX_BG.b, 0.92)
const UI_BG_DARKER = Color(GRUVBOX_BG1.r, GRUVBOX_BG1.g, GRUVBOX_BG1.b, 0.92)
const UI_TEXT_LIGHT = GRUVBOX_LIGHT
const UI_TEXT_DARK = GRUVBOX_BG
const UI_TEXT_GRAY = GRUVBOX_GRAY
const UI_TEXT_MUTED = GRUVBOX_LIGHT4

# Tooltip (gruvbox light style)
const TOOLTIP_BG = Color(GRUVBOX_LIGHT.r, GRUVBOX_LIGHT.g, GRUVBOX_LIGHT.b, 0.98)
const TOOLTIP_BORDER = GRUVBOX_LIGHT4
const TOOLTIP_DIVIDER = GRUVBOX_LIGHT3

# Speech bubble
const SPEECH_BUBBLE = Color(GRUVBOX_LIGHT.r, GRUVBOX_LIGHT.g, GRUVBOX_LIGHT.b, 0.95)
const SPEECH_BUBBLE_BORDER = GRUVBOX_BG3

# Exit sign
const EXIT_SIGN_BG = GRUVBOX_RED
const EXIT_SIGN_TEXT = GRUVBOX_LIGHT

# Taskboard (lighter for visibility against floor)
const TASKBOARD_BG = GRUVBOX_LIGHT1
const TASKBOARD_BORDER = GRUVBOX_LIGHT4
const TASKBOARD_HEADER = GRUVBOX_GRAY
const TASKBOARD_FRAME = GRUVBOX_LIGHT3  # Aluminum frame
const TASKBOARD_HEADER_TEXT = GRUVBOX_BLUE_FADED  # Blue marker text
const TASKBOARD_EASEL_LEG = GRUVBOX_LIGHT4  # Lighter metal legs

# Status bar
const STATUS_BAR_BG = GRUVBOX_BG1

# Door/hallway
const DOOR_HALLWAY = GRUVBOX_BG_HARD  # Dark hallway beyond door

# =============================================================================
# AGENT COLORS - Clothing by Type (Gruvbox Accent Colors)
# =============================================================================

# Note: Avoid colors that match floor (BG3) or desk (LIGHT2) for visibility
const AGENT_SHIRT_WHITE = GRUVBOX_LIGHT_HARD  # Brighter white, distinct from desk
const AGENT_BLOUSE_PINK = Color(0.879, 0.668, 0.726)  # GRUVBOX_PURPLE_BRIGHT lightened 0.3
const AGENT_BLOUSE_BLUE = Color(0.611, 0.718, 0.677)  # GRUVBOX_BLUE_BRIGHT lightened 0.2
const AGENT_BLOUSE_LAVENDER = Color(0.75, 0.65, 0.80)  # Light purple, replaced cream
const AGENT_TROUSERS_DARK = GRUVBOX_BG  # Darker than floor (BG3) for contrast
const AGENT_SKIRT_DARK = GRUVBOX_BG1

# Hair colors (natural browns based on Gruvbox)
const HAIR_BROWN = Color(0.35, 0.25, 0.20)
const HAIR_BLACK = Color(0.15, 0.12, 0.10)
const HAIR_AUBURN = Color(0.587, 0.256, 0.039)  # GRUVBOX_ORANGE darkened 0.3
const HAIR_BLONDE = Color(0.874, 0.680, 0.303)  # GRUVBOX_YELLOW lightened 0.2
const HAIR_DARK_BROWN = Color(0.45, 0.30, 0.25)
const HAIR_VERY_DARK = Color(0.30, 0.20, 0.18)

# Skin tones
const SKIN_LIGHT = Color(0.87, 0.75, 0.65)
const SKIN_MEDIUM = Color(0.78, 0.62, 0.50)
const SKIN_TAN = Color(0.65, 0.50, 0.40)
const SKIN_DARK = Color(0.50, 0.38, 0.30)
const SKIN_VERY_LIGHT = Color(0.92, 0.82, 0.72)

# Centralized arrays - single source of truth for appearance UI
# Order must match AgentVisuals and profile index expectations
const HAIR_COLORS: Array[Color] = [HAIR_BROWN, HAIR_BLACK, HAIR_AUBURN, HAIR_BLONDE, HAIR_DARK_BROWN, HAIR_VERY_DARK]
const SKIN_TONES: Array[Color] = [SKIN_LIGHT, SKIN_MEDIUM, SKIN_TAN, SKIN_DARK, SKIN_VERY_LIGHT]

# Eyes
const EYE_COLOR = GRUVBOX_BG

# Agent type accent colors (tie/accent - using gruvbox palette)
# All agent types get colors assigned dynamically from a pool
const AGENT_TYPE_DEFAULT = GRUVBOX_GRAY                  # Gray - fallback if pool exhausted

# =============================================================================
# TOOL INDICATORS (Icons and Colors)
# =============================================================================

# Tool colors (Gruvbox Bright Accents)
const TOOL_BASH = GRUVBOX_GREEN_BRIGHT
const TOOL_READ = GRUVBOX_BLUE_BRIGHT
const TOOL_EDIT = GRUVBOX_YELLOW_BRIGHT
const TOOL_WRITE = GRUVBOX_ORANGE_BRIGHT
const TOOL_GLOB = GRUVBOX_PURPLE_BRIGHT
const TOOL_GREP = GRUVBOX_PURPLE_BRIGHT
const TOOL_WEB = GRUVBOX_AQUA_BRIGHT
const TOOL_TASK = GRUVBOX_ORANGE
const TOOL_DEFAULT = GRUVBOX_GRAY

# Tool icons (ASCII art displayed on monitors)
const TOOL_ICONS: Dictionary = {
	"Bash": "[>_]",
	"Read": "[R]",
	"Edit": "[E]",
	"Write": "[W]",
	"Glob": "[*]",
	"Grep": "[?]",
	"WebFetch": "[~]",
	"WebSearch": "[S]",
	"Task": "[T]",
	"NotebookEdit": "[N]",
	"MultiEdit": "[M]",
	"TodoWrite": "[✓]",
	"LSP": "[λ]",
	"MCPSearch": "[Ⓜ]",
	"Skill": "[⚡]",
	"AskUserQuestion": "[?!]",
}

# Tool color mapping (tool name -> color)
const TOOL_COLORS: Dictionary = {
	"Bash": TOOL_BASH,
	"Read": TOOL_READ,
	"Edit": TOOL_EDIT,
	"Write": TOOL_WRITE,
	"Glob": TOOL_GLOB,
	"Grep": TOOL_GREP,
	"WebFetch": TOOL_WEB,
	"WebSearch": TOOL_WEB,
	"Task": TOOL_TASK,
	"NotebookEdit": TOOL_WRITE,
	"MultiEdit": TOOL_EDIT,
	"TodoWrite": GRUVBOX_AQUA_BRIGHT,
	"LSP": GRUVBOX_PURPLE_BRIGHT,
	"MCPSearch": GRUVBOX_AQUA,
	"Skill": GRUVBOX_YELLOW,
	"AskUserQuestion": GRUVBOX_PURPLE_BRIGHT,
}

# =============================================================================
# CAT COLORS (Natural tones using gruvbox)
# =============================================================================

const CAT_ORANGE_TABBY = GRUVBOX_ORANGE
const CAT_BLACK = GRUVBOX_BG
const CAT_WHITE = GRUVBOX_LIGHT1
const CAT_GRAY = GRUVBOX_GRAY
const CAT_BROWN_TABBY = Color(0.45, 0.35, 0.28)  # Warm brown, distinct from floor (BG3)
const CAT_CREAM = Color(0.890, 0.720, 0.390)  # GRUVBOX_YELLOW lightened 0.3
const CAT_EYES_GREEN = GRUVBOX_AQUA
const CAT_INNER_EAR = Color(0.896, 0.715, 0.765)  # GRUVBOX_PURPLE_BRIGHT lightened 0.4
const CAT_SLEEPING_Z = Color(GRUVBOX_BLUE_BRIGHT.r, GRUVBOX_BLUE_BRIGHT.g, GRUVBOX_BLUE_BRIGHT.b, 0.8)

# =============================================================================
# DOCUMENT/FOLDER (Gruvbox warm tones)
# =============================================================================

const MANILA_FOLDER = Color(0.890, 0.720, 0.390)  # GRUVBOX_YELLOW lightened 0.3
const PAPER_WHITE = GRUVBOX_LIGHT

# =============================================================================
# PERSONAL ITEMS (Gruvbox accents)
# =============================================================================

# Mug color options
const MUG_WHITE = GRUVBOX_LIGHT1
const MUG_RED = GRUVBOX_RED_BRIGHT
const MUG_BLUE = GRUVBOX_BLUE_BRIGHT
const MUG_GREEN = GRUVBOX_AQUA_BRIGHT
const MUG_YELLOW = GRUVBOX_YELLOW_BRIGHT

# Pencil cup
const PENCIL_CUP = GRUVBOX_BG2
const PENCIL_YELLOW = GRUVBOX_YELLOW_BRIGHT
const PENCIL_BLUE = GRUVBOX_BLUE

# Water bottle
const WATER_BOTTLE = Color(GRUVBOX_BLUE_BRIGHT.r, GRUVBOX_BLUE_BRIGHT.g, GRUVBOX_BLUE_BRIGHT.b, 0.7)
const WATER_BOTTLE_CAP = GRUVBOX_BLUE

# Photo frame
const PHOTO_FRAME_WOOD = GRUVBOX_BG2
const PHOTO_SKY = Color(0.611, 0.718, 0.677)  # GRUVBOX_BLUE_BRIGHT lightened 0.2

# Figurine base
const FIGURINE_BASE = GRUVBOX_BG1

# =============================================================================
# RESULT BUBBLE (Success/Completion - Gruvbox green tint)
# =============================================================================

const RESULT_BUBBLE_BG = Color(GRUVBOX_AQUA_BRIGHT.r * 0.3 + GRUVBOX_LIGHT.r * 0.7,
                               GRUVBOX_AQUA_BRIGHT.g * 0.3 + GRUVBOX_LIGHT.g * 0.7,
                               GRUVBOX_AQUA_BRIGHT.b * 0.3 + GRUVBOX_LIGHT.b * 0.7, 0.95)
const RESULT_BUBBLE_BORDER = GRUVBOX_AQUA_FADED
const RESULT_BUBBLE_TEXT = Color(0.207, 0.395, 0.251)  # GRUVBOX_AQUA_FADED darkened 0.2

# =============================================================================
# MCP MANAGER (Office manager character)
# =============================================================================

const MCP_MANAGER_SHIRT = GRUVBOX_LIGHT1            # Professional light shirt
const MCP_MANAGER_TROUSERS = GRUVBOX_BG             # Dark trousers
const MCP_MANAGER_TIE = GRUVBOX_YELLOW_BRIGHT       # Gold/yellow tie (MCP branding)
const MCP_MANAGER_GLASSES_FRAME = GRUVBOX_BG        # Dark glasses frame
const MCP_MANAGER_GLASSES_LENS = Color(GRUVBOX_BLUE_BRIGHT.r, GRUVBOX_BLUE_BRIGHT.g, GRUVBOX_BLUE_BRIGHT.b, 0.3)  # Tinted lens
const MCP_MANAGER_CLIPBOARD = GRUVBOX_BG2           # Clipboard backing
const MCP_MANAGER_CLIPBOARD_CLIP = GRUVBOX_GRAY     # Metal clip
const MCP_MANAGER_PAPER = GRUVBOX_LIGHT             # Paper on clipboard
const MCP_MANAGER_PAPER_LINES = GRUVBOX_LIGHT4      # Writing lines
