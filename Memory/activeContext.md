---
version: "1.2"
lastUpdated: "2026-01-16 UTC"
lifecycle: "active"
stakeholder: "all"
changeTrigger: "Session save - bug fixes and orchestrator lifecycle"
validatedBy: "user"
dependencies: ["communicationStyle.md"]
---

# activeContext

## Current Project Status

**Primary Focus**: Stable - bug fixes complete, lifecycle management added

**Active Work**:
- All cute features implemented
- Orchestrator lifecycle management working (/exit detection, idle timeout)
- Meeting table overflow system working

**Recent Activities** (last 7 days):
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
- `tool_start` / `tool_end` - Tool usage
- `agent_complete` - Work finished

## Next Steps

**Immediate**:
- [x] All requested cute features implemented
- [x] Bug fixes complete
- [x] Orchestrator lifecycle management (/exit, idle timeout)

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
