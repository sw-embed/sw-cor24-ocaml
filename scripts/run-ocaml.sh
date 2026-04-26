#!/usr/bin/env bash
#
# run-ocaml.sh -- Run an OCaml program on the COR24 interpreter
#
# Usage: ./scripts/run-ocaml.sh <file.ml> [max_instructions]
#
# Requires build/ocaml.p24m and build/pvm.bin (run ./scripts/build.sh first)
#
# If the env var OCAML_STDIN is set, its contents are appended to the UART
# input buffer after the source's EOT terminator. This feeds runtime
# getc/read_line calls (used by interactive demos) without blocking on a
# live terminal.
set -euo pipefail

ML="${1:?Usage: $0 <file.ml> [max_instructions]}"
MAX_INSTRS="${2:-500000000}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"

COR24_RUN="$REPO_ROOT/vendor/sw-em24/$(. "$REPO_ROOT/vendor/active.env" && echo "$SW_EM24_VERSION")/bin/cor24-run"
if [ ! -f "$COR24_RUN" ]; then COR24_RUN="$(command -v cor24-run 2>/dev/null || true)"; fi
if [ -z "$COR24_RUN" ]; then echo "error: cor24-run not found" >&2; exit 1; fi

if [ ! -f "$BUILD_DIR/ocaml.p24m" ]; then
  echo "error: build/ocaml.p24m not found. Run ./scripts/build.sh first." >&2
  exit 1
fi

CODE_PTR=$(cat "$BUILD_DIR/code_ptr_addr.txt")
ML_INPUT=$(cat "$ML")
ML_INPUT="${ML_INPUT//\\/\\\\}"

UART_INPUT="${ML_INPUT}"$'\x04'"${OCAML_STDIN:-}"

"$COR24_RUN" --load-binary "$BUILD_DIR/pvm.bin@0" \
  --load-binary "$BUILD_DIR/ocaml.p24m@0x010000" \
  --patch "0x${CODE_PTR}=0x010000" \
  --entry 0 -u "${UART_INPUT}" --speed 0 -n "$MAX_INSTRS" 2>&1 | \
  awk '
    /^UART output:/ { in_out = 1; sub(/^UART output: /, ""); }
    /^Executed / { in_out = 0 }
    in_out { print }
  ' | tr -d '\r' | sed '1s/^PVM OK$//; /^$/d; /^HALT$/d'
