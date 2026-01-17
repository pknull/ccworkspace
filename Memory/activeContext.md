---
version: "1.3"
lastUpdated: "2026-01-16 UTC"
lifecycle: "active"
stakeholder: "all"
changeTrigger: "Session save - z-index fix, smoke test, path recalculation"
validatedBy: "user"
dependencies: ["communicationStyle.md"]
---

# activeContext

## Current Project Status

**Primary Focus**: Stable - z-index rendering fixed, smoke test infrastructure added

**Active Work**:
- Z-index rendering fixed for all furniture
- Smoke test script with furniture tour
- Path recalculation on furniture movement
- Graceful unreachable path handling

**Recent Activities** (last 7 days):
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
- [ ] Visual verification of furniture tour

**Blocked**:
- None

**Deferred**:
- Sound/audio system (user mentioned but deferred for later)
- More furniture variety
- Agent customization options

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
