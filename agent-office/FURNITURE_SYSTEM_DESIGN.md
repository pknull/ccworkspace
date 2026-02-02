# Furniture System Design

## Overview

Modular, trait-based furniture system where:
- All furniture is draggable and replaceable at runtime
- Agents interact with furniture based on traits, not specific types
- New furniture can be added without modifying agent code
- Graceful degradation when furniture is missing (affects mood, not crashes)

## Class Hierarchy

```
Node2D
└── DraggableItem
    │   - drag detection, bounds, grid snap
    │   - obstacle_size, navigation_grid ref
    │   - position_changed signal
    │
    ├── FurnitureBase
    │   │   - traits: Array[String]
    │   │   - capacity: int
    │   │   - slots: Array[{offset: Vector2, occupied_by: String}]
    │   │   - reserve(agent_id) / release(agent_id)
    │   │   - hooks: on_reserved, on_agent_arrived, on_agent_left, on_released
    │   │
    │   ├── Desk
    │   ├── MeetingTable
    │   ├── Shredder
    │   ├── FilingCabinet
    │   ├── WaterCooler
    │   ├── Plant
    │   ├── Taskboard
    │   └── CatBed
    │
    ├── OfficeCat (not furniture, just draggable)
    │
    └── Agent (future possibility)
```

## Traits

Traits define what agents can do with furniture. Most furniture has multiple traits.

| Trait | Purpose | Agent State |
|-------|---------|-------------|
| `terminal` | Exclusive work station (desk with monitor) | WORKING |
| `overflow` | Fallback when terminals full | MEETING |
| `delivery` | Turn in completed work | DELIVERING |
| `social` | Hang out, chat with others | SOCIALIZING |
| `viewable` | Passive display, can look at | - |
| `cat_rest` | Cat-specific resting spot | - |

### Trait Composition

| Furniture | Traits |
|-----------|--------|
| Desk | `terminal` |
| Meeting Table | `overflow`, `social` |
| Shredder | `delivery`, `social` |
| Filing Cabinet | `delivery`, `social` |
| Water Cooler | `social` |
| Plant | `social` |
| Taskboard | `viewable`, `social` |
| Cat Bed | `cat_rest` |
| Terminal (large) | *(no agent traits; user-interactive)* |

Note: `social` is additive - agents can socialize at most furniture except desks (work-focused).

## FurnitureBase Properties

```gdscript
# Core
var traits: Array[String] = []
var capacity: int = 1
var slots: Array = []  # [{offset: Vector2, occupied_by: String}, ...]

# Optional
var wall_mounted: bool = false      # Affects z-index behavior
var delivery_sound: String = ""     # Sound to play on delivery
```

## FurnitureBase Hooks

Furniture overrides these to add custom behavior. Default implementations do nothing.

```gdscript
func on_reserved(agent, slot_index: int) -> void:
    pass  # Called when agent claims a slot

func on_agent_arrived(agent, slot_index: int) -> void:
    pass  # Called when agent reaches the furniture

func on_agent_left(agent, slot_index: int) -> void:
    pass  # Called when agent leaves

func on_released(agent, slot_index: int) -> void:
    pass  # Called when slot is freed
```

### Example: Desk Hooks

```gdscript
func on_reserved(agent, slot_index: int) -> void:
    _set_monitor_state(RESERVED)  # Yellow

func on_agent_arrived(agent, slot_index: int) -> void:
    _set_monitor_state(ACTIVE)    # Green
    _show_tool(agent.current_tool)
    _add_personal_items(agent)

func on_agent_left(agent, slot_index: int) -> void:
    _set_monitor_state(OFF)       # Red
    _clear_tool()
    _clear_personal_items()
```

### Example: Shredder Hooks

```gdscript
func on_agent_arrived(agent, slot_index: int) -> void:
    AudioManager.play_shredder()
```

## Furniture File Structure

Each furniture type is a self-contained `.gd` file:

```
agent-office/
└── furniture/
    ├── desk.gd
    ├── terminal_furniture.gd
    ├── meeting_table.gd
    ├── shredder.gd
    ├── filing_cabinet.gd
    ├── water_cooler.gd
    ├── plant.gd
    ├── taskboard.gd
    └── cat_bed.gd
```

### Furniture File Template

```gdscript
extends FurnitureBase
class_name FurnitureShredder

func _init():
    traits = ["delivery", "social"]
    capacity = 3
    slots = [
        {offset = Vector2(-20, 30), occupied_by = ""},
        {offset = Vector2(0, 35), occupied_by = ""},
        {offset = Vector2(20, 30), occupied_by = ""},
    ]
    obstacle_size = Vector2(30, 40)
    delivery_sound = "shredder"

func _build_visuals() -> void:
    # Create visual nodes programmatically
    var body = ColorRect.new()
    body.size = Vector2(30, 40)
    body.color = OfficePalette.SHREDDER_COLOR
    add_child(body)
    # ... more visuals

func on_agent_arrived(agent, slot_index: int) -> void:
    if delivery_sound:
        AudioManager.play(delivery_sound)
```

