class_name OfficeConstants

# =============================================================================
# DEBUG FLAGS
# =============================================================================

const DEBUG_EVENTS: bool = false      # Log all transcript events
const DEBUG_TOOL_TRACKING: bool = false  # Log tool tracking to profiles
const DEBUG_AGENT_LOOKUP: bool = false   # Log agent session lookups
const DEBUG_INTERACTION_POINTS: bool = false  # Show standing positions at furniture

# =============================================================================
# LAYOUT - Office Dimensions and Positions
# =============================================================================

# Screen/window bounds
const SCREEN_WIDTH: float = 1280.0
const SCREEN_HEIGHT: float = 720.0

# Floor walkable area (where agents can move)
const FLOOR_MIN_X: float = 10.0
const FLOOR_MAX_X: float = 1270.0
const FLOOR_MIN_Y: float = 85.0   # Below back wall seam
const FLOOR_MAX_Y: float = 630.0  # Just before bottom wall, door corridor extends beyond

# Wall positions
const BACK_WALL_HEIGHT: float = 76.0
const BACK_WALL_SEAM_Y: float = 68.0
const BOTTOM_WALL_Y: float = 632.0
const BOTTOM_WALL_HEIGHT: float = 88.0

# =============================================================================
# PATHFINDING - Desk Layout and Navigation
# =============================================================================

# Desk row Y positions (center of desk) - 4 rows with tighter spacing (grid-aligned)
const ROW1_DESK_Y: float = 135.0   # Cell row 2: 2*20+95
const ROW2_DESK_Y: float = 235.0   # Cell row 7: 7*20+95
const ROW3_DESK_Y: float = 335.0   # Cell row 12: 12*20+95
const ROW4_DESK_Y: float = 435.0   # Cell row 17: 17*20+95

# Pathfinding zones - boundaries for each row (grid-aligned)
const ROW1_TOP: float = 95.0        # Above row 1 desks
const ROW1_BOTTOM: float = 195.0    # Below row 1 work positions
const ROW2_TOP: float = 215.0       # Above row 2 desks
const ROW2_BOTTOM: float = 295.0    # Below row 2 work positions
const ROW3_TOP: float = 315.0       # Above row 3 desks
const ROW3_BOTTOM: float = 395.0    # Below row 3 work positions
const ROW4_TOP: float = 415.0       # Above row 4 desks
const ROW4_BOTTOM: float = 495.0    # Below row 4 work positions
const MAIN_AISLE_Y: float = 515.0   # Main horizontal aisle

# Vertical corridors between desk columns (X positions)
const CORRIDORS_X: Array[float] = [130.0, 295.0, 445.0, 595.0, 740.0]

# Desk X positions (grid-aligned: n*20+10)
const DESK_POSITIONS_X: Array[float] = [230.0, 390.0, 530.0, 690.0]

# =============================================================================
# SPAWN POINTS - Entry/Exit Locations
# =============================================================================

const DOOR_POSITION: Vector2 = Vector2(640, 615)  # Exit point on floor in front of visual door
const SPAWN_POINT: Vector2 = Vector2(640, 615)   # Spawn at same location as exit

# =============================================================================
# FURNITURE - Default Positions
# =============================================================================

# Grid-aligned furniture positions (X: n*20+10, Y: n*20+95)
const WATER_COOLER_POSITION: Vector2 = Vector2(50, 215)   # X=cell 2, Y=cell 6
const PLANT_POSITION: Vector2 = Vector2(50, 415)          # X=cell 2, Y=cell 16
const FILING_CABINET_POSITION: Vector2 = Vector2(50, 555) # X=cell 2, Y=cell 23
const SHREDDER_POSITION: Vector2 = Vector2(1210, 535)     # X=cell 60, Y=cell 22
const TASKBOARD_POSITION: Vector2 = Vector2(920, 20)      # Top-right corner
const CAT_BED_POSITION: Vector2 = Vector2(210, 575)       # X=cell 10, Y=cell 24

