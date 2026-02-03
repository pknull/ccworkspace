# Active Context

**Version:** 4
**Last Updated:** 2026-02-03

## Current Status

Post-release cleanup complete. Furniture collision system refactored with visual feedback, duplicate code consolidated, magic numbers replaced with named constants. Build pushed.

## Recent Session (2026-02-03)

### Goal
Code review cleanup for maintainability issues identified post-release.

### Accomplished
- **Duplicate Mapping Elimination**: Extracted `DEFAULT_FURNITURE_MAP` constant in DraggableItem.gd - consolidated two nearly-identical inverse dicts in `_get_obstacle_id_for_node()` and `_find_furniture_by_id()`
- **Magic Number Removal**: Added `PTY_RESTART_THROTTLE_MS` (1000) and `PTY_MAX_RESTART_ATTEMPTS` (5) constants in terminal_furniture.gd
- **Collision Highlighting**: Red tint on blocking furniture during drag operations
- **ID Normalization**: `_verify_furniture_ids()` in OfficeManager fixes legacy saves using instance_id format
- **Desk Registration Fix**: Obstacle registration now uses `furniture_id` consistently (was mixing instance_id and furniture_id)
- **Tests**: smoke_test.py basic and --stress both pass (20 agents, 100 tool events, 10 cycles)

### Commits
- `34b7cc5` - refactor: Consolidate furniture mapping and add collision feedback

### Learnings
- Furniture ID inconsistency (furniture_id vs item_name vs instance_id) was causing collision detection failures
- The drag collision system required multiple fixes across DraggableItem, NavigationGrid, and OfficeManager to work properly

## Next Steps

1. **Centralized Settings Registry** (deferred from prior session):
   - Create SettingsRegistry class with registration API
   - MCP tools query registry dynamically

2. Resume furniture grid preview system (plan exists at snuggly-doodling-fox.md)

3. Test save/load persistence with various configurations

## Previous Session (2026-01-25)
- Code review fixes (CORS, validation, refactoring)
- Roster MCP tools, Settings MCP tools
- API alignment fixes
