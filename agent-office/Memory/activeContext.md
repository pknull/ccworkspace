# Active Context

**Version:** 5
**Last Updated:** 2026-02-18

## Current Status

JSON-driven furniture and appearance system complete. All simple furniture and agent appearance items now moddable via JSON files. Feature branch merged to main.

## Recent Session (2026-02-18)

### Goal

Complete JSON furniture feature, merge upstream changes, fix shift-tab terminal issue.

### Accomplished

- **Upstream Sync**: Pulled 6 commits from main (Windows terminal support, click arbitration, achievement fixes, CI consolidation)
- **Security Review**: Audited upstream commits - no critical issues, one medium finding (custom path validation recommendation)
- **Merge Conflict Resolution**: Removed duplicate `_get_home_dir()` function, kept Windows-compatible static version with USERPROFILE/HOMEDRIVE fallback
- **Shift-Tab Fix**: Added `KEY_BACKTAB` to `terminal.cpp` tab_arrow_keys set - prevents Godot focus navigation from intercepting Shift+Tab meant for Claude Code mode switching
- **Feature Branch Merge**: `feature/json-furniture` merged to main, branch deleted

### JSON Furniture System (Complete)

| Category | Count | Location |
|----------|-------|----------|
| Furniture (simple) | 7 | `furniture/definitions/*.json` |
| Furniture (complex) | 2 | `desk.gd`, `terminal_furniture.gd` with metadata JSON |
| Tops | 4 | `appearance/tops/` |
| Bottoms | 7 | `appearance/bottoms/` |
| Hair colors | 6 | `appearance/hair_colors/` |
| Hair styles | 4 | `appearance/hair_styles/` |

### Commits

- `0990fb2` - fix: Shift-Tab mode switching and merge conflict resolution
- `b48de66` - Merge branch 'main' into feature/json-furniture

### Learnings

- **Godot KEY_BACKTAB**: Shift+Tab produces distinct keycode `KEY_BACKTAB`, not `KEY_TAB` with shift modifier. Terminal input handlers must explicitly include it.
- **Git merge conflicts with stash**: When upstream deletes files that stash modifies, need to `git rm --cached` and manually resolve.

## Next Steps

1. **Path Validation** (security recommendation): Add validation to TranscriptWatcher custom paths to prevent directory traversal
2. **CI Checksum**: Add SHA256 verification for godot-xterm download in release workflow
3. Resume furniture grid preview system (plan at snuggly-doodling-fox.md)
4. Centralized Settings Registry

## Previous Session (2026-02-03)

- Duplicate mapping elimination, magic number removal
- Collision highlighting during drag
- ID normalization fixes
