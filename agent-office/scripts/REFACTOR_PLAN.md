# Agent.gd Refactoring Plan

## Current State
- **File:** `Agent.gd`
- **Lines:** ~2880 (3.6x over 800-line limit)
- **Problems:** Hard to maintain, review, test; violates coding standards

## Proposed Architecture

### 1. Keep in Agent.gd (~800 lines)
Core agent logic and state machine:
- Lifecycle: `_init`, `_ready`, `_exit_tree`, `_process`
- State machine: All `_process_*` functions for states
- Public API: `assign_desk`, `start_walking_to_desk`, `complete_work`, `force_complete`
- Position setters: `set_shredder_position`, etc.
- Document handling: `_create_document`, `_deliver_document`

### 2. AgentVisuals.gd (~400 lines)
Visual creation and appearance:
- `_create_visuals`, `_ensure_ui_nodes`
- `_create_male_visuals`, `_create_female_visuals`
- `_create_male_visuals_persistent`, `_create_female_visuals_persistent`
- `_create_tooltip`, `_update_appearance`
- `apply_profile_appearance`, `_apply_appearance_values`
- `_clear_visual_nodes`, `_update_visual_colors`
- Tooltip: `_check_mouse_hover`, `_show_tooltip`, `_hide_tooltip`

**Integration:** Composition - Agent has-a AgentVisuals

### 3. AgentBubbles.gd (~350 lines)
Speech bubbles and reactions:
- `_show_reaction`, `_show_speech_bubble`
- `_show_spontaneous_reaction`, `_show_result_bubble`
- `clear_spontaneous_bubble`
- `_generate_reaction_phrases`, `_get_tool_aware_phrase`
- `_update_reaction_timer`
- `_process_spontaneous_bubble`, `_can_show_spontaneous_globally`

**Integration:** Composition - Agent has-a AgentBubbles

### 4. AgentSocial.gd (~200 lines)
Social behavior and chat:
- `start_chat_with`, `end_chat`, `can_chat`
- `_start_post_chat_action`, `_show_small_talk_bubble`
- `_pick_post_work_action`, `_get_social_spots`
- `_choose_social_spot`, `_mark_social_spot_cooldown`
- `_update_social_spot_cooldowns`
- `_start_socializing_at`, `_start_wandering`
- Cat reactions: `react_to_cat`, `can_react_to_cat`

**Integration:** Composition - Agent has-a AgentSocial

### 5. AgentNavigation.gd (~150 lines)
Pathfinding and movement:
- `_build_path_to`, `_try_nudge_path`
- `_handle_unreachable_destination`
- `_recover_from_stuck`
- `_is_walkable_with_clearance`
- `on_furniture_moved`
- Furniture tour: `start_furniture_tour`, `_furniture_tour_arrived`
- `_pick_tour_target`, `_order_tour_targets_by_distance`

**Integration:** Composition - Agent has-a AgentNavigation

### 6. PersonalItemFactory.gd (~150 lines)
Personal desk items:
- `_generate_personal_items`
- `_place_personal_items_on_desk`
- `_clear_personal_items_from_desk`
- `_create_personal_item` (large function with item types)

**Integration:** Static utility class, called from Agent

### 7. AgentMood.gd (~80 lines)
Mood system:
- `_update_mood`, `_update_mood_indicator`
- `get_mood_text`, `get_floor_time_text`
- Fidget: `_start_random_fidget`, `_process_fidget`, `_end_fidget`

**Integration:** Composition - Agent has-a AgentMood

## Implementation Order

1. **PersonalItemFactory** - Simplest, static utility, no state dependencies
2. **AgentMood** - Small, self-contained state
3. **AgentNavigation** - Medium complexity, clear boundaries
4. **AgentBubbles** - Medium complexity, visual-only
5. **AgentSocial** - Medium complexity, behavior logic
6. **AgentVisuals** - Largest, most coupled to Agent

## Composition Pattern

Each component will be created as a child node or inner class:

```gdscript
# Agent.gd
var visuals: AgentVisuals
var bubbles: AgentBubbles
var social: AgentSocial
var navigation: AgentNavigation
var mood: AgentMood

func _ready():
    visuals = AgentVisuals.new(self)
    bubbles = AgentBubbles.new(self)
    # ...
```

## Migration Strategy

1. Create new file with extracted functions
2. Add component as member of Agent
3. Update Agent to delegate to component
4. Test functionality
5. Remove old code from Agent
6. Repeat for next component

## Success Criteria

- Agent.gd < 800 lines
- Each component < 400 lines
- All existing functionality preserved
- No regressions in smoke tests
