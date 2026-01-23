# Active Context

**Version:** 1
**Last Updated:** 2026-01-23

## Current Status

MCP Manager feature implementation complete with full office control via MCP tools.

## Recent Session (2026-01-23)

### Accomplished
- Added `remove_furniture` MCP tool - removes furniture by ID
- Added `add_furniture` MCP tool - places new furniture at coordinates
- Updated `get_office_state` to show furniture IDs (defaults vs dynamic arrays)
- Fixed duplicate shredder bug (caused by both default and dynamic shredder in save)
- Added `on_cat_petted()` reaction to McpManager - manager walks to cat
- Connected cat_petted signal: OfficeCat → OfficeManager → McpManager
- UI fixes: Edit button placement in portrait box, appearance panel border, badge refresh on roster changes

### Key Technical Decisions
- HTTP MCP connections are short-lived; using 30-second timeout for manager visibility
- Furniture separated into "defaults" (built-in) and "dynamic" (user-placed) in state
- Default furniture IDs use `default_` prefix; dynamic use `furniture_N` pattern

### MCP Tools Available (14 total)
1. post_event - Office events
2. set_weather - Weather control
3. dismiss_agent - Single agent dismissal
4. dismiss_all_agents - Mass dismissal
5. quit_office - Clean shutdown
6. get_office_state - Full state dump
7. list_agents - Agent listing
8. get_agent_profile - Profile details
9. move_furniture - Reposition furniture
10. move_desk - Reposition desks
11. pet_cat - Cat interaction
12. spawn_agent - Create agents
13. remove_furniture - Delete furniture
14. add_furniture - Place new furniture

## Next Steps

1. Test all MCP tools for edge cases
2. Add taskboard MCP interaction (read/write tasks)
3. Manager visual polish (animation timing, speech bubbles)
4. Consider adding `list_furniture_types` tool for discoverability
5. Test save/load persistence with various furniture configurations
