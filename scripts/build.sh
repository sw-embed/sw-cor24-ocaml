#!/usr/bin/env bash
#
# build.sh -- Build the OCaml interpreter for COR24
#
# Module-mode pipeline (matches sw-cor24-basic):
#   .pas -> p24p (module mode) -> .spc
#   pl24r .spc runtime.spc -> linked.spc   (source-level link with Pascal runtime)
#   pa24r linked.spc -> .p24               (single linked module)
#   cor24-run --assemble pvm.s -> pvm.bin  (for cor24-run/embedded path)
#
# build/ocaml.p24 is a single linked module. Both pv24t (host p-code
# interpreter, used for interactive demos) and cor24-run (emulator, for
# board/web demos) can load it.
#
# Usage: ./scripts/build.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$REPO_ROOT/vendor/active.env"

P24P_S="$REPO_ROOT/vendor/sw-pascal/$SW_PASCAL_VERSION/bin/p24p.s"
RUNTIME_SPC="$REPO_ROOT/vendor/sw-pascal/$SW_PASCAL_VERSION/bin/runtime.spc"
PVM="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pvm.s"
PA24R="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pa24r"
PL24R="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pl24r"
P24LOAD="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/p24-load"

COR24_RUN="$REPO_ROOT/vendor/sw-em24/$SW_EM24_VERSION/bin/cor24-run"
if [ ! -f "$COR24_RUN" ]; then COR24_RUN="$(command -v cor24-run 2>/dev/null || true)"; fi
if [ -z "$COR24_RUN" ]; then echo "error: cor24-run not found" >&2; exit 1; fi

SRC="$REPO_ROOT/src/ocaml.pas"
BUILD_DIR="$REPO_ROOT/build"
MAX_INSTRS="${1:-3000000000}"

mkdir -p "$BUILD_DIR"

echo "Building OCaml interpreter for COR24 (module mode)..."

echo "  [1/4] Compiling Pascal -> .spc (p24p)..."
SPC_OUTPUT=$("$COR24_RUN" --run "$P24P_S" -u "$(cat "$SRC")"$'\x04' --speed 0 -t 120 -n "$MAX_INSTRS" 2>&1 | \
  grep -v '^\[UART' | sed 's/^UART output: //')

if [[ "$SPC_OUTPUT" != *"; OK"* ]]; then
  echo "Pascal compilation failed:" >&2
  echo "$SPC_OUTPUT" | grep -i "error" >&2
  exit 1
fi

echo "$SPC_OUTPUT" | sed -n '/^\.module/,/^\.endmodule/p' > "$BUILD_DIR/ocaml.spc"
[ -s "$BUILD_DIR/ocaml.spc" ] || { echo "error: empty .spc output (expected .module/.endmodule block)" >&2; exit 1; }
echo "  [1/4] ok ($(wc -l < "$BUILD_DIR/ocaml.spc") lines)"

echo "  [2/4] Linking with Pascal runtime (pl24r)..."
"$PL24R" "$BUILD_DIR/ocaml.spc" "$RUNTIME_SPC" -o "$BUILD_DIR/ocaml_linked.spc" 2>/dev/null
echo "  [2/4] ok"

echo "  [3/5] Assembling -> .p24 (pa24r)..."
"$PA24R" "$BUILD_DIR/ocaml_linked.spc" -o "$BUILD_DIR/ocaml.p24" 2>/dev/null
echo "  [3/5] ok"

echo "  [4/5] Relocating -> .p24m (p24-load --load-addr 0x010000)..."
"$P24LOAD" --load-addr 0x010000 "$BUILD_DIR/ocaml.p24" -o "$BUILD_DIR/ocaml.p24m" 2>/dev/null
echo "  [4/5] ok"

echo "  [5/5] Assembling PVM (for cor24-run/embedded path)..."
PVM_DIR="$(dirname "$PVM")"
(cd "$PVM_DIR" && "$COR24_RUN" --assemble "$(basename "$PVM")" "$BUILD_DIR/pvm.bin" "$BUILD_DIR/pvm.lst" >/dev/null 2>&1)
CODE_PTR=$(grep -A1 "code_ptr:" "$BUILD_DIR/pvm.lst" | tail -1 | awk '{print $1}' | tr -d ':')
if [ -z "$CODE_PTR" ]; then
  echo "Error: could not resolve code_ptr from PVM listing" >&2
  exit 1
fi
echo "$CODE_PTR" > "$BUILD_DIR/code_ptr_addr.txt"
echo "  [5/5] ok (code_ptr @ 0x$CODE_PTR)"

echo ""
echo "Build complete:"
echo "  ocaml.p24  (base 0, for pv24t / interactive demos)"
echo "  ocaml.p24m (relocated to 0x010000, for cor24-run / regression / embedded)"
echo "  pvm.bin    (for cor24-run path)"
echo "  Code ptr:  0x$CODE_PTR"
