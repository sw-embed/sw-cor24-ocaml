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

# Smoke test: verify toolchain works
smoke:
    @echo "--- Hello World ---"
    @./scripts/run-pascal.sh tests/hello.pas
    @echo "--- Hello Int ---"
    @./scripts/run-pascal.sh tests/hello_int.pas
    @echo "--- Smoke test passed ---"
