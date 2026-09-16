# Objective

Inference Inc. (repo ccworkspace, Godot 4 app under agent-office/): a
desktop companion that watches local Claude Code, Codex CLI and Clawdbot
transcript files and animates agents claiming desks and working, with
office persistence, navigation, optional loopback MCP control, opt-in
weather and gamification.

# State

Verified 2026-09-16. The 2026-07-28 review-and-hardening pass, whose
session save had committed only Memory, is now committed on master:
transcript normalization and lifecycle fixes (current Claude/Codex event
shapes, partial writes, truncation, bounded state, fair scanning), hardened
loopback MCP JSON-RPC, atomic persistence, navigation obstacle counts,
opt-in weather, GodotXterm native memory ownership fix with a pinned Linux
native build (scripts/build_godot_xterm_linux.sh), pinned CI actions in the
release workflow, and agent-office/tests/test_regressions.gd. Verified today
under Godot 4.5.stable: REGRESSION TESTS PASSED; watcher.py and the stress
script compile; build script and workflow parse. Reviewed publication is
Linux x86-64 only until patched Windows/macOS xterm libraries exist. Memory
is the v2 pair; the v1 files and event logs were retired 2026-09-16. Public
repo pknull/ccworkspace.

# Next

- Inspect the running app for any visual or interaction changes wanted
  after the hardening pass (the 07-28 launch showed only the known
  GodotXterm early-theme warnings).
- Produce patched Windows/macOS godot-xterm libraries before widening the
  release matrix.

# Blockers

- None.
