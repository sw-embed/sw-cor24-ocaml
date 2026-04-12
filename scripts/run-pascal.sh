#!/usr/bin/env bash
#
# run-pascal.sh -- Compile and run a Pascal program through the full
# p24p toolchain using vendored tools.
#
# Pipeline: .pas -> p24p -> .spc -> pl24r (link) -> pa24r -> .p24 -> pvm.s
#
# Usage: ./scripts/run-pascal.sh <file.pas> [max_instructions]
set -euo pipefail

PAS="${1:?Usage: $0 <file.pas> [max_instructions]}"
MAX_INSTRS="${2:-50000000}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Load vendored tool versions ---
. "$REPO_ROOT/vendor/active.env"

# --- Tool paths (vendored) ---
P24P_S="$REPO_ROOT/vendor/sw-pascal/$SW_PASCAL_VERSION/bin/p24p.s"
RUNTIME="$REPO_ROOT/vendor/sw-pascal/$SW_PASCAL_VERSION/bin/runtime.spc"
PVM="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pvm.s"
PL24R="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pl24r"
PA24R="$REPO_ROOT/vendor/sw-pcode/$SW_PCODE_VERSION/bin/pa24r"

# cor24-run: prefer vendored, fall back to system
COR24_RUN="$REPO_ROOT/vendor/sw-em24/$SW_EM24_VERSION/bin/cor24-run"
if [ ! -f "$COR24_RUN" ]; then
    COR24_RUN="$(command -v cor24-run 2>/dev/null || true)"
fi
if [ -z "$COR24_RUN" ]; then
    echo "error: cor24-run not found (vendored or system)" >&2
    exit 1
fi

# --- Verify tools exist ---
for tool in "$P24P_S" "$RUNTIME" "$PVM" "$PL24R" "$PA24R"; do
    if [ ! -f "$tool" ]; then
        echo "error: missing tool: $tool" >&2
        echo "       run: ./scripts/vendor-fetch.sh" >&2
        exit 1
    fi
done

NAME=$(basename "$PAS" .pas)
TMP="/tmp/p24p_ocaml_$$"
mkdir -p "$TMP"
trap "rm -rf $TMP" EXIT

# Resolve code_ptr address dynamically from PVM
CODE_PTR_ADDR=$("$COR24_RUN" --run "$PVM" -e code_ptr --speed 0 -n 0 2>&1 | \
  grep "Entry point:" | sed 's/.*@ //')
if [ -z "$CODE_PTR_ADDR" ]; then
  echo "Error: could not resolve code_ptr address from PVM" >&2
  exit 1
fi

# Step 1: Compile Pascal to .spc
SPC_OUTPUT=$("$COR24_RUN" --run "$P24P_S" -u "$(cat "$PAS")"$'\x04' --speed 0 -n 50000000 2>&1 | \
  grep -v '^\[UART' | sed 's/^UART output: //')

if ! echo "$SPC_OUTPUT" | grep -q "; OK"; then
  echo "Compilation failed:" >&2
  echo "$SPC_OUTPUT" | grep "error" >&2
  exit 1
fi

echo "$SPC_OUTPUT" | sed -n '/^\.module/,/^\.endmodule/p' > "$TMP/$NAME.spc"

# Step 2: Link with runtime
"$PL24R" "$RUNTIME" "$TMP/$NAME.spc" -o "$TMP/${NAME}_linked.spc" 2>/dev/null

# Step 3: Assemble to .p24
"$PA24R" "$TMP/${NAME}_linked.spc" -o "$TMP/$NAME.p24" 2>/dev/null

# Step 4: Relocate for load address 0x010000
python3 "$SCRIPT_DIR/relocate_p24.py" "$TMP/$NAME.p24" 0x010000 >/dev/null

# Step 5: Create code_ptr patch (0x010000 LE)
printf '\x00\x00\x01' > "$TMP/code_ptr.bin"

# Step 6: Run on PVM
"$COR24_RUN" --run "$PVM" \
  --load-binary "$TMP/$NAME.bin@0x010000" \
  --load-binary "$TMP/code_ptr.bin@${CODE_PTR_ADDR}" \
  --terminal --speed 0 -n "$MAX_INSTRS" 2>&1 | \
  grep -v '^\[' | grep -v '^Assembled' | grep -v '^Running' | \
  grep -v '^Executed' | grep -v '^Loaded' | grep -v '^PVM OK' | \
  grep -v '^$' | grep -v '^HALT$'
