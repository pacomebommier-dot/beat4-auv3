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
for t in test_relay_delivery test_relay test_html_v28 test_set_config test_set_layout test_set_reset test_set test_active_cycles test_tempo_transition test_circuit_queue test_circuit_transport test_bpm_gesture test_reference_layout test_kick_continuity test_v054 test_v056 test_tempo_modes test_journal test_r10_midi_memory test_program test_beat4 test_transport test_songs_kick test_beat_gate test_layout; do
  "$CXX" "${FLAGS[@]}" "$ROOT/Tests/${t}.cpp" -o "$TMP/$t"
  "$TMP/$t"
done
