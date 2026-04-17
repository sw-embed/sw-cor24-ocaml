#!/usr/bin/env bash
#
# run-ocaml-interactive.sh -- Run an OCaml program with live stdin
#
# Usage: ./scripts/run-ocaml-interactive.sh <file.ml>
#
# Uses pv24t (host p-code interpreter) with the .ml source preloaded via
# -i so pv24t's stdin stays connected to the terminal. User keystrokes
# feed read_line/getc during execution. Mirrors sw-cor24-basic's
# demo-guess/demo-trek-adventure pattern.
#
# For canned/regression input, use run-ocaml.sh with OCAML_STDIN instead.
set -euo pipefail

ML="${1:?Usage: $0 <file.ml>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"

PV24T="$REPO_ROOT/../sw-cor24-pcode/target/release/pv24t"
if [ ! -x "$PV24T" ]; then PV24T="$(command -v pv24t 2>/dev/null || true)"; fi
if [ -z "$PV24T" ] || [ ! -x "$PV24T" ]; then
  echo "error: pv24t not found (expected at ../sw-cor24-pcode/target/release/pv24t)" >&2
  exit 1
fi

if [ ! -f "$BUILD_DIR/ocaml.p24" ]; then
  echo "error: build/ocaml.p24 not found. Run ./scripts/build.sh first." >&2
  exit 1
fi

"$PV24T" "$BUILD_DIR/ocaml.p24" -n 0 -i "$(cat "$ML")$(printf '\x04')"
