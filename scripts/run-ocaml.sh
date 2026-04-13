#!/usr/bin/env bash
#
# run-ocaml.sh -- Run an OCaml program on the COR24 interpreter
#
# Usage: ./scripts/run-ocaml.sh <file.ml> [max_instructions]
#
# Requires build/ocaml.bin (run ./scripts/build.sh first)
set -euo pipefail

ML="${1:?Usage: $0 <file.ml> [max_instructions]}"
MAX_INSTRS="${2:-500000000}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$REPO_ROOT/vendor/active.env"

PVM="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pvm.s"
BUILD_DIR="$REPO_ROOT/build"

COR24_RUN="$REPO_ROOT/vendor/sw-em24/$SW_EM24_VERSION/bin/cor24-run"
if [ ! -f "$COR24_RUN" ]; then COR24_RUN="$(command -v cor24-run 2>/dev/null || true)"; fi
if [ -z "$COR24_RUN" ]; then echo "error: cor24-run not found" >&2; exit 1; fi

if [ ! -f "$BUILD_DIR/ocaml.bin" ]; then
  echo "error: build/ocaml.bin not found. Run ./scripts/build.sh first." >&2
  exit 1
fi

CODE_PTR_ADDR=$(cat "$BUILD_DIR/code_ptr_addr.txt")
ML_INPUT=$(cat "$ML")

"$COR24_RUN" --run "$PVM" \
  --load-binary "$BUILD_DIR/ocaml.bin@0x010000" \
  --load-binary "$BUILD_DIR/code_ptr.bin@${CODE_PTR_ADDR}" \
  -u "${ML_INPUT}"$'\x04' --speed 0 -n "$MAX_INSTRS" 2>&1 | \
  grep -v '^\[' | grep -v '^Assembled' | grep -v '^Running' | \
  grep -v '^Executed' | grep -v '^Loaded' | grep -v '^PVM OK' | \
  grep -v '^UART output: PVM OK' | grep -v '^CPU halted' | \
  grep -v '^$' | grep -v '^HALT$'
