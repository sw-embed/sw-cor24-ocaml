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

# Smoke test: verify toolchain works
smoke:
    @echo "--- Hello World ---"
    @./scripts/run-pascal.sh tests/hello.pas
    @echo "--- Hello Int ---"
    @./scripts/run-pascal.sh tests/hello_int.pas
    @echo "--- Smoke test passed ---"
