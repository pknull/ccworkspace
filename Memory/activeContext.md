---
version: "2.5"
lastUpdated: "2026-01-26 UTC"
lifecycle: "active"
stakeholder: "all"
changeTrigger: "Session save - Fixed orchestrator respawn and monitor cleanup bugs"
validatedBy: "user"
dependencies: ["communicationStyle.md"]
---

# activeContext

## Current Project Status

**Primary Focus**: Feature-complete office simulation - user considers project essentially done

**Active Work**:
- Weather system with rain/snow particles
- Audio system with typing, meow, achievement, shredder, and filing sounds
- Day/night cycle with real-time sky colors
- Agent mood system (tired/frustrated/irate)

**Recent Activities** (last 7 days):
- **2026-01-26 (Session 15)**: Fixed orchestrator respawn and monitor cleanup bugs:
  - **Bug report**: User noticed agents not appearing despite active Claude sessions elsewhere, plus orphan monitors (3 on, only 2 agents)
  - **Root cause 1 - Missing orchestrator respawn**: TranscriptWatcher only emits `session_start` when session first detected. If orchestrator leaves (idle timeout) while session still watched, it can't respawn when activity resumes.
  - **Root cause 2 - Monitor cleanup gap**: `force_complete()` in SPAWNING/WALKING_TO_DESK states skipped directly to LEAVING without releasing desk or turning off monitor
  - **Fixes implemented**:
    - `Agent.gd force_complete()` - Now releases desk and turns off monitor when bypassing early states
    - `Agent.gd _exit_tree()` - Explicitly turns off monitor as safety net before releasing desk
    - `TranscriptWatcher.gd` - New `session_activity` event emitted when new content detected on watched session
    - `OfficeManager.gd` - New `_handle_session_activity()` respawns missing orchestrators
  - **Verification**: After restart, asha-marketplace session (`orch_60dd8fe6`) appeared correctly alongside ccworkspace session

- **2026-01-25 (Session 14)**: Centralized SettingsRegistry system:
  - **Goal**: Create universal settings system where components register settings with metadata, MCP discovers dynamically
  - **Created**: `scripts/SettingsRegistry.gd` - Core registry with schema validation, persistence, change signals
  - **Modified**:
    - `project.godot` - Added SettingsRegistry to AutoLoad
    - `AudioManager.gd` - Registers 5 settings (typing/meow/achievement/office volumes, sounds_enabled)
    - `WeatherService.gd` - Registers 6 settings (auto_location, location_query, fahrenheit, cached coords)
    - `TranscriptWatcher.gd` - Registers 4 settings, added missing `get_harness_config()`, `set_harness_enabled()`, `set_harness_path()`, `save_config()`, `get_harness_summary()`
    - `McpServer.gd` - Registers 3 settings (enabled, port, bind_address), replaced manual tools
  - **New MCP Tools**:
    - `list_settings` - Returns schemas for all categories
    - `get_settings` - Returns current values (optional category filter)
    - `set_setting` - Sets any setting with validation
  - **Architecture**:
    - In-game UI → Component methods → SettingsRegistry → JSON persistence
    - MCP tools → SettingsRegistry → callback to components
    - Adding new settings: just add to component's schema array, MCP discovers automatically
  - **Bug fix**: Removed `class_name` from autoloaded SettingsRegistry (conflicts with autoload singleton)
  - **Code review**: Fixed null safety issues in all registry value reads

