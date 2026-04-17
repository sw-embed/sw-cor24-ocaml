# sw-cor24-ocaml -- OCaml interpreter for COR24
# Build system using vendored Pascal toolchain

# Fetch vendored tools from upstream repos
vendor-fetch:
    ./scripts/vendor-fetch.sh

# Check that vendored tools are present
vendor-check:
    ./scripts/vendor-fetch.sh --check

# Run a Pascal program through the full toolchain
# Usage: just run-pascal tests/hello.pas
run-pascal file:
    ./scripts/run-pascal.sh {{file}}

# Run regression tests
test:
    REG_RS_DATA_DIR=work/reg-rs reg-rs run -v

# Run regression tests (quiet, for CI)
test-quiet:
    REG_RS_DATA_DIR=work/reg-rs reg-rs run -q

# Show regression test report
test-report:
    REG_RS_DATA_DIR=work/reg-rs reg-rs report -vv

# Build the OCaml interpreter
build:
    ./scripts/build.sh

# Run an OCaml program
# Usage: just run tests/eval_fact.ml
run file:
    ./scripts/run-ocaml.sh {{file}}

# Run the target demo: 42
demo:
    @echo 'let x = 41 + 1 in print_int x' > /tmp/ocaml_demo.ml
    @./scripts/run-ocaml.sh /tmp/ocaml_demo.ml
    @rm -f /tmp/ocaml_demo.ml

# Run factorial demo
demo-fact:
    @./scripts/run-ocaml.sh tests/eval_fact.ml

# Run LED blink demo (board I/O)
demo-led:
    @./scripts/run-ocaml.sh tests/demo_led_blink.ml

# Run lists and pairs demo (sum, length, map, fst/snd, List.rev)
demo-lists:
    @./scripts/run-ocaml.sh tests/demo_lists_pairs.ml

# Run pattern matching demo (sum/length/map/filter/safe_div with match)
demo-match:
    @./scripts/run-ocaml.sh tests/demo_patterns.ml

# Smoke test getc: echo one character from UART input via putc
demo-echo:
    @OCAML_STDIN='Z' ./scripts/run-ocaml.sh tests/eval_getc_echo.ml

# Smoke test read_line: read a line from UART and print it back
demo-readline:
    @OCAML_STDIN=$'hello\n' ./scripts/run-ocaml.sh tests/eval_read_line_echo.ml

# Interactive echo loop: print each line until user types 'quit'
demo-echo-loop:
    @./scripts/run-ocaml-interactive.sh tests/demo_echo_loop.ml

# Interactive guess-the-number game (target is 42)
demo-guess:
    @./scripts/run-ocaml-interactive.sh tests/demo_guess.ml

# Text-adventure demo (variant rooms, pattern-matched commands; commands: look, n/s/e/w, take, inventory, quit)
demo-adventure:
    @./scripts/run-ocaml-interactive.sh tests/demo_adventure.ml

# Run a REPL session from a file (one expression per line)
repl-session file:
    @./scripts/run-ocaml.sh {{file}}

# Run the REPL session demo (factorial, multi-arg, print_int)
demo-repl:
    @./scripts/run-ocaml.sh tests/repl_session.ml

# Launch interactive REPL (terminal mode -- type Ctrl-C to exit)
repl:
    @./scripts/repl.sh

# Smoke test: verify toolchain works
smoke:
    @echo "--- Hello World ---"
    @./scripts/run-pascal.sh tests/hello.pas
    @echo "--- Hello Int ---"
    @./scripts/run-pascal.sh tests/hello_int.pas
    @echo "--- Smoke test passed ---"
