---
version: "1.0"
lastUpdated: "2026-01-16"
---

# techEnvironment

## Platform

**OS**: Linux (6.8.0-90-generic)
**Working Directory**: /home/pknull/Code/ccworkspace/agent-office

## Asha Framework

Tools are provided by the Asha plugin. Tool paths are injected via SessionStart hook.

### Available Commands

| Command | Purpose |
|---------|---------|
| `/asha:save` | Save session context, archive, refresh index, commit |
| `/asha:index` | Index files for semantic search |
| `/asha:init` | Initialize Asha in a new project |
| `/asha:cleanup` | Remove legacy asha/ installation files |

### Tool Invocation

Tools are executed via the plugin's Python environment. Example patterns provided in session context.

**Semantic Search**: Query indexed files using memory_index.py
**Pattern Tracking**: Track and query patterns via reasoning_bank.py

## Project-Specific Stack

### Languages & Frameworks

- **GDScript**: Godot 4.5's scripting language
- **Godot Engine**: 4.5 (latest stable)

### Key Scripts

| File | Purpose |
|------|---------|
| `scripts/Agent.gd` | Agent state machine, behaviors, speech |
| `scripts/OfficeManager.gd` | Central coordinator, desk assignment |
| `scripts/OfficeVisualFactory.gd` | All visual element creation |
| `scripts/OfficePalette.gd` | Color constants |
| `scripts/OfficeConstants.gd` | Layout positions, sizes |
| `scripts/NavigationGrid.gd` | A* pathfinding |
| `scripts/TCPServer.gd` | Event listener on port 9999 |
| `scripts/OfficeCat.gd` | Autonomous cat behaviors |

### Architecture

```
Main.tscn
├── OfficeManager (singleton coordinator)
│   ├── Furniture (water cooler, plant, cabinet, shredder, meeting table)
│   ├── Desks[16] (workstations)
│   ├── Agents[] (dynamic, spawned via TCP events)
│   └── OfficeCat
└── TCPServer (port 9999)
```

### TCP Event Protocol

JSON messages to port 9999:
```json
{"event": "agent_spawn", "id": "abc123", "type": "Explore", "description": "..."}
{"event": "tool_start", "id": "abc123", "tool": "Read", "details": "..."}
{"event": "tool_end", "id": "abc123", "tool": "Read"}
{"event": "agent_complete", "id": "abc123"}
```

### Development Tools

- **Editor**: Godot 4.5 built-in editor
- **Git**: Version control
- **Claude Code**: Primary development assistant
