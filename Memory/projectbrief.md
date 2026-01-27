---
version: "2.0"
lastUpdated: "2026-01-27 UTC"
lifecycle: "released"
stakeholder: "all"
changeTrigger: "v2.0.2 release"
validatedBy: "user"
dependencies: []
---

# projectbrief

## Project Overview

**Inference Inc.** is a Godot 4.5 desktop companion app that visualizes Claude Code sessions as a charming virtual office. When Claude agents work, little office workers spawn, claim desks, type on computers, and go about their day.

The project connects via MCP (Model Context Protocol) or TCP on port 9999 to receive events and translate them into animated behaviors.

### Core Philosophy

- **Personality over precision**: Small delightful details that add character
- **Non-intrusive ambiance**: Something pleasant to have running in the background
- **Visual storytelling**: Agent states readable at a glance

## Status

**Released** - v2.0.2 available on itch.io and GitHub Releases

### Features Implemented

- 8 desks with active monitors showing current tool
- Draggable furniture (water cooler, plant, filing cabinet, shredder, taskboard, meeting table)
- Office cat with autonomous behaviors (sleep, wander, stretch, meow)
- Weather system (rain/snow particles)
- Day/night cycle following real time
- Agent mood system (tired, frustrated, irate)
- Achievement and leveling system
- Session panel showing active Claude sessions
- MCP server for external control

### Distribution

- **itch.io**: https://pknull.itch.io/inference-inc
- **GitHub**: https://github.com/pknull/ccworkspace/releases

## Architecture

```
Main.tscn
├── OfficeManager (coordinator)
│   ├── Furniture (draggable items)
│   ├── Desks[8] (workstations)
│   ├── Agents[] (spawned dynamically)
│   └── OfficeCat
├── TranscriptWatcher (monitors Claude session files)
├── McpServer (external MCP tool interface)
└── AudioManager (typing, meow, achievement sounds)
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/Agent.gd` | Agent state machine, behaviors |
| `scripts/OfficeManager.gd` | Central coordinator |
| `scripts/McpServer.gd` | MCP tool interface |
| `scripts/TranscriptWatcher.gd` | Session monitoring |
| `scripts/OfficePalette.gd` | Color constants |
| `scripts/OfficeConstants.gd` | Layout constants |

## Success Metrics

- Visualization feels alive and charming
- Doesn't interfere with actual work
- Easy to set up and run
