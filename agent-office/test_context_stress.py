#!/usr/bin/env python3
"""
Test context stress feature by simulating different stress levels.
"""

import socket
import json
import time
import sys

HOST = "localhost"
PORT = 9999

def send_event(sock, event: dict) -> None:
    """Send a JSON event to the office."""
    data = json.dumps(event) + "\n"
    sock.sendall(data.encode())
    print(f"  Sent: {event.get('event', 'unknown')}")

def test_context_stress():
    print("=" * 50)
    print("Context Stress Visual Test")
    print("=" * 50)
    print()

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((HOST, PORT))
        print(f"Connected to {HOST}:{PORT}")
    except ConnectionRefusedError:
        print("ERROR: Could not connect. Is the office running?")
        return False

    try:
        # Step 1: Spawn an orchestrator
        print("\n[1] Spawning test orchestrator...")
        send_event(sock, {
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
            send_event(sock, {
                "event": "set_context_stress",
                "agent_id": "orch_stress_test",
                "stress": stress
            })
            time.sleep(2)  # Pause to observe

        # Step 3: Cycle back down
        print("\n[3] Cycling back down (relief)...")
        for stress in [0.70, 0.50, 0.0]:
            print(f"    Setting: {int(stress * 100)}%")
            send_event(sock, {
                "event": "set_context_stress",
                "agent_id": "orch_stress_test",
                "stress": stress
            })
            time.sleep(1.5)

        # Step 4: Complete
        print("\n[4] Press Enter to complete the test...")
        input()

        send_event(sock, {
            "event": "agent_complete",
            "agent_id": "orch_stress_test",
            "force": True
        })
        time.sleep(1)

        print("\nTest complete!")
        return True

    finally:
        sock.close()

if __name__ == "__main__":
    success = test_context_stress()
    sys.exit(0 if success else 1)
