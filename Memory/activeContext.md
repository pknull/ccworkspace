---
version: "3.3"
lastUpdated: "2026-02-02 UTC"
lifecycle: "active"
stakeholder: "all"
changeTrigger: "Session save - v2.2.0 release (terminal furniture, itch.io CI)"
validatedBy: "user"
dependencies: ["communicationStyle.md"]
---

# activeContext

## Current Project Status

**Primary Focus**: Feature-complete office simulation - published on itch.io

**Active Work**:
- Feature-complete, v2.2.0 released with terminal furniture
- Stability fixes and crash prevention

**Recent Activities** (last 7 days):
- **2026-02-02 (Session 24)**: v2.2.0 release - Terminal furniture complete:
  - **Goal**: Complete terminal furniture integration, merge to main, release
  - **Font investigation**: Tested spleen (5x8, 6x12), cozette, JetBrains Mono
    - **Result**: Gohufont 11px (6×11) remains best - crisp, correct size, retro aesthetic
    - Other fonts either too big, too crushed, or poor antialiasing in Godot
  - **Color rendering fix**: White halo around colored text (e.g., blue on black)
    - **Root cause**: GodotXterm dual-layer rendering - foreground color as base, ANSI colors on top
    - **Solution**: Monochrome amber theme - all 16 ANSI colors mapped to same amber
    - **Result**: Clean retro terminal aesthetic, no rendering artifacts
  - **Code review & fixes** (code-reviewer agent):
    - **Critical**: Added `_exit_tree()` to kill PTY process on furniture removal
    - **High**: Replaced SceneTree timer with child Timer node (prevents callback on freed object)
    - **High**: Added restart throttling (max 5 retries within 1 second)
    - **Medium**: `is_instance_valid()` checks throughout, font resource duplication
  - **Cleanup**: Removed unused files (TerminalEmulator.gd, spleen/cozette/unscii fonts, build artifacts)
  - **MIT License**: Added project license file
  - **CI/CD**: Added itch.io publishing via butler to release workflow
  - **Release**: v2.2.0 tagged, pushed, CI building exports for GitHub + itch.io
  - **Learning**: GodotXterm's foreground/ANSI layering causes color halos; monochrome avoids this

- **2026-02-01 (Session 23)**: Terminal furniture bug fixes:
  - **Goal**: Investigate new terminal furniture, improve font rendering, fix bugs
  - **Font investigation**: Explored bitmap fonts (lime, nu, limey, cozette) for crisp rendering
    - **Discovery**: Godot doesn't support OTB (OpenType Bitmap) format - only TTF/OTF
    - Configured gohufont-11 with correct 6×11 pixel dimensions
    - Updated GodotXterm theme to use gohufont
  - **Bug fix - Shell restart**: Terminal got stuck after typing `exit`
    - **Root cause**: PTY node can't be reused after child process exits - `fork()` silently fails
    - **Fix**: Recreate entire PTY node in `_restart_shell()` instead of reusing
  - **Bug fix - Taskboard removal**: Verified working (debug prints confirmed signal flow)
  - **Cleanup**: Removed unused `third_party/limey/` folder
  - **Status**: Branch `terminal-furniture` - more issues to address before merge
  - **Learning**: PTY nodes must be recreated after process exit, not reused

