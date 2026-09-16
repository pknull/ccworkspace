#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NATIVE="$ROOT/addons/godot_xterm/native"
THIRDPARTY="$NATIVE/thirdparty"

clone_at() {
  local repository="$1" commit="$2" destination="$3"
  if [[ -d "$destination/.git" ]] && [[ "$(git -C "$destination" rev-parse HEAD)" == "$commit" ]]; then
    return
  fi
  rm -rf "$destination"
  git clone --filter=blob:none --no-checkout "$repository" "$destination"
  git -C "$destination" checkout --detach "$commit"
}

mkdir -p "$THIRDPARTY"
clone_at https://github.com/godotengine/godot-cpp.git e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77 "$THIRDPARTY/godot-cpp"
clone_at https://github.com/libuv/libuv.git 4839e28d509b3c11fc86904e12abaa7212545fcf "$THIRDPARTY/libuv"
clone_at https://github.com/Aetf/libtsm.git 9e9cd90b2ffade2228aa3378a5c9718eba554bfe "$THIRDPARTY/libtsm"

cmake \
  -S "$THIRDPARTY/libuv" \
  -B "$THIRDPARTY/libuv/build-release" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
cmake --build "$THIRDPARTY/libuv/build-release" --config Release --parallel

cd "$NATIVE"
LIBUV_BUILD_DIR=build-release scons target=template_release arch=x86_64 debug_symbols=no
LIBUV_BUILD_DIR=build-release scons target=template_debug arch=x86_64 debug_symbols=no