## Agent Query Flow

Agents query furniture by trait through OfficeManager:

```gdscript
# Agent needs to work
var result = office_manager.find_available("terminal")
if not result:
    result = office_manager.find_available("overflow")
if not result:
    # No work spot - enter frustrated state, keep looking
    _enter_looking_for_work_state()
    return

# Found a spot
result.furniture.reserve(agent_id, result.slot_index)
_walk_to(result.furniture.get_slot_position(result.slot_index))
```

```gdscript
# Agent needs to deliver
var result = office_manager.find_available("delivery")
# Randomly picks from Shredder or FilingCabinet

# Agent wants to socialize
var result = office_manager.find_available("social")
# Weighted random from all furniture with "social" trait
```

## FurnitureRegistry

Catalog of available furniture types for spawning:

```gdscript
class_name FurnitureRegistry

var available_types: Dictionary = {
    "desk": preload("res://furniture/desk.gd"),
    "shredder": preload("res://furniture/shredder.gd"),
    # ...
}

func spawn(type: String, position: Vector2) -> FurnitureBase:
    var script = available_types.get(type)
    if not script:
        return null
    var furniture = script.new()
    furniture.position = position
    furniture._build_visuals()
    return furniture

func get_available_types() -> Array[String]:
    return available_types.keys()
```

## User Actions

### Add Furniture

1. User opens FurnitureShelfPopup
2. Popup shows available types from FurnitureRegistry
3. User clicks type and placement position
4. `registry.spawn(type, position)` creates instance
5. `office_manager.add_furniture(furniture)` tracks it
6. `navigation_grid.add_obstacle(...)` updates pathfinding

### Remove Furniture

1. User selects furniture, clicks remove
2. `furniture.release_all()` - kicks out any agents gracefully
3. `office_manager.remove_furniture(furniture)` stops tracking
4. `navigation_grid.remove_obstacle(...)` updates pathfinding
5. `furniture.queue_free()` destroys node

## Persistence

### Save Format

```json
{
  "furniture": [
    {"type": "desk", "id": "desk_1", "position": [100, 200]},
    {"type": "desk", "id": "desk_2", "position": [200, 200]},
    {"type": "shredder", "id": "shredder_1", "position": [500, 400]},
    ...
  ]
}
```

### Save/Load

```gdscript
# Save
func save_layout():
    var data = {"furniture": []}
    for f in furniture:
        data.furniture.append({
            "type": f.furniture_type,
            "id": f.furniture_id,
            "position": [f.position.x, f.position.y]
        })
    # Write to user://furniture_layout.json

# Load
func load_layout():
    # Read from user://furniture_layout.json
    for item in data.furniture:
        var f = registry.spawn(item.type, Vector2(item.position[0], item.position[1]))
        f.furniture_id = item.id
        add_furniture(f)
```

## Graceful Degradation

When furniture is missing, agents adapt rather than crash:

| Missing | Agent Behavior |
|---------|----------------|
| No terminals | Enters "looking for work" state, mood drops, keeps searching |
| No delivery targets | Work completes without delivery animation |
| No social spots | Skips socialization, goes directly to exit |
| No cat_rest | Cat wanders but doesn't rest |

Mood system (future) can track frustration from missing furniture.

## Migration from Current System

### Phase 1: Create Foundation
- [ ] Create `FurnitureBase` extending `DraggableItem`
- [ ] Create `furniture/` directory
- [ ] Create `FurnitureRegistry`

### Phase 2: Migrate Furniture
- [ ] Migrate `Shredder` to new system (simplest)
- [ ] Migrate `FilingCabinet`
- [ ] Migrate `WaterCooler`
- [ ] Migrate `Plant`
- [ ] Migrate `Taskboard`
- [ ] Migrate `CatBed`
- [ ] Migrate `MeetingTable`
- [ ] Migrate `Desk` (most complex - last)

### Phase 3: Update Agent Queries
- [ ] Add `find_available(trait)` to OfficeManager
- [ ] Replace hardcoded position setters in Agent
- [ ] Replace furniture name checks with trait queries

### Phase 4: Update OfficeManager
- [ ] Remove individual furniture variables
- [ ] Use unified `furniture: Array[FurnitureBase]`
- [ ] Update persistence to new format

### Phase 5: Cleanup
- [ ] Remove old furniture code from OfficeVisualFactory
- [ ] Remove old interaction_points_occupied system
- [ ] Update smoke tests
