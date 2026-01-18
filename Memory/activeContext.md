---
version: "1.5"
lastUpdated: "2026-01-18 UTC"
lifecycle: "active"
stakeholder: "all"
changeTrigger: "Session save - major feature additions, bug fixes, audio system"
validatedBy: "user"
dependencies: ["communicationStyle.md"]
---

# activeContext

## Current Project Status

**Primary Focus**: Feature-rich office simulation with audio, day/night cycle, achievements

**Active Work**:
- Audio system implemented with CC0 sound effects
- Day/night cycle with real-time sky colors
- Agent mood system (tired/frustrated/irate)
- Enhanced achievement system with cat and speed achievements

**Recent Activities** (last 7 days):
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
- [x] All requested cute features implemented
- [x] Bug fixes complete
- [x] Orchestrator lifecycle management (/exit, idle timeout)
- [x] Z-index rendering fixed for furniture
- [x] Smoke test with furniture tour
- [x] Path recalculation on furniture move
- [x] Gamification lifetime stats verified working
- [x] Tool definitions centralized in OfficePalette
- [x] Sound/audio system implemented
- [x] Day/night cycle
- [x] Agent mood system
- [x] Cat and speed achievements
- [ ] Test tool tracking with reduced scan interval
- [ ] Verify subagents leaving properly

**Blocked**:
- None

**Deferred**:
- Extract AgentSpawner from OfficeManager (reduces monolith)
- EventBus pattern for decoupled communication
- A* priority queue optimization
- Weather effects (user noted back wall layering issues)
- More furniture variety

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

### Godot Audio Import
Audio files placed in `res://audio/` require Godot editor to scan and import them. Running headless editor (`godot --editor --headless`) triggers the import without opening the full GUI.
