# Terminal Integration (Linux)

This repo embeds a full terminal using **GodotXterm** (GDExtension).
The terminal furniture instantiates `Terminal` + `PTY` nodes and forks a local shell.

Add-on files live in:
- `addons/godot_xterm/` (GDExtension + themes + docs)
- `addons/godot_xterm/lib/` (native binaries per platform)

## Rebuilding GodotXterm (Linux)

If you need to rebuild the native binaries, run these steps from the project root:

1) Ensure third-party sources are present under:
   - `addons/godot_xterm/native/thirdparty/{godot-cpp,libuv,libtsm,node-pty}`
2) Build libuv (debug + release):
```
cd addons/godot_xterm/native/thirdparty/libuv
cmake -S . -B build/linux-x86_64-debug -DCMAKE_BUILD_TYPE=Debug -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE -DCMAKE_OSX_ARCHITECTURES=$(uname -m)
cmake --build build/linux-x86_64-debug --config Debug -j$(nproc)
cmake -S . -B build/linux-x86_64-release -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE -DCMAKE_OSX_ARCHITECTURES=$(uname -m)
cmake --build build/linux-x86_64-release --config Release -j$(nproc)
```
3) Build the extension (debug + release) for Godot 4.5:
```
cd addons/godot_xterm/native
LIBUV_BUILD_DIR=build/linux-x86_64-debug scons target=template_debug arch=$(uname -m) debug_symbols=yes api_version=4.5 generate_bindings=yes
LIBUV_BUILD_DIR=build/linux-x86_64-release scons target=template_release arch=$(uname -m) debug_symbols=no api_version=4.5 generate_bindings=yes
```

Outputs:
- `addons/godot_xterm/lib/libgodot-xterm.linux.template_debug.x86_64.so`
- `addons/godot_xterm/lib/libgodot-xterm.linux.template_release.x86_64.so`

Godot loads the extension via `project.godot`.

## Usage

- Add the Terminal furniture from the furniture shelf.
- Click inside the terminal area to focus (mouse selection is intentionally disabled).
- Type directly to the shell.

## Notes

- The legacy PTY + GDScript terminal (`native/pty/` + `scripts/TerminalEmulator.gd`) still exists
  but is no longer wired to the furniture.
- Only Linux x86_64 binaries are currently present in `addons/godot_xterm/lib`. Build other targets
  if you plan to export to macOS/Windows/Web.
