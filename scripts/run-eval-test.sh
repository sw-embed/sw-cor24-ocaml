#!/usr/bin/env bash
# run-eval-test.sh -- Compile and run the evaluator test with OCaml source input
# Usage: ./scripts/run-eval-test.sh <file.ml> [max_instructions]
set -euo pipefail

ML="${1:?Usage: $0 <file.ml>}"
MAX_INSTRS="${2:-200000000}"

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

EVAL_PAS="$REPO_ROOT/tests/test_eval.pas"
TMP="/tmp/p24p_evaltest_$$"
mkdir -p "$TMP"
trap "rm -rf $TMP" EXIT

CODE_PTR_ADDR=$("$COR24_RUN" --run "$PVM" -e code_ptr --speed 0 -n 0 2>&1 | \
  grep "Entry point:" | sed 's/.*@ //')
if [ -z "$CODE_PTR_ADDR" ]; then echo "Error: could not resolve code_ptr" >&2; exit 1; fi

SPC_OUTPUT=$("$COR24_RUN" --run "$P24P_S" -u "$(cat "$EVAL_PAS")"$'\x04' --speed 0 -n "$MAX_INSTRS" 2>&1 | \
  grep -v '^\[UART' | sed 's/^UART output: //')
if ! echo "$SPC_OUTPUT" | grep -q "; OK"; then
  echo "Pascal compilation failed:" >&2
  echo "$SPC_OUTPUT" | grep -i "error" >&2
  exit 1
fi
echo "$SPC_OUTPUT" | sed -n '/^\.module/,/^\.endmodule/p' > "$TMP/test_eval.spc"
"$PL24R" "$RUNTIME" "$TMP/test_eval.spc" -o "$TMP/test_eval_linked.spc" 2>/dev/null
"$PA24R" "$TMP/test_eval_linked.spc" -o "$TMP/test_eval.p24" 2>/dev/null
python3 "$SCRIPT_DIR/relocate_p24.py" "$TMP/test_eval.p24" 0x010000 >/dev/null

ML_INPUT=$(cat "$ML")
printf '\x00\x00\x01' > "$TMP/code_ptr.bin"
"$COR24_RUN" --run "$PVM" \
  --load-binary "$TMP/test_eval.bin@0x010000" \
  --load-binary "$TMP/code_ptr.bin@${CODE_PTR_ADDR}" \
  -u "${ML_INPUT}"$'\x04' --speed 0 -n "$MAX_INSTRS" 2>&1 | \
  grep -v '^\[' | grep -v '^Assembled' | grep -v '^Running' | \
  grep -v '^Executed' | grep -v '^Loaded' | grep -v '^PVM OK' | \
  grep -v '^UART output: PVM OK' | grep -v '^CPU halted' | \
  grep -v '^$' | grep -v '^HALT$'
