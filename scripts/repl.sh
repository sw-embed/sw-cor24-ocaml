#!/usr/bin/env bash
#
# repl.sh -- Launch interactive OCaml REPL on COR24 emulator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"

if [ ! -f "$BUILD_DIR/ocaml.p24m" ]; then
  echo "error: build/ocaml.p24m not found. Run 'just build' first." >&2
  exit 1
fi

CODE_PTR=$(cat "$BUILD_DIR/code_ptr_addr.txt")

cat <<'EOF'
OCaml REPL on COR24 -- type expressions, Ctrl-C to exit
Try: 42
     let x = 41 + 1 in x
     let f = fun x -> x * 2 in f 21
     let rec fact = fun n -> if n = 0 then 1 else n * fact (n - 1) in fact 5
     let add = fun x y -> x + y in add 20 22
     print_int 99
     led_on (); print_int 1
     putc 72; putc 105; putc 10
----------------------------------------
EOF

cor24-run --load-binary "$BUILD_DIR/pvm.bin@0" \
  --load-binary "$BUILD_DIR/ocaml.p24m@0x010000" \
  --patch "0x${CODE_PTR}=0x010000" \
  --entry 0 --speed 0 -n 2000000000 --terminal
