#!/usr/bin/env bash
#
# build.sh -- Build the OCaml interpreter for COR24
#
# Uses the multi-unit pipeline:
#   .pas -> p24p (unit mode) -> .spc -> pa24r -> .p24
#   p24-load user.p24 p24p_rt.p24 -> .p24m
#   cor24-run --assemble pvm.s -> pvm.bin
#
# Output: build/ocaml.p24m + build/pvm.bin
#
# Usage: ./scripts/build.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$REPO_ROOT/vendor/active.env"

P24P_S="$REPO_ROOT/vendor/sw-pascal/$SW_PASCAL_VERSION/bin/p24p.s"
RT_P24="$REPO_ROOT/vendor/sw-pascal/$SW_PASCAL_VERSION/bin/p24p_rt.p24"
PVM="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pvm.s"
PA24R="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pa24r"
P24LOAD="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/p24-load"

COR24_RUN="$REPO_ROOT/vendor/sw-em24/$SW_EM24_VERSION/bin/cor24-run"
if [ ! -f "$COR24_RUN" ]; then COR24_RUN="$(command -v cor24-run 2>/dev/null || true)"; fi
if [ -z "$COR24_RUN" ]; then echo "error: cor24-run not found" >&2; exit 1; fi

SRC="$REPO_ROOT/src/ocaml.pas"
BUILD_DIR="$REPO_ROOT/build"
MAX_INSTRS="${1:-500000000}"

mkdir -p "$BUILD_DIR"

echo "Building OCaml interpreter for COR24 (unit mode)..."

# Step 1: Compile Pascal to .spc (unit mode)
echo "  [1/5] Compiling Pascal -> .spc (p24p, unit mode)..."
SPC_OUTPUT=$("$COR24_RUN" --run "$P24P_S" -u "$(cat "$SRC")"$'\x04' --speed 0 -n "$MAX_INSTRS" 2>&1 | \
  grep -v '^\[UART' | sed 's/^UART output: //')

if ! echo "$SPC_OUTPUT" | grep -q "; OK"; then
  echo "Pascal compilation failed:" >&2
  echo "$SPC_OUTPUT" | grep -i "error" >&2
  exit 1
fi

echo "$SPC_OUTPUT" | sed -n '/^\.unit/,/^\.endunit/p' > "$BUILD_DIR/ocaml.spc"
echo "  [1/5] ok"

# Step 2: Assemble user unit to .p24 (v2)
echo "  [2/5] Assembling -> .p24 (pa24r)..."
"$PA24R" "$BUILD_DIR/ocaml.spc" -o "$BUILD_DIR/ocaml.p24" 2>/dev/null
echo "  [2/5] ok"

# Step 3: Link units with p24-load
echo "  [3/5] Linking units (p24-load)..."
"$P24LOAD" "$BUILD_DIR/ocaml.p24" "$RT_P24" -o "$BUILD_DIR/ocaml.p24m" 2>/dev/null
echo "  [3/5] ok"

# Step 4: Pre-assemble PVM
echo "  [4/5] Assembling PVM..."
PVM_DIR="$(dirname "$PVM")"
(cd "$PVM_DIR" && "$COR24_RUN" --assemble "$(basename "$PVM")" "$BUILD_DIR/pvm.bin" "$BUILD_DIR/pvm.lst" >/dev/null 2>&1)
CODE_PTR=$(grep -A1 "code_ptr:" "$BUILD_DIR/pvm.lst" | tail -1 | awk '{print $1}' | tr -d ':')
if [ -z "$CODE_PTR" ]; then
  echo "Error: could not resolve code_ptr from PVM listing" >&2
  exit 1
fi
echo "$CODE_PTR" > "$BUILD_DIR/code_ptr_addr.txt"
echo "  [4/5] ok (code_ptr @ 0x$CODE_PTR)"

# Step 5: Done
echo "  [5/5] Build artifacts ready"

echo ""
echo "Build complete:"
echo "  Image:     $BUILD_DIR/ocaml.p24m"
echo "  PVM:       $BUILD_DIR/pvm.bin"
echo "  Code ptr:  0x$CODE_PTR"
echo ""
echo "Run with:"
echo "  cor24-run --load-binary $BUILD_DIR/pvm.bin@0 \\"
echo "    --load-binary $BUILD_DIR/ocaml.p24m@0x010000 \\"
echo "    --patch \"0x${CODE_PTR}=0x010000\" \\"
echo "    --entry 0 --speed 0 -n 500000000 --terminal"
