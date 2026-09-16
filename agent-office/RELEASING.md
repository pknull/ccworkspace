# Release Process

This document describes the release process for Inference Inc.

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

## Release Steps

### 1. Update Version Numbers

```bash
# Edit project.godot - update config/version
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

### 5. Build the Linux Export

Reviewed release artifacts are currently Linux x86-64 only. Windows and macOS
publishing remains paused until the patched native terminal extension is built
and tested on those platforms.

#### Prerequisites

1. Install Godot 4.5 export templates:
   - Open Godot Editor
   - Go to **Editor → Manage Export Templates**
   - Download templates for version 4.5

#### Build Commands

Using Godot CLI:

```bash
python3 -m pip install scons==4.10.1
./scripts/build_godot_xterm_linux.sh
mkdir -p builds/linux
godot --headless --export-release "Linux" builds/linux/inference-inc.x86_64
```

Godot places `libgodot-xterm.linux.template_release.x86_64.so` beside the
executable. It is required at runtime and must be distributed with the
executable:

```bash
cd builds/linux
zip -9 ../inference-inc-v1.0.0-linux-x86_64.zip \
  inference-inc.x86_64 \
  libgodot-xterm.linux.template_release.x86_64.so
cd ../..
```

Or using the Godot Editor:
1. Open project in Godot
2. Go to **Project → Export**
3. Select the Linux preset and click **Export Project**

### 6. Create GitHub Release (Optional)

```bash
# Create release with built binaries
gh release create v1.0.0 \
  builds/inference-inc-v1.0.0-linux-x86_64.zip \
  --title "Inference Inc. v1.0.0" \
  --notes "Release notes here"
```

## Export Presets

The `export_presets.cfg` file contains configurations for:

| Preset | Platform | Output Path |
|--------|----------|-------------|
| Linux | Linux x86_64 | `builds/linux/inference-inc.x86_64` |

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
python3 -m pip install scons==4.10.1
./scripts/build_godot_xterm_linux.sh
mkdir -p builds/linux
godot --headless --export-release "Linux" "builds/linux/inference-inc.x86_64"
test -f builds/linux/libgodot-xterm.linux.template_release.x86_64.so
(
  cd builds/linux
  zip -9 "../inference-inc-v${VERSION}-linux-x86_64.zip" \
    inference-inc.x86_64 \
    libgodot-xterm.linux.template_release.x86_64.so
)

echo "Release v$VERSION complete!"
echo "Archive in builds/ directory"
```

## Troubleshooting

### Export templates not found

Download templates via Godot Editor: **Editor → Manage Export Templates → Download**