- **2026-01-24 (Session 13)**: Furniture grid preview system:
  - **Feature**: Added visual feedback during furniture dragging:
    - 7x7 grid overlay centered on item (subtle white cells)
    - Semi-transparent ghost preview at snap target position
    - Green/red color tint for valid/invalid placement
    - Original furniture hidden during drag (only ghost visible)
  - **Implementation**:
    - DraggableItem.gd: Added ghost_preview, grid_overlay, visual_center_offset
    - _create_ghost_preview() duplicates ColorRect children with 0.6 alpha
    - _create_grid_overlay() draws 7x7 grid using CELL_SIZE (20px)
    - _update_ghost_validity() tints with GRUVBOX_GREEN/RED
    - _cleanup_drag_visuals() restores visibility and frees preview nodes
  - **Bug fixes**:
    - Self-collision during drag: Synced item_name with furniture_id
    - Debug visualization broken: Changed to use navigation_grid.get_all_obstacle_ids()
    - Orphan collision boxes: Added conditional obstacle registration
    - Taskboard grid offset: Added visual_center_offset property
  - **Taskboard as floor object**:
    - User clarified taskboard is rolling whiteboard, not wall-mounted
    - Added TASKBOARD_OBSTACLE (150x30) for easel legs
    - Added TASKBOARD_OBSTACLE_OFFSET (85, 180) for proper collision registration
    - Legs now block pathfinding like desk monitors

- **2026-01-20 (Session 12)**: Desk drag bug during pause menu:
  - **Bug**: Adjusting volume sliders in pause menu caused desks to move
  - **Root cause**: `Desk.gd` used `_input()` for drag handling without popup check
    - `DraggableItem.gd` already had `is_any_popup_open()` guard
    - `Desk.gd` was missing this check (only checked `is_occupied`)
    - Control's `mouse_filter = MOUSE_FILTER_STOP` only blocks GUI event propagation
    - `_input()` receives events from main input pipeline before GUI processing
  - **Fix**:
    - Added `office_manager` reference to `Desk.gd`
    - Added popup check in `Desk._input()` before starting drag
    - Set reference in `OfficeManager._create_desks()`

- **2026-01-20 (Session 11)**: Distribution workflow planning:
  - User considers project ready for first release ("ask for coffee")
  - Discussed GitHub release access without repo access
  - Planned itch.io distribution workflow: code → GitHub Actions → Butler → itch.io
  - Workflow cost: $0 (free tiers cover indie use)
  - Added itch.io setup task to user's Todoist with full workflow steps
  - User will set up itch.io account and publishing workflow tonight

