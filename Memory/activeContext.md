---
version: "2.0"
lastUpdated: "2026-07-28 07:00 UTC"
lifecycle: "active"
synthesizedFrom: "events"
---

# Active Context

## What Was Accomplished (2026-07-28 — Inference Inc. review and hardening)
<!-- wwa-session: 019fa62a-aacc-7542-acde-4de0e326dd0d -->

- Reconstructed the Godot application's intent and architecture: transcript-driven visualization for Claude Code, Codex CLI, and Clawdbot, with optional loopback MCP control, office persistence, navigation, weather, and gamification.
- Ran independent logic, security, and edge-case reviews, applied the confirmed findings, and repeated slim adversarial passes until all three reviewers passed the final fixes.
- Corrected transcript normalization and lifecycle behavior, including current Claude/Codex event shapes, partial writes, truncation and replacement detection, bounded retained state, fair scanning, session cleanup, and tool correlation.
- Hardened MCP HTTP/JSON-RPC handling, furniture operations, loopback defaults, request limits, Unicode framing, client timeouts, and clean shutdown.
- Corrected navigation obstacle reference counts, desk identity and placement behavior, atomic settings/roster/statistics/layout persistence, opt-in weather lookup, and achievement tracking.
- Fixed native GodotXterm memory ownership and disabled unsafe cross-thread libuv access. Added a pinned Linux native build path for debug and release libraries.
- Reworked release packaging and documentation: pinned CI dependencies, excluded private/development resources, included the required native library, and limited reviewed publication to Linux x86-64 until patched Windows/macOS libraries exist.
- Added `agent-office/tests/test_regressions.gd` and verified the regression suite, Godot editor parse/import, native debug/release compilation, Linux export, packaged runtime startup, Python syntax, shell syntax, workflow YAML, and diff hygiene.
- Launched the application in the desktop session as `Inference Inc. (DEBUG)` for visual inspection. The startup log showed active Codex/Claude session discovery and agent/tool activity; only the known early-theme-access warnings from GodotXterm remained.

## Next Steps

1. Inspect the running Inference Inc. window and record any visual or interaction changes wanted.
2. Review the application diff and commit it separately from this Memory checkpoint; the code changes remain intentionally uncommitted and unpushed.
3. Before restoring Windows or macOS releases, build and test the patched GodotXterm native library on each target and re-enable those workflow artifacts only after runtime smoke tests.
