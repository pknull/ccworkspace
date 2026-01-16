---
version: "1.1"
lastUpdated: "2026-01-16 UTC"
lifecycle: "active"
stakeholder: "all"
changeTrigger: "Session save - cute features complete"
validatedBy: "user"
dependencies: ["communicationStyle.md"]
---

# activeContext

## Current Project Status

**Primary Focus**: Polish phase - adding personality and ambient behaviors

**Active Work**:
- Core cute features implemented
- Meeting table overflow system working
- Tool-aware speech bubbles active

**Recent Activities** (last 7 days):
- **2026-01-16**: Added cute features via panel-driven development:
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

**Blocked**:
- None

**Deferred**:
- Sound/audio system (user mentioned but deferred for later)
- More furniture variety
- Agent customization options
