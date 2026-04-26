Rebase the remaining 7 pre-existing baseline failures, all unrelated to TCO:

Stderr-only (assembled bytes count changed across interpreter rebuilds):
  - lex_all, lex_arith, lex_fun, lex_let

Stdout mismatch (de562aa updated demo .ml sources; baselines echo old sources):
  - demo_adventure, demo_echo_loop, demo_guess

For each: run reg-rs run -p <name> -vv, sanity-check that the diff is
purely mechanical (size change or source-echo change), then reg-rs rebase
-p <name>. After all 7, just test should report 0 failures.

Commit message: chore(tests): rebase stale reg-rs baselines.

Out of scope: fixing underlying test framework, any source changes.