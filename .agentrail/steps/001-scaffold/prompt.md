Set up the project directory structure, vendoring skeleton, and build infrastructure.

Create directories: src/, tests/, scripts/, vendor/
Set up vendor/active.env and version.json manifests for vendored tools (Pascal compiler, P-code VM, assembler, emulator).
Create scripts/vendor-fetch.sh adapted from the sw-cor24-plsw vendoring pattern.
Create initial build.sh or justfile.
Set up work/reg-rs/ directory for regression testing.
Verify the full pipeline works with a trivial Pascal hello-world program through the vendored toolchain.

Reference docs/architecture.md for the vendoring layout and docs/plan.md step 1.