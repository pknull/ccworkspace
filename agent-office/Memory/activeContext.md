# Active Context

**Version:** 3
**Last Updated:** 2026-01-25

## Current Status

MCP tooling expanded significantly. Code review fixes applied. Settings MCP tools added but architecture identified as non-universal - centralized settings registry needed.

## Recent Session (2026-01-25)

### Accomplished
- **Code Review Fixes**: Applied fixes from 4-way parallel review:
  - CORS restricted from `*` to `http://localhost`
  - Dictionary validation for placed_furniture access
  - Refactored 128-line function into 3 helper methods
  - Added constants for appearance bounds (HAIR_COLOR_COUNT, etc.)
  - Fixed unused `sock` parameter in smoke_test.py
  - Centralized HAIR_COLORS/SKIN_TONES arrays in OfficePalette.gd
- **Roster MCP Tools**: Added `list_roster` and `fire_agent` tools, fired 11 agents to trim roster to top 10
- **Settings MCP Tools**: Added `get_settings`, `set_volume`, `set_watcher`, `set_weather_config`
- **API Alignment**: Fixed WeatherService API usage (use_fahrenheit not use_celsius, proper setter methods)

### Key Learnings
- Settings are scattered across components (AudioManager, WeatherService, TranscriptWatcher, McpServer)
- Each has its own settings file and API - no universal registry
- MCP tools manually hardcoded to know about specific properties
- Need centralized SettingsRegistry for dynamic discoverability

### Commits This Session
- `46eca25` - feat: Add MCP settings tools for volume, watchers, and weather
- Previous review fixes committed earlier in session

## Next Steps

1. **Centralized Settings Registry** (in progress):
   - Create SettingsRegistry class with registration API
   - Settings declare metadata (type, range, description, category)
   - MCP tools query registry dynamically
   - Migrate existing settings to use registry

2. Resume furniture grid preview system (plan exists at snuggly-doodling-fox.md)
3. Test save/load persistence with various configurations

## Previous Session (2026-01-24)
- Orphan cleanup, idle agent recall, UI polish, PauseMenu refactor
- 14 MCP tools operational
