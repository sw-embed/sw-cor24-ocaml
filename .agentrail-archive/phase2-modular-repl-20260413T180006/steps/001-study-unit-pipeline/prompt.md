Study how p24p unit compilation works and how the Pascal project's multi-unit build pipeline operates.

Read the Pascal compiler's unit-related docs and tests:
- compiler/tests that use 'uses units' or --unit flag
- scripts/run-pascal-unit.sh for the unit build pipeline
- The p24-load tool for combining .p24 binaries
- runtime/runtime-unit.spc and p24p_rt.p24

Understand:
1. How to compile a Pascal file as a unit (--unit flag?)
2. How units export/import procedures and globals
3. How the linker or p24-load combines units
4. What the final binary layout looks like

Document findings in a short notes file.
Do NOT modify interpreter code yet -- research only.