# Meeting table for overflow agents (right side of office)
const MEETING_TABLE_POSITION: Vector2 = Vector2(890, 235)  # Upper-right area
const MEETING_TABLE_SIZE: Vector2 = Vector2(120, 60)       # Rectangular conference table
const MEETING_TABLE_OBSTACLE: Vector2 = Vector2(130, 70)   # Slightly larger for pathfinding

# Meeting table standing positions (relative offsets from table center)
const MEETING_SPOT_OFFSETS: Array[Vector2] = [
	Vector2(-60, -30),   # Left-top
	Vector2(-60, 30),    # Left-bottom
	Vector2(60, -30),    # Right-top
	Vector2(60, 30),     # Right-bottom
	Vector2(-20, -60),   # Top-left
	Vector2(20, -60),    # Top-right
	Vector2(-20, 60),    # Bottom-left
	Vector2(20, 60),     # Bottom-right
]

# =============================================================================
# INTERACTION POINTS - Standing positions relative to furniture center
# =============================================================================
# Agents reserve these spots when socializing at furniture

# Water cooler - 4 positions (both sides)
const WATER_COOLER_POINTS: Array[Vector2] = [
	Vector2(-40, 0),    # Left
	Vector2(40, 0),     # Right
	Vector2(0, 50),     # Front
	Vector2(0, -40),    # Back
]

# Plant - 4 positions (all sides)
const PLANT_POINTS: Array[Vector2] = [
	Vector2(-40, 0),    # Left
	Vector2(40, 0),     # Right
	Vector2(0, 40),     # Front
	Vector2(0, -35),    # Back
]

# Filing cabinet - 4 positions (both sides)
const FILING_CABINET_POINTS: Array[Vector2] = [
	Vector2(-50, 0),    # Left
	Vector2(50, 0),     # Right
	Vector2(0, 50),     # Front
	Vector2(0, -40),    # Back
]

# Shredder - 4 positions (both sides)
const SHREDDER_POINTS: Array[Vector2] = [
	Vector2(-50, 0),    # Left
	Vector2(50, 0),     # Right
	Vector2(0, 45),     # Front
	Vector2(0, -35),    # Back
]

# Taskboard - 3 positions (stand below board to view)
# Board is 170x130 pixels, so center is at (85, 65) from node position
# Standing positions are below the board + easel legs (about 200px down)
const TASKBOARD_POINTS: Array[Vector2] = [
	Vector2(25, 200),   # Left viewer (centered at board center - 60)
	Vector2(85, 200),   # Center viewer (centered at board center)
	Vector2(145, 200),  # Right viewer (centered at board center + 60)
]

# Taskboard dimensions for dragging
const TASKBOARD_SIZE: Vector2 = Vector2(170, 130)
const TASKBOARD_OBSTACLE: Vector2 = Vector2(170, 130)  # Full board blocks navigation

# Cat bed dimensions (floor item)
const CAT_BED_SIZE: Vector2 = Vector2(60, 36)
const CAT_BED_OBSTACLE: Vector2 = Vector2(60, 36)

# Wall decorations (between windows and title sign)
const ACHIEVEMENT_BOARD_POSITION: Vector2 = Vector2(50, 32)  # Far left on wall
const WALL_CLOCK_POSITION: Vector2 = Vector2(1020, 32)       # Between windows at 900 and 1140
const VIP_PHOTO_POSITION: Vector2 = Vector2(510, 32)         # Left of title sign
const ROSTER_CLIPBOARD_POSITION: Vector2 = Vector2(770, 32)  # Right of title sign

# =============================================================================
# Z-INDEX - Layer Ordering (Godot: lower = behind, higher = in front)
# =============================================================================

# Background layers (negative = behind the action)
const Z_FLOOR: int = -100
const Z_FLOOR_DETAIL: int = -99
const Z_SKY: int = -40            # Sky backdrop (behind wall, visible through windows)
const Z_CELESTIAL: int = -39      # Sun/moon (just above sky)
const Z_CLOUDS: int = -38         # Moving clouds (behind wall)
const Z_FOLIAGE: int = -37        # Trees/bushes (behind wall)
const Z_WALL: int = -30           # Back wall with window holes
const Z_WALL_SEAM: int = -20      # Dark depth borders
const Z_WINDOW_FRAME: int = -10   # Window frames around holes
const Z_BOTTOM_WALL: int = -5     # Bottom boundary wall

