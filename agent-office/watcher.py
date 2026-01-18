#!/usr/bin/env python3
"""
Agent Office Watcher - Monitors Claude Code transcript files and sends events to Godot.

Usage:
    python watcher.py                    # Auto-detect latest session
    python watcher.py <session_id>       # Watch specific session
    python watcher.py --list             # List available sessions
"""

import json
import socket
import sys
import time
from pathlib import Path
from datetime import datetime

# Configuration
GODOT_HOST = "localhost"
GODOT_PORT = 9999
CLAUDE_PROJECTS_DIR = Path.home() / ".claude" / "projects"
POLL_INTERVAL = 0.5  # seconds

# Track tool_use_id -> agent info for matching with tool_result
pending_agents = {}  # tool_use_id -> {agent_type, description, timestamp}

# Track ALL pending tool calls - any tool can require permission
pending_tools = {}  # tool_use_id -> {tool_name, timestamp}


def send_to_godot(event: dict) -> bool:
    """Send event to Godot via TCP."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1.0)
            sock.connect((GODOT_HOST, GODOT_PORT))
            sock.sendall((json.dumps(event) + "\n").encode())
        return True
    except (socket.error, socket.timeout) as e:
        print(f"  [!] Failed to send to Godot: {e}")
        return False


def find_session_file(session_id: str = None) -> Path:
    """Find the transcript file for a session."""
    # Look in all project directories
    for project_dir in CLAUDE_PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue

        if session_id:
            # Look for specific session
            session_file = project_dir / f"{session_id}.jsonl"
            if session_file.exists():
                return session_file
        else:
            # Find most recently modified .jsonl file
            jsonl_files = list(project_dir.glob("*.jsonl"))
            if jsonl_files:
                return max(jsonl_files, key=lambda f: f.stat().st_mtime)

    return None


def list_sessions():
    """List available sessions."""
    sessions = []
    for project_dir in CLAUDE_PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue
        for jsonl_file in project_dir.glob("*.jsonl"):
            stat = jsonl_file.stat()
            sessions.append({
                "id": jsonl_file.stem,
                "project": project_dir.name,
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime),
                "path": jsonl_file
            })

    # Sort by modification time, newest first
    sessions.sort(key=lambda s: s["modified"], reverse=True)

    print("\nAvailable sessions (newest first):\n")
    for s in sessions[:10]:
        size_kb = s["size"] / 1024
        print(f"  {s['id']}")
        print(f"    Modified: {s['modified'].strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"    Size: {size_kb:.1f} KB")
        print()


def process_entry(entry: dict):
    """Process a single transcript entry."""
    entry_type = entry.get("type")
    message = entry.get("message", {})
    content = message.get("content", [])

    if not content:
        return

    for item in content:
        # Skip string content (text messages)
        if isinstance(item, str):
            continue

        item_type = item.get("type")

        if item_type == "tool_use":
            process_tool_use(item, entry)
        elif item_type == "tool_result":
            process_tool_result(item, entry)


def process_tool_use(item: dict, entry: dict):
    """Handle tool_use entries."""
    tool_name = item.get("name", "")
    tool_id = item.get("id", "")
    tool_input = item.get("input", {})
    timestamp = entry.get("timestamp", "")

    if tool_name == "Task":
        # Agent spawn!
        agent_type = tool_input.get("subagent_type", "default")
        description = tool_input.get("description", "")

        # Store for matching with result
        pending_agents[tool_id] = {
            "agent_type": agent_type,
            "description": description,
            "timestamp": timestamp,
            "tool_id": tool_id
        }

        print(f"  [SPAWN] {agent_type}: {description}")

        # Send spawn event to Godot
        send_to_godot({
            "event": "agent_spawn",
            "agent_id": tool_id[:8],  # Short ID for display
            "agent_type": agent_type,
            "description": description,
            "parent_id": "main",
            "timestamp": timestamp
        })
    else:
        # ALL tools can potentially wait for permission - track them all
        pending_tools[tool_id] = {
            "tool_name": tool_name,
            "timestamp": timestamp
        }

        # Build tool description
        tool_desc = ""
        if tool_name == "Bash":
            tool_desc = tool_input.get("description", tool_input.get("command", ""))[:50]
        elif tool_name == "Read":
            tool_desc = tool_input.get("file_path", "")
        elif tool_name in ("Edit", "Write"):
            tool_desc = tool_input.get("file_path", "")
        elif tool_name in ("Glob", "Grep"):
            tool_desc = tool_input.get("pattern", "")

        print(f"  [TOOL] {tool_name}: {tool_desc[:40] if tool_desc else ''}")

        # Send waiting event - monitor turns red until result comes back
        send_to_godot({
            "event": "waiting_for_input",
            "agent_id": "main",
            "tool": tool_name,
            "description": tool_desc[:50] if tool_desc else "",
            "timestamp": timestamp
        })


def process_tool_result(item: dict, entry: dict):
    """Handle tool_result entries."""
    tool_use_id = item.get("tool_use_id", "")
    timestamp = entry.get("timestamp", "")

    # Check if this completes a pending agent
    if tool_use_id in pending_agents:
        agent_info = pending_agents.pop(tool_use_id)

        print(f"  [COMPLETE] {agent_info['agent_type']}: {agent_info['description']}")

        # Send complete event to Godot
        send_to_godot({
            "event": "agent_complete",
            "agent_id": tool_use_id[:8],
            "success": "true",
            "timestamp": timestamp
        })

    # Check if this clears a waiting state (tool completed)
    if tool_use_id in pending_tools:
        tool_info = pending_tools.pop(tool_use_id)

        print(f"  [TOOL DONE] {tool_info['tool_name']}")

        # Send input received event to Godot
        send_to_godot({
            "event": "input_received",
            "agent_id": "main",
            "tool": tool_info["tool_name"],
            "timestamp": timestamp
        })


def tail_file(filepath: Path):
    """Tail a file and yield new lines."""
    with open(filepath, 'r') as f:
        # Start at end of file
        f.seek(0, 2)

        while True:
            line = f.readline()
            if line:
                yield line.strip()
            else:
                time.sleep(POLL_INTERVAL)


def watch_session(session_file: Path):
    """Watch a session file and process new entries."""
    print(f"\n{'='*60}")
    print(f"Agent Office Watcher")
    print(f"{'='*60}")
    print(f"Watching: {session_file.name}")
    print(f"Sending to: {GODOT_HOST}:{GODOT_PORT}")
    print(f"{'='*60}\n")
    print("Waiting for new transcript entries...\n")

    try:
        for line in tail_file(session_file):
            if not line:
                continue
            try:
                entry = json.loads(line)
                process_entry(entry)
            except json.JSONDecodeError as e:
                print(f"  [!] Invalid JSON: {e}")
    except KeyboardInterrupt:
        print("\n\nStopped watching.")


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "--list":
            list_sessions()
            return
        session_id = sys.argv[1]
    else:
        session_id = None

    # Find session file
    session_file = find_session_file(session_id)

    if not session_file:
        print("Error: No session file found.")
        print("Make sure Claude Code is running or specify a session ID.")
        print("\nUsage:")
        print("  python watcher.py              # Auto-detect latest session")
        print("  python watcher.py <session_id> # Watch specific session")
        print("  python watcher.py --list       # List available sessions")
        sys.exit(1)

    watch_session(session_file)


if __name__ == "__main__":
    main()