- **2026-01-31 (Session 22)**: Extended X11 crash mitigation to TranscriptWatcher:
  - **Trigger**: XCB sequence number crash after 13 hours runtime (v2.1.1 improved from immediate crashes)
  - **Observation**: v2.1.1 deferred `roster_changed` signals; crash still occurred after extended runtime
  - **Analysis**: TranscriptWatcher has 9 `event_received.emit()` calls still synchronous
  - **Panel decision**: 100% consensus to apply same deferred emission pattern
  - **Fix implemented**:
    - Added `TranscriptWatcher._emit_event()` helper with guards: `is_inside_tree()`, `is_queued_for_deletion()`, tree validity
    - All 9 `event_received.emit()` calls converted to `call_deferred("_emit_event", {...})`
    - Events affected: `session_start`, `session_end`, `session_activity`, `session_exit`, `agent_spawn`, `waiting_for_input`, `agent_complete`, `input_received` (2 locations)
  - **Pattern**: Same mechanism as AgentRoster fix - deferred emission breaks synchronous cascades that race with X11
  - **Known limitation**: Still application-level mitigation for Godot engine bug (#102633)
  - **Learning**: When one signal path is deferred, check ALL signal paths that trigger UI updates

- **2026-01-31 (Session 21)**: v2.1.1 release - X11 crash cascade prevention:
  - **Bug**: XCB crash during session cleanup, triggered by roster_changed signal cascade
  - **Root cause**: Session 19's fix deferred `session_end` emission, but subsequent `roster_changed.emit()` in `record_orchestrator_session()` still triggered synchronous UI updates that raced with X11
  - **Cascade path**: `session_end` → `_handle_session_end` → `record_orchestrator_session` → `roster_changed.emit()` → 4 handlers doing UI updates
  - **Fix implemented (defense in depth)**:
    - `AgentRoster._emit_roster_changed()` helper with guards: `is_inside_tree()`, `is_queued_for_deletion()`, tree validity
    - All 7 `roster_changed.emit()` calls replaced with `call_deferred("_emit_roster_changed")`
    - All 4 `_on_roster_changed()` handlers guard with `is_inside_tree()`
    - `OfficeManager._request_quit()` disconnects transcript_watcher and roster signals before cleanup
    - `OfficeManager._on_event_received()` skips processing when `is_quitting`
  - **Known limitation**: This is application-level mitigation for a Godot engine bug ([#102633](https://github.com/godotengine/godot/issues/102633)). True graceful X11 recovery would require engine changes.
  - **Learning**: When signals trigger UI operations, both emitter AND receivers need shutdown guards. Defense in depth - fail gracefully at multiple points.
  - **Release**: Tagged v2.1.1, pushed to GitHub, CI building exports

- **2026-01-30 (Session 20)**: Fixed roster working_agents desync (orphaned agents):
  - **Bug**: User reported agents "stuck at the door"; roster showed Quinn/Casey as `[working]` but they weren't in office
  - **Root cause**: Two separate tracking systems can desync:
    - `OfficeManager.active_agents` tracks actual Agent nodes in scene
    - `AgentRoster.working_agents` tracks profile IDs marked as busy
  - When agents complete abnormally (app quit, scene tree manipulation), `work_completed` signal never fires, `release_agent()` never runs
  - **Not a state engine problem**: Agent state machine is correct; issue is architectural coupling between tracking systems
  - **Fix implemented**:
    - `AgentRoster.gd`: Added `reconcile_working_agents(active_profile_ids)` - compares working dict with actual agents, releases orphans
    - `OfficeManager.gd`: Added `_reconcile_roster()` called every 5 seconds via timer
    - Collects profile IDs from all active agents, passes to roster for sync
  - **Result**: Orphaned working entries (Quinn, Casey) will be auto-released within 5 seconds of app restart
  - **Learning**: When two systems track related state independently, add periodic reconciliation as safety net

- **2026-01-29 (Session 19)**: Fixed XCB threading crash on session cleanup:
  - **Bug**: Godot crashed with XCB assertion failure when TranscriptWatcher sessions became inactive
  - **Root cause**: Synchronous event cascade during `_process` - `_remove_stale_sessions` emitted `session_end` synchronously, triggering `record_orchestrator_session` → `roster_changed.emit()` → UI updates, all racing with X11
  - **Fix**: Added `call_deferred("_emit_session_end", ...)` in TranscriptWatcher.gd to defer signal emission to next frame
  - Added new `_emit_session_end` helper function following existing `_emit_session_start` pattern
  - **Learning**: Deferred signal emission breaks synchronous cascades that can cause X11 threading races

- **2026-01-28 (Session 17-18)**: v2.1.0 release - context stress visuals, custom session paths, Clawdbot:
  - **Reddit request**: Personal-Dev-Kit requested configurable session paths for WSL users
  - **Custom session paths (WatcherConfigPopup.gd)**:
    - All harnesses now have editable path fields (removed HARNESS_PATH_REQUIRED restriction)
    - Claude/Codex show auto-detected path as placeholder, field empty unless custom
    - WSL users can enter paths like `\\wsl$\Ubuntu\home\user\.claude\projects`
  - **Context stress visuals (Agent.gd, AgentVisuals.gd)**:
    - Orchestrators display sweat drops (1-4) based on context usage percentage
    - Thresholds: 50% (1 drop), 70% (2), 85% (3), 95% (4 + face flush)
    - Context % shown in agent tooltip
  - **Sliding window tracking (TranscriptWatcher.gd)**:
    - Context measured over 10-minute window with 800KB cap
    - Old entries pruned every 5 seconds for natural decay
    - `/compact` command detection resets context to 0%
  - **Clawdbot harness support** (user added):
    - New harness for Clawdbot agent sessions (~/.clawdbot/agents)
    - Parses embedded toolCall events in message content
    - Clears waiting state on subsequent text (no explicit toolResult)
  - **Code cleanup**: Extracted magic numbers to constants (SWEAT_DROP_COLOR, etc.)
  - **Reddit engagement**: 85 upvotes, 22K views; Personal-Dev-Kit confirmed v2.1.0 fixed their issue
  - **GitHub stats**: 6 stars, 1 fork, 7 downloads on v2.1.0 release
  - **Schedule plugin tested**: Created/removed monitoring cron job via `/schedule`

- **2026-01-27 (Session 16)**: v2.0.2 release - desk collision fix, monitor cleanup, typing sounds:
  - **Bug report 1**: Typing sounds continue after agent leaves desk
  - **Fix**: Added `stop_typing()` method to AudioManager, called in `complete_work()` and `_start_leaving()`
  - **Bug report 2**: Desk collision boxes don't move when desks are moved
  - **Root cause 1**: Signal signature mismatch - DraggableItem emits `(item_name: String, position)` but `_on_desk_position_changed` expected `(desk: FurnitureDesk, position)`
  - **Root cause 2**: Inconsistent obstacle IDs - `_add_desk` registered with `furniture_id` but move handler used `get_instance_id()`
  - **Fixes**:
    - `FurnitureDesk._input()` - Override drag end to emit `(self, position)` matching handler expectation
    - `OfficeManager._add_desk()` - Use `get_instance_id()` for obstacle registration
    - `OfficeManager._remove_desk()` - Always use `get_instance_id()` for consistency
  - **Cleanup**: Removed unused `tasks_failed` tracking from AgentProfile, AgentRoster, AgentStable, McpServer, ProfilePopup
  - **Monitor cleanup hardening**: `force_complete()` now explicitly turns off monitor for IDLE/CHATTING/WANDERING/FURNITURE_TOUR states and during DELIVERING/SOCIALIZING/LEAVING/COMPLETING states
  - **Release**: Tagged v2.0.2, pushed to GitHub, CI workflow building Linux/Windows/macOS exports

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

- **2026-01-20 (Sessions 8-12)**: Weather system, smoke tests, floor boundaries, desk drag fixes
  - WeatherSystem with rain/snow particles clipped to sky region
  - Extended smoke_test.py to 832 lines with 22 tests (refactor, interactions, stress, edge cases)
  - Fixed floor boundaries (FLOOR_MAX_Y=630, DOOR_POSITION Y=615)
  - Fixed cat stuck detection with long-range timeout
  - Fixed desk drag during popups (added popup check to Desk._input)

- **2026-01-19 (Sessions 6-7)**: Agent.gd refactor - 51% reduction:
  - Extracted: AgentVisuals (691), AgentBubbles (395), AgentMood (173), AgentSocial (58), PersonalItemFactory (169)
  - Agent.gd: ~2880 → 1419 lines
  - Fixed profile appearance deferred initialization pattern

- **2026-01-18 (Session 5)**: Major features - wall clock, mood system, audio, day/night cycle

- **2026-01-16-17 (Sessions 1-4)**: Initial features and gamification verification

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
- [x] Set up itch.io publishing workflow (GitHub Actions with Butler)
- [x] v2.0.2 released - desk collision fix, monitor cleanup, typing sounds
- [x] v2.1.0 released - context stress visuals, custom session paths, Clawdbot harness
- [x] v2.1.1 released - X11 crash cascade prevention via deferred roster signals
- [x] v2.2.0 released - terminal furniture with embedded GodotXterm, itch.io CI publishing

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

### Signal Signature Mismatch with Inheritance
When a base class defines a signal with one signature (e.g., `(item_name: String, position)`) but handlers expect a different signature (e.g., `(item: Node, position)`), GDScript's dynamic signal system will pass whatever is emitted. The handler receives wrong types and method calls fail silently or crash. Fix: Override the signal emission in subclasses to match handler expectations.

### Consistent IDs for Navigation Grid Operations
When registering/unregistering obstacles in NavigationGrid, use the SAME ID scheme everywhere:
- `_register_with_navigation_grid()` uses `"desk_%d" % desk.get_instance_id()`
- `_add_desk()` must use same format, NOT `desk.furniture_id`
- `_remove_desk()` and `_on_desk_position_changed()` must use same format
Using different ID schemes causes unregister calls to silently fail (obstacle not found).

### UI Must Expose Backend Settings
When backend supports a feature (like custom paths in TranscriptWatcher), the UI must expose it. In WatcherConfigPopup, `HARNESS_PATH_REQUIRED` gated which harnesses got editable fields - but the backend already supported paths for all harnesses. Always check if config UI matches backend capabilities.

### Sliding Window for Decay Metrics
Instead of cumulative counters with artificial decay timers, use sliding windows: store timestamped entries, prune entries older than the window, sum remaining. Benefits: natural decay, no magic decay rates, reflects actual recent activity. Pattern:
```gdscript
var entries: Array = []  # [{time: float, size: int}, ...]
const WINDOW_SECONDS = 600.0
func add_entry(size: int) -> void:
    entries.append({"time": Time.get_unix_time_from_system(), "size": size})
func prune() -> void:
    var cutoff = Time.get_unix_time_from_system() - WINDOW_SECONDS
    entries = entries.filter(func(e): return e.time >= cutoff)
```

### Cron vs Systemd Timer Formats
Cron expressions like `*/10 * * * *` don't directly translate to systemd calendar specs. The sync script may generate invalid timer files. Use `--force-cron` flag when systemd timers fail with "bad unit file setting".

### Deferred Signal Emission for X11 Threading
Synchronous signal cascades during `_process` can cause XCB assertion failures when X11 requests race between threads. When emitting signals that trigger UI updates (especially during session/resource cleanup), use `call_deferred` to defer emission to the next frame:
```gdscript
# Instead of:
event_received.emit({"event": "session_end", ...})

# Use:
call_deferred("_emit_session_end", session_id, path, harness)

func _emit_session_end(session_id: String, session_path: String, harness: String) -> void:
    event_received.emit({...})
```
This breaks the synchronous cascade and gives X11 time to complete pending operations.

### GodotXterm Color Rendering Artifacts
GodotXterm renders text in two layers: foreground color as base, then ANSI colors applied on top. When ANSI colors differ from foreground, the base layer shows through as a "halo" around characters (especially visible with blue on black background). Solutions:
1. **Monochrome theme**: Map all 16 ANSI colors to the same foreground color
2. **Accept artifacts**: If colors are essential, the halos are unavoidable with current GodotXterm architecture
Pattern:
```gdscript
# Monochrome amber theme - no color artifacts
var fg = Color(1.0, 0.6, 0.2, 1.0)  # Amber
for i in range(16):
    terminal.add_theme_color_override("ansi_%d_color" % i, fg)
```

### SceneTree Timer vs Child Timer
`get_tree().create_timer()` creates a timer that lives in the SceneTree, NOT as a child of the calling node. If the node is freed before the timer fires, the callback attempts to call a method on a freed object (crash). Solution: Use child Timer nodes that get freed with parent:
```gdscript
# Unsafe - timer survives node deletion
var timer = get_tree().create_timer(0.1)
timer.timeout.connect(_my_callback)

# Safe - timer dies with parent
var timer = Timer.new()
timer.wait_time = 0.1
timer.one_shot = true
timer.timeout.connect(_my_callback)
add_child(timer)
timer.start()
```

### PTY Cleanup in _exit_tree
PTY (pseudo-terminal) processes continue running after their Godot node is freed. Always kill the PTY process explicitly in `_exit_tree()` to prevent orphaned shell processes:
```gdscript
func _exit_tree() -> void:
    if _pty and is_instance_valid(_pty):
        if _pty.has_method("kill"):
            _pty.call("kill", 15)  # SIGTERM
        _pty = null
```

### Shell Restart Throttling
Auto-restarting shells on exit can create infinite loops if the shell immediately crashes (invalid SHELL, permission issues). Add throttling:
```gdscript
var _restart_count := 0
var _last_restart_time := 0

func _on_pty_exited(_exit_code: int, _signum: int) -> void:
    var now = Time.get_ticks_msec()
    if now - _last_restart_time < 1000:
        _restart_count += 1
        if _restart_count > 5:
            push_error("Shell crashed too many times, not restarting")
            return
    else:
        _restart_count = 0
    _last_restart_time = now
    # ... proceed with restart
```

### Font Resource Global Mutation
`load()` returns a shared resource instance. Modifying properties (antialiasing, hinting) affects ALL users of that resource. Always duplicate before modifying:
```gdscript
# Wrong - modifies global resource
var font = load(font_path) as FontFile
font.antialiasing = TextServer.FONT_ANTIALIASING_NONE

# Correct - local copy
var font = load(font_path).duplicate() as FontFile
font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
```

### Parallel State Tracking Desync
When two systems track related state independently (e.g., `active_agents` dict vs `working_agents` dict), they can desync if one system's cleanup path fails. Solutions:
1. **Tight coupling**: Make one system authoritative, other derives state
2. **Reconciliation**: Periodically sync systems to catch drift
3. **Event-driven**: Both systems listen to same lifecycle events
Pattern for reconciliation:
```gdscript
func reconcile_working_agents(active_profile_ids: Array[int]) -> int:
    var orphaned: Array[int] = []
    for profile_id in working_agents.keys():
        if profile_id not in active_profile_ids:
            orphaned.append(profile_id)
    for profile_id in orphaned:
        working_agents.erase(profile_id)
    return orphaned.size()
```

### Defense in Depth for Signal-Triggered UI
When signals trigger UI operations that can race with system cleanup (X11, etc.), guard at BOTH emitter and receiver:
1. **Emitter helper**: Create deferred emission helper with validity checks
2. **Receiver guards**: Check `is_inside_tree()` and shutdown flags before processing
3. **Shutdown disconnect**: Explicitly disconnect signal handlers in `_request_quit()` before any cleanup
4. **Entry point guard**: Skip event processing entirely when `is_quitting`
Pattern:
```gdscript
# Emitter - deferred with guards
func _emit_roster_changed() -> void:
    if not is_inside_tree() or is_queued_for_deletion():
        return
    if get_tree() == null:
        return
    roster_changed.emit()

# Replace all direct emissions
call_deferred("_emit_roster_changed")

# Receiver - shutdown guard
func _on_roster_changed() -> void:
    if is_quitting or not is_inside_tree():
        return
    _update_ui()

# Shutdown - disconnect first
func _request_quit() -> void:
    is_quitting = true
    signal_source.my_signal.disconnect(_my_handler)
    # ... then save/cleanup
```
