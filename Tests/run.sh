#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXX="${CXX:-c++}"
FLAGS=(-std=c++17 -Wall -Wextra -Werror -pedantic)
if [[ "${BEAT4_SANITIZE:-0}" == 1 ]]; then
  FLAGS+=(-O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined)
fi
for t in test_beat4 test_transport test_songs_kick test_beat_gate test_layout test_v054 test_v056; do
  "$CXX" "${FLAGS[@]}" "$ROOT/Tests/${t}.cpp" -o "$TMP/$t"
  "$TMP/$t"
done
