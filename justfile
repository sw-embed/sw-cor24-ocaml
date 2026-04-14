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

# Run a REPL session from a file (one expression per line)
repl-session file:
    @./scripts/run-ocaml.sh {{file}}

# Run the REPL session demo (factorial, multi-arg, print_int)
demo-repl:
    @./scripts/run-ocaml.sh tests/repl_session.ml

# Launch interactive REPL (terminal mode -- type Ctrl-D or close to exit)
repl:
    @echo "OCaml REPL on COR24 -- type expressions, Ctrl-C to exit"
    @echo "Try: 42"
    @echo "     let x = 41 + 1 in x"
    @echo "     let f = fun x -> x * 2 in f 21"
    @echo "     let rec fact = fun n -> if n = 0 then 1 else n * fact (n - 1) in fact 5"
    @echo "     print_int 99"
    @echo "     led_on (); print_int 1"
    @echo "----------------------------------------"
    @CODE_PTR=$(cat build/code_ptr_addr.txt) && \
      cor24-run --load-binary build/pvm.bin@0 \
        --load-binary build/ocaml.p24m@0x010000 \
        --patch "0x$${CODE_PTR}=0x010000" \
        --entry 0 --speed 0 -n 2000000000 --terminal

# Smoke test: verify toolchain works
smoke:
    @echo "--- Hello World ---"
    @./scripts/run-pascal.sh tests/hello.pas
    @echo "--- Hello Int ---"
    @./scripts/run-pascal.sh tests/hello_int.pas
    @echo "--- Smoke test passed ---"
