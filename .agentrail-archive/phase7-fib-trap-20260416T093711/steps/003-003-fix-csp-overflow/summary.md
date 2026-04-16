BLOCKED: Blocked on upstream sw-cor24-pcode#14 — fix identified and verified locally, but pvm.s is gitignored-vendored. Waiting for upstream merge + version pin bump.

## Details

Identified the exact fix in `vendor/sw-pcode/v0.1.0/bin/pvm.s`: add `csp < eval_stack` bounds checks (trap code 2) to op_call, op_calln, op_enter, and the xcall handler; grow call_stack from 1536 → 4096 bytes. Verified locally — fib 1..11 all return correct values (was: fib 8 EVAL_ERROR, fib 9..12 TRAP 4), deep recursion (`let rec deep n = ... in deep 100`) now produces clean TRAP 2 (STACK_OVERFLOW) instead of TRAP 4 (INVALID_OPCODE). All 58 existing regression tests still pass + a new canonical_fib.ml test passes.

But `vendor/` is gitignored (fetched from upstream by `scripts/vendor-fetch.sh`), so the fix cannot be committed downstream without modifying files outside this repo. Filed https://github.com/sw-embed/sw-cor24-pcode/issues/14 with full diff, evidence table, and patch-ready edits. Reverted local pvm.s edits via vendor-fetch to leave the tree clean.

## Follow-up (new step, once upstream merges)

1. Bump commit pin in `vendor/sw-pcode/v0.1.0/version.json` (or cut a new `v0.1.1/` vendor directory).
2. Re-fetch: `./scripts/vendor-fetch.sh`.
3. Re-add `tests/canonical_fib.ml` + corresponding reg-rs baseline.
4. Re-verify fib 10 returns 55 and deep recursion produces TRAP 2.
