#!/usr/bin/env bash
# Compile the user's own authorized game.wasm locally without a GitHub Actions artifact.
# Keep both game.wasm and the serialized AOT output outside the public repository.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: WASMTIME_BIN=/path/to/wasmtime $0 /path/to/game.wasm [private-output.cwasm]" >&2
  exit 2
fi

wasm="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
if [[ ! -s "$wasm" ]]; then
  echo "ERROR: game.wasm is missing or empty: $wasm" >&2
  exit 2
fi
if [[ -z "${WASMTIME_BIN:-}" || ! -x "$WASMTIME_BIN" ]]; then
  echo "ERROR: Set WASMTIME_BIN to an executable Wasmtime 49.0.2 binary." >&2
  exit 2
fi

# This is the known, previously audited engine snapshot. Stop on a mismatch;
# do not silently compile a different or partially copied file.
expected="11ca8d2c04c5e843d18ff4aea4899d72c86973c6b031df334e67c446b2ae83e0"
actual="$(shasum -a 256 "$wasm" | awk '{print $1}')"
if [[ "$actual" != "$expected" ]]; then
  echo "ERROR: game.wasm SHA-256 mismatch." >&2
  echo "Expected: $expected" >&2
  echo "Actual:   $actual" >&2
  echo "No compilation was started. Confirm this is the audited engine version." >&2
  exit 3
fi
echo "PASS: game.wasm SHA-256 matches the audited snapshot."

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/../.." rev-parse --show-toplevel)"
if [[ $# -eq 2 ]]; then
  output="$2"
else
  output="${TMPDIR:-/tmp}/playgta5-private-aot/gta-ios.cwasm"
fi
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
case "$output" in
  "$repo_root"/*)
    echo "ERROR: Output must be outside the Git repository to avoid committing proprietary engine code." >&2
    exit 4
    ;;
esac

echo "Using Wasmtime: $("$WASMTIME_BIN" --version)"
echo "Private AOT output: $output"
bash "$script_dir/aot_compile_wasmtime.sh" "$wasm" "$output"
echo "AOT compilation completed. This is not a playable IPA; host imports, runtime integration and Metal rendering remain required."
