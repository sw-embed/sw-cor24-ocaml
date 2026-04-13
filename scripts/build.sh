#!/usr/bin/env bash
#
# build.sh -- Build the OCaml interpreter for COR24
#
# Compiles src/ocaml.pas through the full Pascal toolchain:
#   .pas -> p24p -> .spc -> pl24r (link) -> pa24r -> .p24 -> relocate -> .bin
#
# Output: build/ocaml.bin (p-code binary, loadable by PVM)
#
# Usage: ./scripts/build.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$REPO_ROOT/vendor/active.env"

P24P_S="$REPO_ROOT/vendor/sw-pascal/$SW_PASCAL_VERSION/bin/p24p.s"
RUNTIME="$REPO_ROOT/vendor/sw-pascal/$SW_PASCAL_VERSION/bin/runtime.spc"
PVM="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pvm.s"
PL24R="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pl24r"
PA24R="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pa24r"

COR24_RUN="$REPO_ROOT/vendor/sw-em24/$SW_EM24_VERSION/bin/cor24-run"
if [ ! -f "$COR24_RUN" ]; then COR24_RUN="$(command -v cor24-run 2>/dev/null || true)"; fi
if [ -z "$COR24_RUN" ]; then echo "error: cor24-run not found" >&2; exit 1; fi

SRC="$REPO_ROOT/src/ocaml.pas"
BUILD_DIR="$REPO_ROOT/build"
MAX_INSTRS="${1:-500000000}"

mkdir -p "$BUILD_DIR"

echo "Building OCaml interpreter for COR24..."

# Resolve code_ptr address from PVM
CODE_PTR_ADDR=$("$COR24_RUN" --run "$PVM" -e code_ptr --speed 0 -n 0 2>&1 | \
  grep "Entry point:" | sed 's/.*@ //')
if [ -z "$CODE_PTR_ADDR" ]; then echo "Error: could not resolve code_ptr" >&2; exit 1; fi
echo "$CODE_PTR_ADDR" > "$BUILD_DIR/code_ptr_addr.txt"

# Step 1: Compile Pascal to .spc
echo "  [1/5] Compiling Pascal -> .spc (p24p)..."
SPC_OUTPUT=$("$COR24_RUN" --run "$P24P_S" -u "$(cat "$SRC")"$'\x04' --speed 0 -n "$MAX_INSTRS" 2>&1 | \
  grep -v '^\[UART' | sed 's/^UART output: //')

if ! echo "$SPC_OUTPUT" | grep -q "; OK"; then
  echo "Pascal compilation failed:" >&2
  echo "$SPC_OUTPUT" | grep -i "error" >&2
  exit 1
fi

echo "$SPC_OUTPUT" | sed -n '/^\.module/,/^\.endmodule/p' > "$BUILD_DIR/ocaml.spc"
echo "  [1/5] ok"

# Step 2: Link with runtime
echo "  [2/5] Linking with runtime (pl24r)..."
"$PL24R" "$RUNTIME" "$BUILD_DIR/ocaml.spc" -o "$BUILD_DIR/ocaml_linked.spc" 2>/dev/null
echo "  [2/5] ok"

# Step 3: Assemble to .p24
echo "  [3/5] Assembling -> .p24 (pa24r)..."
"$PA24R" "$BUILD_DIR/ocaml_linked.spc" -o "$BUILD_DIR/ocaml.p24" 2>/dev/null
echo "  [3/5] ok"

# Step 4: Relocate for load address
echo "  [4/5] Relocating for 0x010000..."
python3 "$SCRIPT_DIR/relocate_p24.py" "$BUILD_DIR/ocaml.p24" 0x010000 >/dev/null
echo "  [4/5] ok"

# Step 5: Create code_ptr patch
echo "  [5/5] Creating code_ptr patch..."
printf '\x00\x00\x01' > "$BUILD_DIR/code_ptr.bin"
echo "  [5/5] ok"

echo ""
echo "Build complete:"
echo "  Binary:    $BUILD_DIR/ocaml.bin"
echo "  Code ptr:  $BUILD_DIR/code_ptr.bin @ $CODE_PTR_ADDR"
echo "  PVM:       $PVM"
echo ""
echo "Run with:"
echo "  cor24-run --run $PVM \\"
echo "    --load-binary $BUILD_DIR/ocaml.bin@0x010000 \\"
echo "    --load-binary $BUILD_DIR/code_ptr.bin@$CODE_PTR_ADDR \\"
echo "    -u '<ocaml source>\\x04' --speed 0 -n 500000000"
