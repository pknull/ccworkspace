#!/usr/bin/env python3
"""
Test context stress feature by simulating different stress levels.
"""

import json
import time
import sys
import urllib.error
import urllib.request

MCP_URL = "http://localhost:9999/"

def send_event(event: dict) -> None:
    """Send an event through the HTTP JSON-RPC MCP transport."""
    payload = {
        "jsonrpc": "2.0",
        "id": int(time.time_ns()),
        "method": "tools/call",
        "params": {"name": "post_event", "arguments": event},
    }
    request = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=2.0) as response:
        if response.status != 200:
            raise RuntimeError(f"MCP returned HTTP {response.status}")
    print(f"  Sent: {event.get('event', 'unknown')}")

def test_context_stress():
    print("=" * 50)
    print("Context Stress Visual Test")
    print("=" * 50)
    print()

    try:
        send_event({"event": "test_connection"})
        print(f"Connected to {MCP_URL}")
    except (urllib.error.URLError, TimeoutError, RuntimeError):
        print("ERROR: Could not connect. Is the office running?")
        return False

    try:
        # Step 1: Spawn an orchestrator
        print("\n[1] Spawning test orchestrator...")
        send_event({
            "event": "agent_spawn",
            "agent_id": "orch_stress_test",
            "agent_type": "orchestrator",
            "description": "Context stress test",
            "is_orchestrator": True
        })
        time.sleep(3)  # Let agent walk to desk

        # Step 2: Cycle through stress levels
        stress_levels = [
            (0.0, "0% - No stress (no sweat)"),
            (0.50, "50% - Light stress (1 drop)"),
            (0.70, "70% - Moderate stress (2 drops)"),
            (0.85, "85% - High stress (3 drops + flush)"),
            (0.95, "95% - Critical stress (4 drops + flush)"),
            (1.0, "100% - Maximum stress"),
        ]

        print("\n[2] Testing stress levels...")
        print("    Watch the orchestrator for sweat drops!")
        print("    Hover over them to see Context % in tooltip")
        print()

        for stress, description in stress_levels:
            print(f"    Setting: {description}")
            send_event({
                "event": "set_context_stress",
                "agent_id": "orch_stress_test",
                "stress": stress
            })
            time.sleep(2)  # Pause to observe

        # Step 3: Cycle back down
        print("\n[3] Cycling back down (relief)...")
        for stress in [0.70, 0.50, 0.0]:
            print(f"    Setting: {int(stress * 100)}%")
            send_event({
                "event": "set_context_stress",
                "agent_id": "orch_stress_test",
                "stress": stress
            })
            time.sleep(1.5)

        # Step 4: Complete
        print("\n[4] Press Enter to complete the test...")
        input()

        send_event({
            "event": "agent_complete",
            "agent_id": "orch_stress_test",
            "force": True
        })
        time.sleep(1)

        print("\nTest complete!")
        return True

    finally:
        pass

if __name__ == "__main__":
    success = test_context_stress()
    sys.exit(0 if success else 1)
