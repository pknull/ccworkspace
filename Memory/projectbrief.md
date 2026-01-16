---
version: "1.0"
lastUpdated: "2026-01-16 UTC"
lifecycle: "active"
stakeholder: "all"
changeTrigger: "Initial setup from session context"
validatedBy: "user"
dependencies: []
---

# projectbrief

## Project Overview

Claude Office is a Godot 4.5 game that visualizes AI agent task execution in a charming office environment. It provides a visual representation of Claude Code subagents working on tasks, complete with an office setting featuring desks, furniture, an office cat, and ambient behaviors.

The project receives task events via TCP server on port 9999 and translates them into animated office workers who walk to desks, work on computers, deliver results to a shredder, and socialize before leaving.

### Core Philosophy

- **Personality over precision**: Small delightful details that add character
- **Non-intrusive ambiance**: Features should enhance, not distract
- **Visual storytelling**: Agent states should be readable at a glance

## Current Primary Objective

### Feature Completeness

**Priority**: MEDIUM
**Status**: Core features implemented, polish phase
**Key Files**: `scripts/Agent.gd`, `scripts/OfficeManager.gd`, `scripts/OfficeVisualFactory.gd`

### Goals

1. **Ambient behaviors**: Agents should feel alive with spontaneous actions
2. **Overflow handling**: Gracefully handle more agents than desks via meeting table
3. **Visual polish**: Consistent art style via OfficePalette

## Completed Achievements

### Major Milestones

- **Core visualization**: 16 desks, furniture, A* pathfinding, agent state machine
- **Draggable furniture**: Water cooler, plant, filing cabinet, shredder with position persistence
- **Spontaneous speech bubbles**: Agents occasionally speak without being clicked
- **Office cat**: Autonomous behaviors (sleeping, wandering, stretching) with meow bubbles
- **Meeting table overflow**: Agents without desks gather at conference table
- **Tool-aware phrases**: Agents mention their current tool when speaking

## Success Metrics

### Completion Benchmarks

- All agent states properly visualized
- Overflow gracefully handled
- Ambient behaviors feel natural

### Quality Validation Criteria

- No visual glitches during state transitions
- Pathfinding works for all furniture positions
- Speech bubbles don't overlap excessively

## Available Resources

### Documentation

- **OfficePalette.gd**: All color constants for consistent styling
- **OfficeConstants.gd**: Layout positions and sizes

## Project Scope

### Immediate Deliverables

1. Core visualization working
2. Pleasant ambient behaviors

### Long-term Vision

- Sound/audio system
- More furniture variety
- Agent customization

## Key Stakeholders

### Primary User

- Developer using Claude Code who wants visual feedback on subagent activity
- Values aesthetics and personality in tools

### Quality Standards

- GDScript follows Godot conventions
- Colors use OfficePalette constants
- Layout uses OfficeConstants values

## Critical Context

The project is NOT a standalone game but a companion visualization for Claude Code. Events come from external TCP messages following a specific protocol (agent_spawn, tool_start, tool_end, agent_complete, etc.).
