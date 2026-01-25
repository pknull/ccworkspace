# Inference Inc. - Architecture Documentation

## Overview

Inference Inc. is a virtual office simulation that visualizes AI agent activity. It monitors Claude Code and Codex CLI sessions, spawning animated office workers that represent active AI agents.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INFERENCE INC.                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐       │
│  │  TranscriptWatcher│───▶│  OfficeManager   │◀───│    McpServer     │       │
│  │  (Session Monitor)│    │  (Coordinator)   │    │  (HTTP API)      │       │
│  └──────────────────┘    └────────┬─────────┘    └──────────────────┘       │
│                                   │                                          │
│         ┌─────────────────────────┼─────────────────────────┐               │
│         ▼                         ▼                         ▼               │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐         │
│  │    Agent     │         │    Desk      │         │  Furniture   │         │
│  │  (Worker)    │         │  (Workstation)│        │  (Draggable) │         │
│  └──────────────┘         └──────────────┘         └──────────────┘         │
│         │                                                                    │
│         ├── AgentVisuals (appearance)                                        │
│         ├── AgentBubbles (speech)                                           │
│         ├── AgentMood (emotions)                                            │
│         └── AgentSocial (interactions)                                      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │                        SUPPORT SYSTEMS                            │       │
│  ├──────────────┬──────────────┬──────────────┬─────────────────────┤       │
│  │ Navigation   │ Gamification │   Weather    │     Settings        │       │
│  │ Grid (A*)    │ Manager      │   System     │     Registry        │       │
│  └──────────────┴──────────────┴──────────────┴─────────────────────┘       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Core Components

### OfficeManager.gd (3015 lines) - Central Coordinator
The main orchestrator that manages all office entities.

**Responsibilities:**
- Spawns/removes agents, desks, and furniture
- Handles event routing from TranscriptWatcher and McpServer
- Manages desk assignment and meeting table overflow
- Coordinates navigation grid updates
- Handles pause menu and UI popups

**Key References:**
- `active_agents: Dictionary` - agent_id → Agent node
- `desks: Array[Desk]` - all desk instances
- `navigation_grid: NavigationGrid` - pathfinding
- `transcript_watcher: TranscriptWatcher` - session monitoring
- `mcp_server: McpServer` - HTTP API

### Agent.gd (1677 lines) - Office Worker
Represents an AI agent as an animated office worker.

**State Machine:**
```
SPAWNING → WALKING_TO_DESK → WORKING → DELIVERING → SOCIALIZING → LEAVING → COMPLETING
                                    ↘ MEETING (overflow)
                                    ↘ FURNITURE_TOUR (testing)
```

**Composition:**
- `AgentVisuals` - visual appearance, tooltips
- `AgentBubbles` - speech bubbles, reactions
- `AgentMood` - tired/frustrated/irate states
- `AgentSocial` - social spot selection

**Key Properties:**
- `agent_id: String` - unique identifier
- `agent_type: String` - role (orchestrator, coder, explorer, etc.)
- `profile: AgentProfile` - persistent identity
- `assigned_desk: Desk` - current workstation

### TranscriptWatcher.gd (636 lines) - Session Monitor
Watches Claude Code and Codex CLI session files for activity.

**Monitored Paths:**
- Claude: `~/.claude/projects/*/*.jsonl`
- Codex: `~/.codex/sessions/**/*.jsonl`

**Events Emitted:**
- `session_start` - new session detected
- `session_end` - session inactive
- `agent_spawn` - Task tool invoked
- `agent_complete` - Task result received
- `waiting_for_input` - tool awaiting permission
- `input_received` - tool completed

### McpServer.gd (1756 lines) - HTTP API
JSON-RPC server for external control.

**Endpoints:** `POST http://127.0.0.1:9999/`

**Tools:**
| Tool | Description |
|------|-------------|
| `list_settings` | Get all settings schemas |
| `get_settings` | Get current values |
| `set_setting` | Modify a setting |
| `post_event` | Inject office events |
| `spawn_agent` | Create new agent |
| `dismiss_agent` | Remove agent |
| `get_office_state` | Full state snapshot |
| `move_furniture` | Reposition items |
| `pet_cat` | Pet the office cat |

### NavigationGrid.gd (544 lines) - Pathfinding
A* pathfinding on a 20px cell grid.

**Features:**
- Dynamic obstacle registration
- Path recalculation on furniture move
- Graceful handling of unreachable destinations

**Grid:** 1280x720 viewport → 64x36 cells

## Agent Subsystems

### AgentVisuals.gd (752 lines)
Creates and manages agent appearance.

**Visual Hierarchy:**
```
Agent (Node2D)
├── shadow (ColorRect)
├── body (ColorRect)
├── shirt/blouse (ColorRect)
├── tie (ColorRect) [male only]
├── head (ColorRect)
├── hair (ColorRect)
├── eyes (ColorRect)
├── tool_bg (ColorRect)
├── tool_icon (Label)
└── status_label (Label)
```

**Appearance Properties:**
- Hair color (6 options)
- Skin tone (5 options)
- Hair style (4 options)
- Gender presentation
- Clothing colors

### AgentBubbles.gd (395 lines)
Speech bubbles and reactions.

**Bubble Types:**
- Spontaneous phrases (random intervals)
- Tool-specific phrases
- Mood-specific phrases
- Reaction bubbles (!, ?, ...)

### AgentMood.gd (173 lines)
Emotional state tracking.

**Mood States:**
- Normal (< 30 min work)
- Tired (30-60 min)
- Frustrated (60-120 min)
- Irate (> 120 min)

