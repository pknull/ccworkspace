# Repository Guidelines

## Project Structure & Module Organization
- Root config: `project.godot`, `export_presets.cfg`, and `.godot/` define Godot project settings and editor state.
- Game content: `scenes/` contains `.tscn` scenes; `scripts/` contains GDScript `.gd` logic.
- Assets: `assets/`, `audio/`, and `icon.svg` hold art, sounds, and icons.
- Utilities: `smoke_test.py` (TCP smoke tests) and `watcher.py` (dev helper) live in the root.

## Build, Test, and Development Commands
- `godot` opens the project in the editor (run from repo root).
- `godot --headless --quit` runs a quick headless sanity check.
- `python3 smoke_test.py` runs the 4-step smoke test; use flags like `--all` or `--tour` for expanded coverage.
- Export builds (see `RELEASING.md`):
  - `godot --headless --export-release "Linux" builds/linux/claude-office.x86_64`
  - `godot --headless --export-release "Windows" builds/windows/claude-office.exe`
  - `godot --headless --export-release "macOS" builds/macos/claude-office.dmg`

## Coding Style & Naming Conventions
- GDScript follows Godot defaults: tabs for indentation, `snake_case` for functions/variables, `PascalCase` for classes and files, and `UPPER_SNAKE_CASE` for constants.
- Python uses 4 spaces and `snake_case` names; keep docstrings short and action-focused.
- Match established patterns in `scripts/` and `scenes/` before introducing new structures.

## Testing Guidelines
- `smoke_test.py` expects the app/server running on `localhost:9999`.
- Add new smoke test cases when introducing new event types or agent behaviors.
- There is no separate unit test framework in this repo; keep tests close to runtime behavior.

## Commit & Pull Request Guidelines
- No `.git` history is present in this checkout. For releases, follow the format in `RELEASING.md`:
  - Subject: `Release vX.Y.Z`
  - Body: short bullet summary, optional `Co-Authored-By` line
- PRs should include: a clear summary, testing notes (commands run), and screenshots/GIFs for scene or UI changes.

## Agent-Specific Instructions
- The Asha workflow and memory conventions are documented in `CLAUDE.md`. Follow those instructions when applicable.
