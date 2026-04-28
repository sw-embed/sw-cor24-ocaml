#!/usr/bin/env bash
#
# run-ocaml.sh -- Run an OCaml program on the COR24 interpreter
#
# Usage: ./scripts/run-ocaml.sh <file.ml> [more.ml ...] [max_instructions]
#
# Requires build/ocaml.p24m and build/pvm.bin (run ./scripts/build.sh first)
#
# If the env var OCAML_STDIN is set, its contents are appended to the UART
# input buffer after the source's EOT terminator. This feeds runtime
# getc/read_line calls (used by interactive demos) without blocking on a
# live terminal.
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <file.ml> [more.ml ...] [max_instructions]" >&2
  exit 1
fi

MAX_INSTRS="3000000000"
ARGS=("$@")
LAST_INDEX=$((${#ARGS[@]} - 1))
if [[ "${ARGS[$LAST_INDEX]}" != *.ml ]]; then
  MAX_INSTRS="${ARGS[$LAST_INDEX]}"
  unset 'ARGS[$LAST_INDEX]'
fi
if [ "${#ARGS[@]}" -lt 1 ]; then
  echo "Usage: $0 <file.ml> [more.ml ...] [max_instructions]" >&2
  exit 1
fi

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

module_name_for_file() {
  local path base stem first rest
  path="$1"
  base="$(basename "$path")"
  stem="${base%.ml}"
  first="${stem:0:1}"
  rest="${stem:1}"
  printf '%s%s' "$(tr '[:lower:]' '[:upper:]' <<< "$first")" "$rest"
}

source_for_repl() {
  awk '
    function emit_logical(line) {
      if (line ~ /^[[:space:]]*$/) return
      # Continuation lines: leading whitespace (indented body of a multi-line
      # let/match/if), `|` arm, or `and` (mutual-rec binding). All fold into
      # the current logical line so the REPL sees one statement, not five.
      if (line ~ /^[[:space:]]+/ || line ~ /^and[[:space:]]/) {
        if (have) {
          sub(/^[[:space:]]*/, "", line)
          current = current " " line
        } else {
          current = line
          have = 1
        }
        return
      }
      if (have) print current
      current = line
      have = 1
    }
    {
      out = ""
      in_string = 0
      esc = 0
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        n = substr($0, i + 1, 1)
        if (depth > 0) {
          if (c == "(" && n == "*") {
            depth++
            i++
          } else if (c == "*" && n == ")") {
            depth--
            i++
          }
          continue
        }
        if (in_string) {
          out = out c
          if (esc) {
            esc = 0
          } else if (c == "\\") {
            esc = 1
          } else if (c == "\"") {
            in_string = 0
          }
          continue
        }
        if (c == "\"") {
          out = out c
          in_string = 1
          continue
        }
        if (c == "(" && n == "*") {
          depth = 1
          i++
          continue
        }
        out = out c
      }
      emit_logical(out)
    }
    END {
      if (have) print current
      if (depth > 0) exit 2
    }
  ' "$1"
}

CODE_PTR=$(cat "$BUILD_DIR/code_ptr_addr.txt")
HEAP_LIMIT=$(cat "$BUILD_DIR/heap_limit_addr.txt")
ML_INPUT=""
if [ "${#ARGS[@]}" -eq 1 ]; then
  ML="${ARGS[0]}"
  if [ ! -f "$ML" ]; then
    echo "error: source file not found: $ML" >&2
    exit 1
  fi
  ML_INPUT="$(source_for_repl "$ML")"
else
  for ML in "${ARGS[@]}"; do
    if [ ! -f "$ML" ]; then
      echo "error: source file not found: $ML" >&2
      exit 1
    fi
    MODULE_NAME="$(module_name_for_file "$ML")"
    ML_INPUT+="let __module = \"$MODULE_NAME\""$'\n'
    ML_INPUT+="$(source_for_repl "$ML")"$'\n'
  done
fi
ML_INPUT="${ML_INPUT//\\/\\\\}"

UART_INPUT="${ML_INPUT}"$'\x04'"${OCAML_STDIN:-}"

"$COR24_RUN" --load-binary "$BUILD_DIR/pvm.bin@0" \
  --load-binary "$BUILD_DIR/ocaml.p24m@0x040000" \
  --patch "0x${CODE_PTR}=0x040000" \
  --patch "0x${HEAP_LIMIT}=0x03F000" \
  --entry 0 -u "${UART_INPUT}" --speed 0 -n "$MAX_INSTRS" 2>&1 | \
  awk '
    /^UART output:/ { in_out = 1; sub(/^UART output: /, ""); }
    /^Executed / { in_out = 0 }
    in_out { print }
  ' | tr -d '\r' | sed '1s/^PVM OK$//; /^$/d; /^HALT$/d'