### AgentSocial.gd (58 lines)
Social interaction management.

**Social Spots:**
- Water cooler
- Potted plant
- Filing cabinet

## Gamification System

### GamificationManager.gd
Coordinates XP, levels, and achievements.

### AgentRoster.gd (408 lines)
Persistent agent profiles stored in `user://stable/`.

**Profile Data:**
- Name, appearance
- XP, level
- Tasks completed/failed
- Work time
- Badges, skills
- Tool usage stats

### AchievementSystem.gd
Tracks and awards achievements.

**Achievement Categories:**
- Cat interaction (Petter → Friend → Crazy Cat Office)
- Task speed (Quick → Lightning → Speed Demon)
- Tool mastery
- Social milestones

### BadgeSystem.gd
Skill-based badges for tool proficiency.

## Settings System

### SettingsRegistry.gd (AutoLoad)
Centralized settings with schema validation.

**Registered Categories:**
| Category | File | Settings |
|----------|------|----------|
| audio | user://audio_settings.json | typing_volume, meow_volume, achievement_volume, office_volume, sounds_enabled |
| weather | user://weather_settings.json | use_auto_location, location_query, use_fahrenheit, saved_lat, saved_lon |
| watchers | user://watchers.json | claude_enabled, codex_enabled, claude_path, codex_path |
| mcp | user://watchers.json | enabled, port, bind_address |

**Flow:**
```
UI Popup → Component.set_*() → SettingsRegistry → JSON file
MCP Tool → SettingsRegistry → Component callback → UI update
```

## Visual Systems

### WeatherSystem.gd
Particle-based weather effects.

**States:** Clear, Rain, Snow, Fog

**Features:**
- CPUParticles2D for rain/snow
- SubViewport clips to sky region
- Random transitions (5-15 min)

### WeatherService.gd (470 lines)
Real weather data from Open-Meteo API.

**Flow:**
1. IP geolocation (ipapi.co) or custom location
2. Geocoding (Open-Meteo)
3. Forecast fetch
4. Update WeatherSystem + TemperatureDisplay

### WallClock.gd
Real-time analog clock on office wall.

### AudioManager.gd (327 lines)
Sound effects management.

**Sounds:**
- typing.wav - keyboard sounds
- meow.wav - cat meowing
- stapler.wav - achievements
- shredder.wav - document shredding
- filing.wav - cabinet sounds

## UI Components

### PauseMenu.gd
ESC key menu with settings access.

### ProfilePopup.gd (686 lines)
Agent detail view with stats, badges, appearance.

### RosterPopup.gd (467 lines)
Agent roster list sorted by XP.

### VolumeSettingsPopup.gd
Audio volume sliders.

### WeatherSettingsPopup.gd
Location and temperature unit settings.

### WatcherConfigPopup.gd (440 lines)
Enable/disable session watchers.

### AppearanceEditorPopup.gd (599 lines)
Agent customization interface.

### FurnitureShelfPopup.gd (382 lines)
Add new furniture to office.

## Furniture System

### DraggableItem.gd
Base class for movable furniture.

**Features:**
- Drag with grid snapping (20px)
- Ghost preview during drag
- Collision validation
- Position persistence

### FurnitureRegistry.gd
Furniture type definitions and creation.

**Types:**
- water_cooler
- potted_plant
- filing_cabinet
- shredder
- cat_bed
- meeting_table
- taskboard

## Data Flow

### Agent Lifecycle
```
TranscriptWatcher detects Task tool
    ↓
OfficeManager._handle_agent_spawn()
    ↓
AgentRoster assigns profile
    ↓
Agent created, walks to desk
    ↓
Agent works (tool events update status)
    ↓
TranscriptWatcher detects Task result
    ↓
Agent delivers, socializes, leaves
    ↓
Profile updated with XP/stats
```

### Settings Change Flow
```
MCP set_setting("audio", "typing_volume", 0.5)
    ↓
SettingsRegistry.set_setting()
    ↓
Validate against schema
    ↓
Save to JSON file
    ↓
Emit setting_changed signal
    ↓
AudioManager._on_setting_changed()
    ↓
Update audio player volume
```

## File Structure

```
agent-office/
├── project.godot          # Godot project config
├── scenes/
│   └── Main.tscn          # Main scene
├── scripts/
│   ├── OfficeManager.gd   # Central coordinator
│   ├── Agent.gd           # Worker entity
│   ├── Agent*.gd          # Agent subsystems
│   ├── McpServer.gd       # HTTP API
│   ├── TranscriptWatcher.gd
│   ├── SettingsRegistry.gd
│   ├── Navigation*.gd     # Pathfinding
│   ├── Weather*.gd        # Weather systems
│   ├── *Popup.gd          # UI dialogs
│   └── ...
├── audio/
│   ├── typing.wav
│   ├── meow.wav
│   ├── stapler.wav
│   ├── shredder.wav
│   └── filing.wav
└── icon.svg
```

## Configuration

### Environment Variables
- `HOME` - user home directory (for session paths)
- `CODEX_HOME` - custom Codex directory

### User Data (user://)
- `stable/` - agent profiles
- `audio_settings.json`
- `weather_settings.json`
- `watchers.json`
- `furniture_positions.json`

## Performance Notes

- Navigation grid: 279/1792 cells blocked typical
- Max agents: Stress tested with 20 simultaneous
- Particle effects: CPU-based, clipped to sky region
- Session scan interval: 1 second

## Version History

- **1.0**: Initial release with basic agent visualization
- **1.1**: Gamification, achievements, profiles
- **2.0**: SettingsRegistry, universal MCP tools, weather system
