# Release Process

This document describes the deterministic release process for Claude Office.

## Version Numbering

We use semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes or significant new features
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes and minor improvements

## Pre-Release Checklist

Before creating a release:

1. [ ] All changes committed to `main` branch
2. [ ] Application runs without errors: `godot --headless --quit` (basic sanity check)
3. [ ] Manual testing completed (run the app, verify agents spawn/work/leave)
4. [ ] Version number updated in all locations (see below)

## Files Requiring Version Updates

When bumping the version, update these files:

| File | Location | Example |
|------|----------|---------|
| `project.godot` | `config/version` | `config/version="1.0.0"` |
| `export_presets.cfg` | macOS `short_version` and `version` | `application/short_version="1.0.0"` |

## Release Steps

### 1. Update Version Numbers

```bash
# Edit project.godot - update config/version
# Edit export_presets.cfg - update macOS version strings
```

### 2. Commit Changes

```bash
git add -A
git commit -m "Release v1.0.0

- Summary of major changes
- Additional notes

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### 3. Create Git Tag

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
```

### 4. Push to Remote

```bash
git push origin main
git push origin v1.0.0
```

### 5. Build Exports (Optional - for distributing binaries)

#### Prerequisites

1. Install Godot 4.5 export templates:
   - Open Godot Editor
   - Go to **Editor → Manage Export Templates**
   - Download templates for version 4.5

#### Build Commands

Using Godot CLI:

```bash
# Create builds directory
mkdir -p builds/linux builds/windows builds/macos

# Export Linux build
godot --headless --export-release "Linux" builds/linux/claude-office.x86_64

# Export Windows build
godot --headless --export-release "Windows" builds/windows/claude-office.exe

# Export macOS build
godot --headless --export-release "macOS" builds/macos/claude-office.dmg
```

Or using the Godot Editor:
1. Open project in Godot
2. Go to **Project → Export**
3. Select each preset and click **Export Project**

### 6. Create GitHub Release (Optional)

```bash
# Create release with built binaries
gh release create v1.0.0 \
  builds/linux/claude-office.x86_64 \
  builds/windows/claude-office.exe \
  builds/macos/claude-office.dmg \
  --title "Claude Office v1.0.0" \
  --notes "Release notes here"
```

## Export Presets

The `export_presets.cfg` file contains configurations for:

| Preset | Platform | Output Path |
|--------|----------|-------------|
| Linux | Linux x86_64 | `builds/linux/claude-office.x86_64` |
| Windows | Windows x86_64 | `builds/windows/claude-office.exe` |
| macOS | macOS Universal | `builds/macos/claude-office.dmg` |

## Quick Release Script

For convenience, here's a complete release script:

```bash
#!/bin/bash
set -e

VERSION=$1
if [ -z "$VERSION" ]; then
  echo "Usage: ./release.sh 1.0.0"
  exit 1
fi

echo "Releasing v$VERSION..."

# Verify working directory is clean (except version bumps)
if [ -n "$(git status --porcelain)" ]; then
  echo "Working directory not clean. Commit or stash changes first."
  exit 1
fi

# Create and push tag
git tag -a "v$VERSION" -m "Release v$VERSION"
git push origin main
git push origin "v$VERSION"

# Build exports (requires Godot CLI and export templates)
mkdir -p builds/linux builds/windows builds/macos
godot --headless --export-release "Linux" "builds/linux/claude-office.x86_64"
godot --headless --export-release "Windows" "builds/windows/claude-office.exe"
godot --headless --export-release "macOS" "builds/macos/claude-office.dmg"

echo "Release v$VERSION complete!"
echo "Binaries in builds/ directory"
```

## Troubleshooting

### Export templates not found

Download templates via Godot Editor: **Editor → Manage Export Templates → Download**

### macOS code signing errors

For unsigned development builds, set `codesign/codesign=1` (ad-hoc signing) in export_presets.cfg.
For distribution, you'll need an Apple Developer certificate.

### Windows builds fail

Ensure the Windows export template is installed. Cross-compilation from Linux requires the Windows template.
