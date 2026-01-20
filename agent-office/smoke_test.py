#!/usr/bin/env python3
"""
Smoke test for Agent Office TCP server on port 9999.

Tests:
1. Connection to server
2. Basic events (agent_spawn, waiting_for_input, input_received, agent_complete)
3. Furniture tour - walks an agent to all furniture items
4. Refactor verification - tests extracted components work
5. Agent interactions - multi-agent behaviors
6. Stress tests - rapid event handling
7. Edge cases - error handling and recovery

Usage:
    python3 smoke_test.py               # Quick smoke test (4 tests)
    python3 smoke_test.py --tour        # Furniture tour (visual test)
    python3 smoke_test.py --refactor    # Component verification
    python3 smoke_test.py --interactions # Multi-agent tests
    python3 smoke_test.py --stress      # Rapid event stress test
    python3 smoke_test.py --edge        # Edge case handling
    python3 smoke_test.py --all         # Run all tests
"""

import json
import socket
import sys
import time
from typing import Optional

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


def connect() -> Optional[socket.socket]:
    """Establish TCP connection."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT)
        sock.connect((HOST, PORT))
        return sock
    except socket.error as e:
        print(f"  FAIL: {e}")
        return None


def timestamp() -> str:
    """Get current UTC timestamp in ISO format."""
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


# =============================================================================
# Basic Tests
# =============================================================================

def test_connection() -> Optional[socket.socket]:
    """Test basic TCP connection."""
    print(f"[1/4] Connecting to {HOST}:{PORT}...")
    sock = connect()
    if sock:
        print("  PASS: Connected")
    return sock


def test_agent_spawn(sock: socket.socket, agent_id: str = "smoke001") -> bool:
    """Test sending agent_spawn event."""
    print("[2/4] Sending agent_spawn event...")
    event = {
        "event": "agent_spawn",
        "agent_id": agent_id,
        "agent_type": "smoke-test",
        "description": "Smoke test agent",
        "parent_id": "main",
        "timestamp": timestamp()
    }
    if send_event(sock, event):
        print("  PASS: agent_spawn sent")
        return True
    return False


def test_waiting_for_input(sock: socket.socket, agent_id: str = "smoke001") -> bool:
    """Test sending waiting_for_input event (replaces old tool_use)."""
    print("[3/4] Sending waiting_for_input event...")
    event = {
        "event": "waiting_for_input",
        "agent_id": agent_id,
        "tool": "Bash",
        "description": "echo 'smoke test'",
        "session_path": "/tmp/smoke-test",
        "timestamp": timestamp()
    }
    if send_event(sock, event):
        print("  PASS: waiting_for_input sent")
        return True
    return False


def test_agent_complete(sock: socket.socket, agent_id: str = "smoke001") -> bool:
    """Test sending agent_complete event."""
    print("[4/4] Sending agent_complete event...")
    event = {
        "event": "agent_complete",
        "agent_id": agent_id,
        "success": "true",
        "timestamp": timestamp()
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

    # Test 3: waiting_for_input (triggers monitor color change)
    if test_waiting_for_input(sock):
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


# =============================================================================
# Furniture Tour
# =============================================================================

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
        "timestamp": timestamp()
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


# =============================================================================
# Refactor Verification Tests
# =============================================================================

def run_refactor_tests() -> bool:
    """Test that extracted components work correctly."""
    print()
    print("=" * 50)
    print("Agent Office Smoke Test - Refactor Verification")
    print("=" * 50)
    print()
    print("Testing extracted components:")
    print("  - AgentVisuals (appearance, tooltips)")
    print("  - AgentBubbles (speech, reactions)")
    print("  - AgentMood (mood tracking, fidgets)")
    print("  - AgentSocial (social spot selection)")
    print()

    sock = connect()
    if not sock:
        print("FAIL: Cannot connect to server")
        return False

    passed = 0
    failed = 0

    # Test 1: Spawn agent with visuals
    print("[1/5] Spawning agent (tests AgentVisuals)...")
    if send_event(sock, {
        "event": "agent_spawn",
        "agent_id": "refactor001",
        "agent_type": "typescript-pro",
        "description": "Refactor test - visuals",
        "parent_id": "main",
        "timestamp": timestamp()
    }):
        print("  PASS: Agent spawned")
        passed += 1
    else:
        failed += 1

    time.sleep(1.0)  # Wait for agent to walk to desk

    # Test 2: Trigger tool display (tests visuals.show_tool)
    print("[2/5] Triggering tool display...")
    if send_event(sock, {
        "event": "waiting_for_input",
        "agent_id": "refactor001",
        "tool": "Read",
        "description": "Reading config file",
        "session_path": "/tmp/refactor-test",
        "timestamp": timestamp()
    }):
        print("  PASS: Tool display triggered")
        passed += 1
    else:
        failed += 1

    time.sleep(0.5)

    # Test 3: Clear tool display
    print("[3/5] Clearing tool display...")
    if send_event(sock, {
        "event": "input_received",
        "agent_id": "refactor001",
        "tool": "Read",
        "session_path": "/tmp/refactor-test",
        "timestamp": timestamp()
    }):
        print("  PASS: Tool display cleared")
        passed += 1
    else:
        failed += 1

    time.sleep(0.5)

    # Test 4: Spawn second agent (tests social interactions)
    print("[4/5] Spawning second agent (tests AgentSocial)...")
    if send_event(sock, {
        "event": "agent_spawn",
        "agent_id": "refactor002",
        "agent_type": "debugger",
        "description": "Refactor test - social",
        "parent_id": "main",
        "timestamp": timestamp()
    }):
        print("  PASS: Second agent spawned")
        passed += 1
    else:
        failed += 1

    time.sleep(2.0)  # Let agents potentially interact

    # Test 5: Complete both agents (tests bubbles/leaving behavior)
    print("[5/5] Completing agents (tests AgentBubbles)...")
    success = True
    for agent_id in ["refactor001", "refactor002"]:
        if not send_event(sock, {
            "event": "agent_complete",
            "agent_id": agent_id,
            "success": "true",
            "force": True,  # Bypass MIN_WORK_TIME for reliable test cleanup
            "timestamp": timestamp()
        }):
            success = False
        time.sleep(0.2)

    if success:
        print("  PASS: Agents completed")
        passed += 1
    else:
        failed += 1

    sock.close()

    print()
    print("=" * 50)
    print(f"Refactor tests: {passed} passed, {failed} failed")
    print("=" * 50)
    print()
    print("Visual verification:")
    print("  1. Both agents had visible bodies/heads/hair")
    print("  2. Tool icon appeared above agent during waiting_for_input")
    print("  3. Agents may have chatted or shown speech bubbles")
    print("  4. Agents walked to door on completion")
    print()

    return failed == 0


# =============================================================================
# Agent Interaction Tests
# =============================================================================

def run_interaction_tests() -> bool:
    """Test multi-agent interactions."""
    print()
    print("=" * 50)
    print("Agent Office Smoke Test - Agent Interactions")
    print("=" * 50)
    print()
    print("Testing:")
    print("  - Multiple agents spawning")
    print("  - Meeting table overflow (9+ agents)")
    print("  - Session lifecycle (orchestrator)")
    print()

    sock = connect()
    if not sock:
        print("FAIL: Cannot connect to server")
        return False

    passed = 0
    failed = 0

    # Test 1: Session start (creates orchestrator)
    print("[1/4] Starting session (creates orchestrator)...")
    if send_event(sock, {
        "event": "session_start",
        "session_id": "interaction-test",
        "session_path": "/tmp/interaction-test.jsonl",
        "timestamp": timestamp()
    }):
        print("  PASS: Session started")
        passed += 1
    else:
        failed += 1

    time.sleep(1.0)

    # Test 2: Spawn multiple agents
    print("[2/4] Spawning 6 agents...")
    agent_types = ["typescript-pro", "debugger", "python-pro", "tdd", "security-auditor", "devops-engineer"]
    spawn_success = True
    for i, agent_type in enumerate(agent_types):
        if not send_event(sock, {
            "event": "agent_spawn",
            "agent_id": f"interact{i:03d}",
            "agent_type": agent_type,
            "description": f"Interaction test agent {i+1}",
            "parent_id": "main",
            "timestamp": timestamp()
        }):
            spawn_success = False
        time.sleep(0.1)

    if spawn_success:
        print(f"  PASS: {len(agent_types)} agents spawned")
        passed += 1
    else:
        failed += 1

    time.sleep(3.0)  # Let agents settle

    # Test 3: Spawn more to trigger meeting overflow
    print("[3/4] Spawning 4 more agents (tests meeting overflow)...")
    overflow_success = True
    for i in range(6, 10):
        if not send_event(sock, {
            "event": "agent_spawn",
            "agent_id": f"interact{i:03d}",
            "agent_type": "full-stack-developer",
            "description": f"Overflow test agent {i+1}",
            "parent_id": "main",
            "timestamp": timestamp()
        }):
            overflow_success = False
        time.sleep(0.1)

    if overflow_success:
        print("  PASS: 4 additional agents spawned")
        passed += 1
    else:
        failed += 1

    time.sleep(2.0)

    # Test 4: End session (completes orchestrator)
    print("[4/4] Ending session...")
    if send_event(sock, {
        "event": "session_end",
        "session_id": "interaction-test",
        "session_path": "/tmp/interaction-test.jsonl",
        "timestamp": timestamp()
    }):
        print("  PASS: Session ended")
        passed += 1
    else:
        failed += 1

    # Complete all agents (force=true bypasses MIN_WORK_TIME for immediate cleanup)
    for i in range(10):
        send_event(sock, {
            "event": "agent_complete",
            "agent_id": f"interact{i:03d}",
            "success": "true",
            "force": True,
            "timestamp": timestamp()
        })
        time.sleep(0.05)

    sock.close()

    print()
    print("=" * 50)
    print(f"Interaction tests: {passed} passed, {failed} failed")
    print("=" * 50)
    print()
    print("Visual verification:")
    print("  1. Orchestrator appeared at session start")
    print("  2. Agents filled desks, then meeting table")
    print("  3. Some agents may have chatted")
    print("  4. Orchestrator left at session end")
    print()

    return failed == 0


# =============================================================================
# Stress Tests
# =============================================================================

def run_stress_tests() -> bool:
    """Stress test with rapid events."""
    print()
    print("=" * 50)
    print("Agent Office Smoke Test - Stress Test")
    print("=" * 50)
    print()
    print("Testing rapid event handling:")
    print("  - 20 agents spawned in 2 seconds")
    print("  - Rapid tool state cycling")
    print("  - Quick spawn/complete cycles")
    print()

    sock = connect()
    if not sock:
        print("FAIL: Cannot connect to server")
        return False

    passed = 0
    failed = 0
    errors = 0

    # Test 1: Rapid agent spawning
    print("[1/3] Spawning 20 agents rapidly...")
    start = time.time()
    for i in range(20):
        if not send_event(sock, {
            "event": "agent_spawn",
            "agent_id": f"stress{i:03d}",
            "agent_type": "smoke-test",
            "description": f"Stress test {i+1}",
            "parent_id": "main",
            "timestamp": timestamp()
        }):
            errors += 1
        time.sleep(0.1)
    elapsed = time.time() - start

    if errors == 0:
        print(f"  PASS: 20 agents spawned in {elapsed:.2f}s ({20/elapsed:.1f} events/sec)")
        passed += 1
    else:
        print(f"  PARTIAL: {20-errors}/20 spawned, {errors} errors")
        failed += 1

    time.sleep(1.0)

    # Test 2: Rapid tool state cycling
    print("[2/3] Cycling tool states 50 times...")
    errors = 0
    start = time.time()
    for i in range(50):
        if not send_event(sock, {
            "event": "waiting_for_input",
            "agent_id": "stress000",
            "tool": "Bash",
            "description": f"Command {i+1}",
            "session_path": "/tmp/stress",
            "timestamp": timestamp()
        }):
            errors += 1
        if not send_event(sock, {
            "event": "input_received",
            "agent_id": "stress000",
            "tool": "Bash",
            "session_path": "/tmp/stress",
            "timestamp": timestamp()
        }):
            errors += 1
        time.sleep(0.02)
    elapsed = time.time() - start

    if errors == 0:
        print(f"  PASS: 100 events in {elapsed:.2f}s ({100/elapsed:.1f} events/sec)")
        passed += 1
    else:
        print(f"  PARTIAL: {100-errors}/100 sent, {errors} errors")
        failed += 1

    # Test 3: Quick spawn/complete cycles
    print("[3/3] Quick spawn/complete cycles...")
    errors = 0
    start = time.time()
    for i in range(10):
        agent_id = f"cycle{i:03d}"
        if not send_event(sock, {
            "event": "agent_spawn",
            "agent_id": agent_id,
            "agent_type": "smoke-test",
            "description": f"Cycle test {i+1}",
            "parent_id": "main",
            "timestamp": timestamp()
        }):
            errors += 1
        time.sleep(0.3)  # Brief work
        if not send_event(sock, {
            "event": "agent_complete",
            "agent_id": agent_id,
            "success": "true",
            "timestamp": timestamp()
        }):
            errors += 1
        time.sleep(0.1)
    elapsed = time.time() - start

    if errors == 0:
        print(f"  PASS: 10 cycles in {elapsed:.2f}s")
        passed += 1
    else:
        print(f"  PARTIAL: {20-errors}/20 events sent, {errors} errors")
        failed += 1

    # Cleanup: Complete all stress agents (force=true bypasses MIN_WORK_TIME)
    for i in range(20):
        send_event(sock, {
            "event": "agent_complete",
            "agent_id": f"stress{i:03d}",
            "success": "true",
            "force": True,
            "timestamp": timestamp()
        })
        time.sleep(0.02)

    sock.close()

    print()
    print("=" * 50)
    print(f"Stress tests: {passed} passed, {failed} failed")
    print("=" * 50)
    print()
    print("Visual verification:")
    print("  1. Office handled many agents without crashing")
    print("  2. Tool icons flickered rapidly during cycling")
    print("  3. Agents came and went during cycles")
    print()

    return failed == 0


# =============================================================================
# Edge Case Tests
# =============================================================================

def run_edge_case_tests() -> bool:
    """Test edge cases and error handling."""
    print()
    print("=" * 50)
    print("Agent Office Smoke Test - Edge Cases")
    print("=" * 50)
    print()
    print("Testing error handling:")
    print("  - Complete non-existent agent")
    print("  - Invalid event format")
    print("  - Missing required fields")
    print("  - Duplicate agent IDs")
    print()

    sock = connect()
    if not sock:
        print("FAIL: Cannot connect to server")
        return False

    passed = 0
    failed = 0

    # Test 1: Complete non-existent agent (should be ignored gracefully)
    print("[1/5] Completing non-existent agent...")
    if send_event(sock, {
        "event": "agent_complete",
        "agent_id": "nonexistent999",
        "success": "true",
        "timestamp": timestamp()
    }):
        print("  PASS: Event sent (server should ignore gracefully)")
        passed += 1
    else:
        failed += 1

    time.sleep(0.2)

    # Test 2: Invalid event type (should be ignored)
    print("[2/5] Sending invalid event type...")
    if send_event(sock, {
        "event": "invalid_event_type",
        "data": "test",
        "timestamp": timestamp()
    }):
        print("  PASS: Event sent (server should ignore unknown event)")
        passed += 1
    else:
        failed += 1

    time.sleep(0.2)

    # Test 3: Missing required fields
    print("[3/5] Sending agent_spawn without agent_id...")
    if send_event(sock, {
        "event": "agent_spawn",
        "agent_type": "test",
        "description": "Missing ID test",
        "timestamp": timestamp()
    }):
        print("  PASS: Event sent (server should handle missing field)")
        passed += 1
    else:
        failed += 1

    time.sleep(0.2)

    # Test 4: Spawn agent, then spawn with same ID
    print("[4/5] Testing duplicate agent ID...")
    send_event(sock, {
        "event": "agent_spawn",
        "agent_id": "duplicate001",
        "agent_type": "smoke-test",
        "description": "Original agent",
        "parent_id": "main",
        "timestamp": timestamp()
    })
    time.sleep(0.5)
    if send_event(sock, {
        "event": "agent_spawn",
        "agent_id": "duplicate001",
        "agent_type": "smoke-test",
        "description": "Duplicate agent",
        "parent_id": "main",
        "timestamp": timestamp()
    }):
        print("  PASS: Duplicate event sent (server should handle)")
        passed += 1
    else:
        failed += 1

    time.sleep(0.5)

    # Test 5: Empty event
    print("[5/5] Sending empty JSON...")
    if send_event(sock, {}):
        print("  PASS: Empty event sent (server should ignore)")
        passed += 1
    else:
        failed += 1

    # Cleanup
    send_event(sock, {
        "event": "agent_complete",
        "agent_id": "duplicate001",
        "success": "true",
        "force": True,  # Bypass MIN_WORK_TIME for immediate cleanup
        "timestamp": timestamp()
    })

    sock.close()

    print()
    print("=" * 50)
    print(f"Edge case tests: {passed} passed, {failed} failed")
    print("=" * 50)
    print()
    print("Verification:")
    print("  1. Server did not crash on any edge case")
    print("  2. Invalid events were silently ignored")
    print("  3. Duplicate agent ID was handled gracefully")
    print()

    return failed == 0


# =============================================================================
# Main
# =============================================================================

def main():
    args = sys.argv[1:]

    tour_mode = "--tour" in args
    refactor_mode = "--refactor" in args
    interactions_mode = "--interactions" in args
    stress_mode = "--stress" in args
    edge_mode = "--edge" in args
    all_mode = "--all" in args

    # If no specific mode, run basic tests
    run_specific = tour_mode or refactor_mode or interactions_mode or stress_mode or edge_mode

    # Always run basic tests first (unless specific mode selected)
    if not run_specific or all_mode:
        basic_passed = run_basic_tests()
        if not basic_passed:
            print("\nBasic tests FAILED")
            sys.exit(1)
        print("\nBasic smoke test PASSED")

    all_passed = True

    if tour_mode or all_mode:
        if not run_furniture_tour():
            all_passed = False

    if refactor_mode or all_mode:
        if not run_refactor_tests():
            all_passed = False

    if interactions_mode or all_mode:
        if not run_interaction_tests():
            all_passed = False

    if stress_mode or all_mode:
        if not run_stress_tests():
            all_passed = False

    if edge_mode or all_mode:
        if not run_edge_case_tests():
            all_passed = False

    if not run_specific and not all_mode:
        print("\nTips:")
        print("  --tour          Furniture accessibility tour")
        print("  --refactor      Test extracted components")
        print("  --interactions  Multi-agent interaction tests")
        print("  --stress        Rapid event stress test")
        print("  --edge          Edge case handling")
        print("  --all           Run all tests")

    if all_mode and not all_passed:
        print("\nSome tests FAILED")
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