- **2026-01-20 (Session 10)**: Weather system, delivery sounds, bug fixes:
  - **WeatherSystem.gd**: Random weather (clear 50%, rain 35%, snow 15%)
    - CPUParticles2D for rain/snow effects
    - SubViewport clips particles to 76px sky region (doesn't fall on floor)
    - 5-15 minute random transitions with 3s fade
  - **Shredder/filing sounds**: Downloaded CC0 sounds from BigSoundBank
    - `shredder.wav` (torn paper), `filing.wav` (metal drawer)
    - Agent tracks `delivery_target` and plays appropriate sound
    - Added `play_shredder()` and `play_filing()` to AudioManager
  - **Fixed furniture drag through popups**:
    - Added `is_any_popup_open()` to OfficeManager
    - DraggableItem checks popup state before starting drag
  - **Fixed white tie bug**: Male agents had white ties after profile appearance applied
    - Cause: tie created as ColorRect without setting .color (defaults to white)
    - Fix: Set `tie.color = Agent.get_agent_color(agent.agent_type)` in both `_create_male_visuals` and `_create_male_visuals_persistent`
  - Stress tests passing (20 agents, 100 tool cycles)
  - User considers project feature-complete

- **2026-01-20 (Session 9)**: Floor boundary fix and cat stuck detection:
  - **xdotool screenshot capability**: Demonstrated ability to capture game window screenshots for visual verification during development
  - **Fixed agents walking on bottom wall**:
    - Reduced FLOOR_MAX_Y from 670 to 630 (agents stop at wall edge)
    - Moved DOOR_POSITION from Y=665 to Y=615 (exit point on floor in front of visual door)
    - Moved SPAWN_POINT from Y=620 to Y=615 (spawn at same location as exit)
  - **Fixed cat getting stuck** (long-range stuck detection):
    - Added LONG_STUCK_TIMEOUT (5s) and LONG_STUCK_DISTANCE (30px)
    - Cat now turns around and walks opposite direction instead of teleporting
    - Added `_find_opposite_direction_position()` helper function
  - **Stress tests passing**: All 3 stress tests pass with floor boundary fix
  - Verified agents properly exit without getting stuck on wall

- **2026-01-20 (Session 8)**: Smoke test enhancements and force completion fix:
  - **Extended smoke_test.py** from 243 to 832 lines with new test suites:
    - `--refactor` - Tests component extraction (AgentVisuals, AgentBubbles, AgentMood, AgentSocial)
    - `--interactions` - Multi-agent interaction tests (rapid spawns, social spots, reactions)
    - `--stress` - Rapid event stress testing (20 agents, 10 cycles)
    - `--edge` - Edge case handling (duplicate IDs, empty events, non-existent agents)
    - `--all` - Run complete test suite (22 tests total)
  - **Fixed multiple bugs discovered during testing**:
    - `reaction_timer` access error in OfficeManager.gd:916 (moved to bubbles component)
    - `pop_back()` not found on PackedStringArray in TCPServer.gd:80 (convert to Array)
    - Tour agent stuck at door - `door_position` defaulted to SPAWN_POINT instead of DOOR_POSITION
    - Door outside walkable area - increased FLOOR_MAX_Y from 625 to 670
    - `_pick_tour_target()` type mismatch - changed `Array[Vector2]` to plain `Array`
    - `furniture_tour_targets` type mismatch - changed `Array[Dictionary]` to plain `Array`
  - **Fixed stress test cleanup issue** - agents stuck with monitors off:
    - Added `pending_completion` indicator to agent tooltips for debugging
    - Added `bypass_min_time` parameter to `force_complete()` in Agent.gd
    - Added `force` flag support to `agent_complete` event in OfficeManager.gd
    - Updated all smoke_test.py cleanup completions to use `"force": True`
  - Replaced non-functional `tool_use` event with working `waiting_for_input` event

- **2026-01-19 (Session 7)**: Agent.gd refactor completed - 51% reduction:
  - **Extracted components**:
    - AgentVisuals.gd (691 lines) - visual node creation, appearance, tooltips
    - AgentBubbles.gd (395 lines) - speech bubbles, reactions, phrases
    - AgentMood.gd (173 lines) - mood tracking, fidget animations
    - AgentSocial.gd (58 lines) - social spot selection, cooldowns
    - PersonalItemFactory.gd (169 lines) - from previous session
  - **Result**: Agent.gd reduced from ~2880 to 1419 lines (51% reduction)
  - **Fixed CRITICAL bug**: Profile appearance not applying
    - Cause: `apply_profile_appearance()` called before `_ready()` when `visuals` was null
    - Fix: Added `_pending_profile` variable to defer application until visuals ready
  - **Fixed compilation errors during refactor**:
    - `tool_bg` not declared (missed changing to `visuals.tool_bg`)
    - `visuals.visuals.status_label` typos (18 occurrences from bad sed)
    - Class not found errors (Godot needed `--editor --headless` to rescan scripts)
  - **Cleaned dead code**: Removed unused `get_social_spots()` and `agent` var from AgentSocial.gd
  - **Smoke test passed**: 4/4 tests passing
  - Updated REFACTOR_PLAN.md with final status and lessons learned

- **2026-01-19 (Session 6)**: Comprehensive code review and refactor start:
  - Full code review of Agent.gd (2880 lines) and ProfilePopup.gd (660 lines)
  - **Fixed CRITICAL issues**:
    - Added `_exit_tree()` to Agent.gd for proper cleanup (interaction points, desk, chat references)
    - Fixed post-await validity checks with `is_instance_valid(status_label)`
  - **Fixed HIGH issues**:
    - Added `is_instance_valid(office_manager)` in 2 locations
    - Removed 8 debug print statements (replaced with `_log_debug_event()`)
    - Added null profile guard in ProfilePopup.gd `show_profile()`
    - Fixed division by zero in ProfilePopup.gd `_create_bar()`
    - Added `is_instance_valid()` for roster and badge_system
    - Added `get_viewport().set_input_as_handled()` for ESC key
  - **Fixed MEDIUM/LOW issues**:
    - Added bounds check in `_furniture_tour_arrived()`
    - Removed unused `shirt` variable and `stats_container`
  - **Refactor started**:
    - Created REFACTOR_PLAN.md documenting extraction strategy
    - Extracted PersonalItemFactory.gd (169 lines) - static utility for desk items
    - Agent.gd reduced from ~2880 to 2776 lines (~100 line reduction)
  - Remaining refactor: AgentVisuals (~400 lines), AgentBubbles (~350), AgentSocial (~200), AgentNavigation (~150), AgentMood (~80)

- **2026-01-18 (Session 5)**: Major feature additions and bug fixes:
  - Code review via `/local-review` identified issues across 19 files
  - Fixed bugs:
    - Unreachable hair rendering in ProfilePopup (moved from after return)
    - DraggableItem input handling (reverted `_unhandled_input` to `_input`)
    - Monitor staying on when agents leave (added desk release in `_start_leaving()`)
    - Added `is_instance_valid()` checks in Agent.gd
    - Centralized UI_POPUP_LAYER constant (replaced magic number 200)
  - New features implemented:
    - **Skill tooltips** in ProfilePopup badges
    - **Wall clock** with real-time hour/minute/second hands (WallClock.gd)
    - **Agent mood system**: Tired (30min), Frustrated (1hr), Irate (2hr) with mood-specific phrases
    - **AudioManager**: Typing sounds, meow sounds, achievement stapler sound
    - **Day/night cycle**: Real-time sky color transitions (dawn→day→dusk→night)
    - **New achievements**: Cat Petter/Cat Friend/Crazy Cat Office, Quick Task/Lightning Fast/Speed Demon
  - Downloaded CC0 audio files from BigSoundBank (typing.wav, meow.wav, stapler.wav)
  - Fixed Godot class_name loading issues (preload instead of global class_name for AudioManager/WallClock)
  - Modified agent "Quinn" appearance (female, light skin, brown hair)
  - Repositioned wall clock to x=1020 (between windows, above window masks)

- **2026-01-17 (Session 4)**: Gamification verification, codebase review:
  - Verified lifetime stats ARE persisting (AgentProfile JSON in user://stable/)
  - Diagnosed tool tracking delay - reduced SCAN_INTERVAL from 5s to 1s
  - Added debug flags to OfficeConstants (DEBUG_EVENTS, DEBUG_TOOL_TRACKING, DEBUG_AGENT_LOOKUP)
  - Centralized TOOL_ICONS and TOOL_COLORS in OfficePalette.gd (removed from Agent.gd)
  - Comprehensive codebase exploration identifying refactoring opportunities:
    - God Object issue: OfficeManager (1,226 lines), Agent (1,500+ lines)
    - String-based method dispatch should use signals
    - A* pathfinding could use priority queue
  - Health Score: 6.1/10 - functional but monolithic classes limit maintainability

- **2026-01-16 (Session 3)**: Z-index fix, smoke test, pathfinding improvements:
  - Fixed z-index for DraggableItem (water cooler, plant, cabinet, shredder, table)
    - Added `z_index = int(position.y)` in _ready() and _process()
  - Created `smoke_test.py`:
    - Basic tests: connection, agent_spawn, tool_use, agent_complete
    - `--tour` flag: furniture tour visiting all items from multiple sides
  - Added `furniture_tour` event and FURNITURE_TOUR state
  - Fixed orchestrator teleporting to water cooler (now walks with pathfinding)
  - Added path recalculation when target furniture moves mid-walk:
    - New `destination_furniture` tracking in Agent
    - `on_furniture_moved()` method recalculates path
  - Added graceful unreachable path handling:
    - NavigationGrid returns empty array (no direct-path fallback)
    - Agent `_handle_unreachable_destination()` - skips/leaves/idles

- **2026-01-16 (Session 2)**: Bug fixes and orchestrator lifecycle:
  - Fixed 6 visual/behavioral bugs:
    - Desk items accumulating (defensive clear_personal_items)
    - Head z-ordering (body=0, tie=1, head=2)
    - Cat/whiteboard drag limits expanded
    - Whiteboard legs added (metal easel)
    - Monitor timing (separated reservation from set_monitor_active)
  - Added /exit detection in TranscriptWatcher → orchestrators leave office
  - Added 10-minute idle timeout → orchestrators at water cooler leave
  - Removed female necklace/scarf (translated poorly)

- **2026-01-16 (Session 1)**: Added cute features via panel-driven development:
  - Tuned spontaneous bubble timing (12s interval, 25% chance)
  - Cat meow speech bubbles with 11 phrases
  - Compact tooltips fixing overflow
  - Random post-work socializing (cooler/plant/cabinet/exit)
  - Meeting table overflow for 8+ agents
  - Draggable meeting table
  - Tool-aware phrases for desk and meeting agents

## Critical Reference Information

### Agent States
```
SPAWNING -> WALKING_TO_DESK -> WORKING -> DELIVERING -> [SOCIALIZING] -> LEAVING -> COMPLETING
                                                    \-> EXIT directly (25% chance)
                            \-> MEETING (overflow)
                            \-> FURNITURE_TOUR (smoke test)
```

### Key Files
- `scripts/Agent.gd` - Agent behavior, states, phrases
- `scripts/OfficeManager.gd` - Central coordinator, desk/meeting assignment
- `scripts/OfficeVisualFactory.gd` - All visual elements
- `scripts/OfficePalette.gd` - Color constants
- `scripts/OfficeConstants.gd` - Layout positions

### TCP Protocol
Port 9999, JSON messages with `"event"` field:
- `agent_spawn` - New agent
- `tool_use` - Tool usage
- `agent_complete` - Work finished
- `furniture_tour` - Spawn agent to visit all furniture (smoke test)

## Next Steps

**Immediate**:
- [x] All features implemented (weather, audio, day/night, mood, achievements)
- [x] All bugs fixed (floor boundary, cat stuck, drag popups, tie color)
- [x] Agent.gd refactor complete (51% reduction)
- [x] Comprehensive smoke test suite (22 tests, 5 modes)
- [ ] **Set up itch.io publishing workflow** (user doing tonight)
  - Create itch.io account/project
  - Export Godot builds (Windows/Linux/macOS/Web)
  - Set up GitHub Action with Butler
  - Configure Butler credentials as secret
- [ ] First public release on itch.io

**Blocked**:
- None

**Deferred**:
- Extract AgentSpawner from OfficeManager (reduces monolith)
- EventBus pattern for decoupled communication
- A* priority queue optimization
- Agent-type accent for female agents (optional consistency)
- More furniture variety
- Further Agent.gd reduction would require StateMachine class (diminishing returns)

## Learnings

### TranscriptWatcher Behavior
The JSONL watcher seeks to file end on start, so it only sees NEW entries. Commands like /exit must be run AFTER the office starts watching to be detected.

### State Separation Pattern
Separating logical state (desk reservation) from visual state (monitor active) allows finer timing control. The monitor now turns on only when the agent arrives, not when they claim the desk.

### Z-Index Consistency
All moving objects (Agent, Desk, DraggableItem) need dynamic z_index based on Y position: `z_index = int(position.y)`. Objects lower on screen (higher Y) render in front. Missing this on DraggableItem caused agents to appear on top of furniture.

### Path Recalculation Pattern
When agents walk to movable targets, track destination furniture name alongside position. When furniture moves, check all agents heading there and recalculate their paths. Without this, agents walk to stale positions.

### Graceful Pathfinding Failure
Don't fall back to direct paths when A* fails - this causes agents to walk through walls. Instead return empty path and let agent handle gracefully (skip target, go idle, or leave).

### Session Scan Timing
TranscriptWatcher scans for new sessions at SCAN_INTERVAL. If too slow (5s), subagent sessions may be discovered after tool events have already happened, causing tool tracking to fail. Reduced to 1s.

### Centralized Constants Pattern
Tool definitions (icons, colors) scattered across files create maintenance burden. Centralize in OfficePalette.gd for single source of truth. Use debug flags in OfficeConstants.gd to gate verbose logging.

### Godot class_name Loading Order
When using `class_name` declarations, Godot may not register them before other scripts try to use them as type annotations. Solution: Use `preload()` for new scripts and remove type annotations (e.g., `var audio_manager = null` instead of `var audio_manager: AudioManager = null`).

### Window Mask Z-Index
Window cloud masks (to hide overflow) render on top of wall decorations. Wall-mounted items like clocks need z_index higher than Z_WINDOW_MASK (4) to be visible.

### _input vs _unhandled_input
Using `_unhandled_input` for drag operations caused furniture dragging to break - other nodes consumed the input first. Reverted to `_input` for DraggableItem to ensure drag events are captured.

### _input Bypasses Control mouse_filter
Control nodes with `mouse_filter = MOUSE_FILTER_STOP` only block GUI event propagation (Control._gui_input). They do NOT block `_input()` which receives events from the main input pipeline before GUI processing. When using `_input()` for drag handling on floor objects (desks, furniture), always check if popups/menus are open before starting drag operations.

### Godot Audio Import
Audio files placed in `res://audio/` require Godot editor to scan and import them. Running headless editor (`godot --editor --headless`) triggers the import without opening the full GUI.

### is_instance_valid() for Node References
In GDScript, checking `if node:` does NOT verify if the object has been freed. Always use `is_instance_valid(node)` before accessing properties/methods on node references that may have been queue_free()'d. Critical for: assigned_desk, office_manager, chatting_with, roster, badge_system.

### _exit_tree() Cleanup Pattern
Nodes that hold external references or reservations MUST implement `_exit_tree()` to release resources. Without it, interaction points stay reserved, desks stay "occupied", and memory leaks occur when agents are freed. Pattern:
```gdscript
func _exit_tree() -> void:
    if is_instance_valid(external_ref):
        external_ref.release()
    external_ref = null
```

### Post-await Validity Checks
After `await get_tree().create_timer().timeout`, the node and its children may have been freed. Always re-validate with `is_instance_valid(self)` AND check child nodes before accessing them.

### Static Utility Classes for Factories
Large factory methods (like personal item creation with 140+ lines of item types) are good candidates for extraction to static utility classes with `class_name`. Reduces main class size and improves maintainability. Pattern: `PersonalItemFactory.create_item(type)` instead of inline match statements.

### Composition Pattern for Large Classes
Extract cohesive functionality into `RefCounted` classes with `class_name`. Initialize in `_ready()` and delegate calls. Pattern:
```gdscript
var visuals: AgentVisuals = null
func _ready() -> void:
    visuals = AgentVisuals.new(self)
```

### Deferred Initialization for Pre-_ready Calls
When external callers invoke methods before `add_child()` triggers `_ready()`, store pending data and apply later:
```gdscript
var _pending_profile = null
func apply_profile_appearance(profile) -> void:
    if visuals:
        visuals.apply_profile_appearance(profile)
    else:
        _pending_profile = profile  # Apply in _ready()
```

### State Machines Resist Decomposition
State machine code with heavy `_process_*` functions, state transitions, and `await` calls creates tight coupling that resists extraction. Extracting would require a full StateMachine class pattern - high risk for diminishing returns.

### Godot 4 PackedStringArray Limitations
`PackedStringArray.split()` returns PackedStringArray which lacks `pop_back()` method. Wrap with `Array()` constructor for full array functionality: `var lines: Array = Array(buffer.split("\n"))`.

### Typed Arrays in GDScript
Typed arrays like `Array[Vector2]` or `Array[Dictionary]` can cause type mismatch errors when assigned from plain `Array` returns. For flexibility in function parameters and assignment, use plain `Array` type when strict typing isn't essential.

### MIN_WORK_TIME Enforcement
Agents won't leave until they've worked for MIN_WORK_TIME (3.0s). For tests with rapid spawn/complete cycles, add `"force": true` to agent_complete events to bypass this check and ensure reliable cleanup.

### Exit Point vs Boundary Exceptions
When entities get stuck trying to reach a point outside the walkable area, move the target point inside the walkable area rather than adding complex boundary-bypass logic. Simpler solution: DOOR_POSITION at Y=615 (on floor) instead of Y=665 (in wall) with LEAVING state exceptions.

### Long-Range Stuck Detection
Short-term stuck detection (1.5s, 0.75px) misses "dodging in place" where an entity moves but makes no real progress. Add long-range detection (5s, 30px) that checks actual distance traveled. On trigger, turn around and walk the opposite direction - more natural than teleporting.

### xdotool for Visual Verification
`xdotool search --name "Window Name"` finds window IDs, `import -window $ID file.png` captures screenshots. Useful for visual verification during development. May need `wmctrl -i -a $ID` to focus window first if on different workspace.

### Ghost Preview for Drag Operations
When dragging items with snapping behavior, hide the original and show a semi-transparent ghost at the snap position. Users see exactly where the item will land. Pattern:
```gdscript
func _create_ghost_preview() -> void:
    for child in get_children():
        if child is ColorRect:
            child.visible = false  # Hide original
            # Create ghost copy at snap position
```

### Visual Center Offset for Non-Centered Items
Items with position at top-left (like taskboard) need visual_center_offset to properly align grid overlays. The offset points from the node position to the item's visual/collision center:
```gdscript
visual_center_offset = Vector2(85, 161)  # Top-left to legs center
```

### Obstacle Registration Requires Conditional Checks
When spawning furniture dynamically, don't register obstacles unconditionally. Check if the furniture was actually created before registering its collision:
```gdscript
if draggable_water_cooler:
    _register_furniture_obstacle("water_cooler", pos, size)
```

### Navigation Grid as Source of Truth
Debug visualizations should query NavigationGrid directly rather than maintaining separate obstacle arrays. Prevents synchronization bugs when indices shift:
```gdscript
for obstacle_id in navigation_grid.get_all_obstacle_ids():
    var bounds = navigation_grid.get_obstacle_bounds(obstacle_id)
```

### AutoLoad vs class_name Conflict
Scripts added to AutoLoad cannot also have `class_name` declarations - Godot treats them as conflicting global identifiers. Remove `class_name` from autoloaded scripts; access via `/root/NodeName` instead.

### Registry Pattern for Settings
Centralize settings via registry where components register schemas with metadata (type, range, description). Benefits:
- New settings auto-discovered by external tools (MCP)
- Validation happens once in registry
- Components receive change callbacks
- Single persistence layer
Pattern:
```gdscript
func _ready():
    var registry = get_node_or_null("/root/SettingsRegistry")
    registry.register_category("audio", "user://audio.json", schema, _on_change)
```

### Multi-Path Cleanup Safety Net
When agents can leave through multiple paths (idle timeout, force_complete with bypass, normal completion, _exit_tree), ALL paths must properly clean up resources. Add explicit cleanup in _exit_tree() as a safety net even if normal paths should handle it:
```gdscript
func _exit_tree() -> void:
    if is_instance_valid(assigned_desk):
        assigned_desk.set_monitor_active(false)  # Safety net
        assigned_desk.set_occupied(false, agent_id)
```

### Session Detection vs Activity Pattern
Distinguish between one-time detection (`session_start` when first discovered) and ongoing activity (`session_activity` when content added). Enables proper lifecycle management when entities can leave and return:
- `session_start` - First detection, spawn orchestrator
- `session_activity` - Content detected, respawn if orchestrator missing
- `session_end` - Session stale, orchestrator leaves
