# Decisions

- The MCP server is loopback-only and disabled by default; live weather is
  disabled by default and automatic location is opt-in (sends the public IP
  to ipapi.co, forecasts from Open-Meteo).
- Native godot-xterm libraries are built from the pinned script, not
  downloaded; releases ship only platforms with patched libraries (Linux
  x86-64 today).
- CI actions and build tooling are pinned by commit hash / version hash.
- Regression coverage lives in agent-office/tests/test_regressions.gd and
  runs headless under the installed Godot before a push.
- Memory/ is exactly the v2 pair; `.asha/config.json` is tracked; harness
  state, Work/ and event logs stay local.