# Floor level (0 = base, Y-position for dynamic sorting)
const Z_DOOR: int = 0
const Z_FURNITURE: int = 0        # Base for floor furniture (uses Y-sorting)
const Z_CAT: int = 0              # Cat uses Y-sorting like agents
const Z_AGENT: int = 0            # Agents use position.y as z_index (range ~85-625)

# Wall-mounted items (above all floor items, max Y is 625)
const Z_WALL_DECORATION: int = 700
const Z_TASKBOARD: int = 700      # Wall-mounted, always in front of agents
const Z_TASKBOARD_LEGS: int = 150 # Easel legs below agents (who stand at Y ~232)

# Overlays and UI
const Z_AMBIENT_OVERLAY: int = 800  # Day/night lighting overlay
const Z_UI: int = 900               # UI elements (popups, overlays)
const Z_UI_TOOLTIP: int = 950
const Z_UI_POPUP_LAYER: int = 1000  # CanvasLayer for modal popups

# =============================================================================
# TIMING - Durations and Intervals (in seconds)
# =============================================================================

const MIN_WORK_TIME: float = 3.0       # Minimum time agent shows working
const AGENT_SPAWN_FADE_TIME: float = 0.5
const AGENT_EXIT_FADE_TIME: float = 0.5
const SOCIALIZE_TIME_MIN: float = 2.0
const SOCIALIZE_TIME_MAX: float = 5.0
const FIDGET_TIME_MIN: float = 3.0
const FIDGET_TIME_MAX: float = 8.0
const FIDGET_DURATION: float = 1.5
const NEXT_FIDGET_MIN: float = 5.0
const NEXT_FIDGET_MAX: float = 15.0
const TRANSCRIPT_POLL_INTERVAL: float = 0.5

# =============================================================================
# MOVEMENT - Speeds (in pixels per second)
# =============================================================================

const AGENT_WALK_SPEED: float = 180.0
const CAT_WALK_SPEED: float = 40.0
const CLOUD_SPEED_MIN: float = 3.0
const CLOUD_SPEED_MAX: float = 7.0

# =============================================================================
# DIMENSIONS - Object Sizes
# =============================================================================

# Desk
const DESK_WIDTH: float = 80.0
const DESK_DEPTH: float = 28.0

# Windows
const WINDOW_WIDTH: float = 80.0
const WINDOW_HEIGHT: float = 44.0
const WINDOW_FRAME_THICKNESS: float = 4.0

# Agent collision/click bounds
const AGENT_CLICK_WIDTH: float = 40.0
const AGENT_CLICK_HEIGHT: float = 85.0

# Obstacle sizes for pathfinding
const WATER_COOLER_OBSTACLE: Vector2 = Vector2(40, 60)
const PLANT_OBSTACLE: Vector2 = Vector2(40, 50)
const FILING_CABINET_OBSTACLE: Vector2 = Vector2(40, 80)
const SHREDDER_OBSTACLE: Vector2 = Vector2(30, 40)

# =============================================================================
# GRID NAVIGATION - A* Pathfinding Grid
# =============================================================================

const CELL_SIZE: int = 20
const GRID_WIDTH: int = 64   # 1280 / 20
const GRID_HEIGHT: int = 28  # (625 - 85) / 20 ≈ 27, round to 28
const GRID_ORIGIN: Vector2 = Vector2(0.0, 85.0)  # Top-left of walkable area

# Work position offset from desk (where agent stands)
const WORK_POSITION_OFFSET: float = 55.0  # Pixels in front of desk center

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Snap a world position to the nearest grid cell center
static func snap_to_grid(pos: Vector2) -> Vector2:
	var gx = round((pos.x - GRID_ORIGIN.x) / CELL_SIZE)
	var gy = round((pos.y - GRID_ORIGIN.y) / CELL_SIZE)
	return Vector2(
		gx * CELL_SIZE + GRID_ORIGIN.x + CELL_SIZE / 2.0,
		gy * CELL_SIZE + GRID_ORIGIN.y + CELL_SIZE / 2.0
	)
