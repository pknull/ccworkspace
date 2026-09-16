#!/usr/bin/env python3
"""
Agent Office Watcher - Monitors Claude Code transcript files and sends events to Godot.

Usage:
    python watcher.py                    # Auto-detect latest session
    python watcher.py <session_id>       # Watch specific session
    python watcher.py --list             # List available sessions
"""

import json
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime

# Configuration
GODOT_MCP_URL = "http://localhost:9999"
CLAUDE_PROJECTS_DIR = Path.home() / ".claude" / "projects"
POLL_INTERVAL = 0.5  # seconds

# Track tool_use_id -> agent info for matching with tool_result
pending_agents = {}  # tool_use_id -> {agent_type, description, timestamp}

# Track ALL pending tool calls - any tool can require permission
pending_tools = {}  # tool_use_id -> {tool_name, timestamp}


def send_to_godot(event: dict) -> bool:
    """Send event to Godot via HTTP MCP call."""
    try:
        # Build MCP tool call request
        request_data = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "post_event",
                "arguments": event
            }
        }
        req = urllib.request.Request(
            GODOT_MCP_URL,
            data=json.dumps(request_data).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        with urllib.request.urlopen(req, timeout=2.0) as response:
            return response.status == 200
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        print(f"  [!] Failed to send to Godot: {e}")
        return False


def find_session_file(session_id: str = None) -> Path:
    """Find the transcript file for a session."""
    if not CLAUDE_PROJECTS_DIR.is_dir():
        return None
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
    if not CLAUDE_PROJECTS_DIR.is_dir():
        print(f"No Claude project directory found at {CLAUDE_PROJECTS_DIR}")
        return
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
    if not isinstance(entry, dict):
        return
    entry_type = entry.get("type")
    message = entry.get("message", {})
    if not isinstance(message, dict):
        return
    content = message.get("content", [])

    if not isinstance(content, list):
        return

    for item in content:
        # Skip string content (text messages)
        if not isinstance(item, dict):
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

    if tool_name in ("Task", "Agent"):
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
    """Tail complete JSONL records, reopening on truncation or replacement."""
    stream = open(filepath, 'rb')
    stream.seek(0, 2)
    identity = (stream.fileno(), filepath.stat().st_ino)
    remainder = b""
    try:
        while True:
            chunk = stream.read(65536)
            if chunk:
                remainder += chunk
                records = remainder.split(b"\n")
                remainder = records.pop()
                if len(remainder) > 262144:
                    print("  [!] Discarding oversized unterminated transcript record")
                    remainder = b""
                for record in records:
                    if record.strip():
                        yield record.decode("utf-8", errors="replace").rstrip("\r")
                continue

            try:
                stat = filepath.stat()
            except FileNotFoundError:
                time.sleep(POLL_INTERVAL)
                continue
            if stat.st_ino != identity[1]:
                stream.close()
                stream = open(filepath, 'rb')
                identity = (stream.fileno(), stat.st_ino)
                remainder = b""
            elif stat.st_size < stream.tell():
                stream.seek(0)
                remainder = b""
            time.sleep(POLL_INTERVAL)
    finally:
        stream.close()


def watch_session(session_file: Path):
    """Watch a session file and process new entries."""
    print(f"\n{'='*60}")
    print(f"Agent Office Watcher")
    print(f"{'='*60}")
    print(f"Watching: {session_file.name}")
    print(f"Sending to: {GODOT_MCP_URL}")
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
