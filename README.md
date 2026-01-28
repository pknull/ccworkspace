# Inference Inc.

A virtual office that visualizes your Claude Code sessions. Little agents spawn, claim desks, and type away based on what's happening in your Claude Code instance.

![Inference Inc. Screenshot](screenshot.png)

## What is this?

Inference Inc. is a desktop companion app that watches your Claude Code session files and spawns animated office workers when agents start working. They:

- Walk to desks and type while working
- Show what tool they're currently using
- Deliver completed work to the shredder or filing cabinet
- Wander to the water cooler when idle
- Pet the office cat

It doesn't do anything useful - it's purely a visualizer. But it's fun to have running while Claude works.

## Features

- **8 desks** with monitors that light up when occupied
- **Draggable furniture** - rearrange the office however you like
- **Office cat** that wanders, sleeps, and meows
- **Weather system** with rain and snow
- **Day/night cycle** that follows real time
- **Agent mood system** - agents get tired after long sessions
- **Achievements and leveling** for your agents
- **Session tracking** - see which Claude sessions are active

## Installation

Download the latest release for your platform:

- [itch.io](https://pknull.itch.io/inference-inc)
- [GitHub Releases](https://github.com/pknull/ccworkspace/releases)

### How it works

The app monitors your Claude Code session transcript files (in `~/.claude/projects/`) and detects when agents spawn, use tools, and complete work. No configuration needed - just run it alongside Claude Code.

### Optional: MCP Server

The app includes an MCP server for external control of office features (spawn agents manually, move furniture, change settings). Enable it in the Settings menu if you want Claude to interact with the office.

## Requirements

- Claude Code (for the visualization to show anything)
- Windows, macOS, or Linux

## Building from Source

Requires Godot 4.5:

```bash
cd agent-office
godot --export-release "Linux" builds/inference-inc.x86_64
```

## Alpha Status

This is still alpha software. Bugs expected. If you find issues or have suggestions, please report them on [GitHub Issues](https://github.com/pknull/ccworkspace/issues).

## Acknowledgments

Inspired by [claude-office](https://github.com/paulrobello/claude-office) by Paul Robello.

## License

MIT
