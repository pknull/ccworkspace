#!/usr/bin/env python3
"""
Smoke test for Agent Office TCP server on port 9999.

Tests:
1. Connection to server
2. Basic events (agent_spawn, tool_use, agent_complete)
3. Furniture tour - walks an agent to all furniture items

Usage:
    python3 smoke_test.py           # Quick smoke test
    python3 smoke_test.py --tour    # Full furniture tour (visual test)
"""

import json
import socket
import sys
import time

HOST = "localhost"
PORT = 9999
TIMEOUT = 2.0


def send_event(sock: socket.socket, event: dict) -> bool:
    """Send a JSON event to the server."""
    try:
        message = json.dumps(event) + "\n"
        sock.sendall(message.encode())
        return True
    except socket.error as e:
        print(f"  FAIL: Send error - {e}")
        return False


def connect() -> socket.socket | None:
    """Establish TCP connection."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT)
        sock.connect((HOST, PORT))
        return sock
    except socket.error as e:
        print(f"  FAIL: {e}")
        return None


def test_connection() -> socket.socket | None:
    """Test basic TCP connection."""
    print(f"[1/4] Connecting to {HOST}:{PORT}...")
    sock = connect()
    if sock:
        print("  PASS: Connected")
    return sock


def test_agent_spawn(sock: socket.socket) -> bool:
    """Test sending agent_spawn event."""
    print("[2/4] Sending agent_spawn event...")
    event = {
        "event": "agent_spawn",
        "agent_id": "smoke001",
        "agent_type": "smoke-test",
        "description": "Smoke test agent",
        "parent_id": "main",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    if send_event(sock, event):
        print("  PASS: agent_spawn sent")
        return True
    return False


def test_tool_use(sock: socket.socket) -> bool:
    """Test sending tool_use event."""
    print("[3/4] Sending tool_use event...")
    event = {
        "event": "tool_use",
        "agent_id": "main",
        "tool": "Bash",
        "description": "echo 'smoke test'",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    if send_event(sock, event):
        print("  PASS: tool_use sent")
        return True
    return False


def test_agent_complete(sock: socket.socket) -> bool:
    """Test sending agent_complete event."""
    print("[4/4] Sending agent_complete event...")
    event = {
        "event": "agent_complete",
        "agent_id": "smoke001",
        "success": "true",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    if send_event(sock, event):
        print("  PASS: agent_complete sent")
        return True
    return False


def run_basic_tests() -> bool:
    """Run basic connectivity and event tests."""
    print("=" * 50)
    print("Agent Office Smoke Test - Basic")
    print("=" * 50)
    print()

    passed = 0
    failed = 0

    # Test 1: Connection
    sock = test_connection()
    if sock:
        passed += 1
    else:
        failed += 1
        print("\nSmoke test FAILED: Cannot connect to server")
        print(f"Make sure the Godot app is running with TCP server on port {PORT}")
        return False

    time.sleep(0.1)

    # Test 2: agent_spawn
    if test_agent_spawn(sock):
        passed += 1
    else:
        failed += 1

    time.sleep(0.5)

    # Test 3: tool_use
    if test_tool_use(sock):
        passed += 1
    else:
        failed += 1

    time.sleep(0.5)

    # Test 4: agent_complete
    if test_agent_complete(sock):
        passed += 1
    else:
        failed += 1

    sock.close()

    # Summary
    print()
    print("=" * 50)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 50)

    return failed == 0


def run_furniture_tour() -> bool:
    """Run furniture tour test - agent visits all furniture items."""
    print()
    print("=" * 50)
    print("Agent Office Smoke Test - Furniture Tour")
    print("=" * 50)
    print()
    print("This test spawns an agent that walks to each piece")
    print("of furniture to verify accessibility and rendering.")
    print()

    print("[TOUR] Connecting...")
    sock = connect()
    if not sock:
        print("  FAIL: Cannot connect to server")
        return False
    print("  Connected")

    print("[TOUR] Sending furniture_tour event...")
    event = {
        "event": "furniture_tour",
        "agent_id": "tour001",
        "agent_type": "smoke-test",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }

    if send_event(sock, event):
        print("  PASS: furniture_tour event sent")
    else:
        print("  FAIL: Could not send event")
        sock.close()
        return False

    sock.close()

    print()
    print("=" * 50)
    print("Furniture tour started!")
    print("=" * 50)
    print()
    print("Watch the Godot app - the agent will visit:")
    print("  - Water Cooler (left & right sides)")
    print("  - Plant (left & right sides)")
    print("  - Filing Cabinet (left & right sides)")
    print("  - Shredder (left & front)")
    print("  - Meeting Table (all 4 sides)")
    print("  - Then exit via the door")
    print()
    print("Check that:")
    print("  1. Agent can reach all furniture (no blocked paths)")
    print("  2. Z-ordering looks correct (agent behind/in front as expected)")
    print("  3. No visual glitches at any position")
    print()

    return True


def main():
    tour_mode = "--tour" in sys.argv

    # Always run basic tests first
    basic_passed = run_basic_tests()

    if not basic_passed:
        print("\nBasic tests FAILED")
        sys.exit(1)

    print("\nBasic smoke test PASSED")

    if tour_mode:
        # Run furniture tour
        tour_passed = run_furniture_tour()
        if not tour_passed:
            print("\nFurniture tour FAILED")
            sys.exit(1)
    else:
        print("\nTip: Run with --tour for full furniture accessibility test")

    sys.exit(0)


if __name__ == "__main__":
    main()
