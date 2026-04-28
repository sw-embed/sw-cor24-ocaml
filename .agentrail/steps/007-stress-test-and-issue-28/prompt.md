# Step: stress-test-and-issue-28

Add an internal stress test, run the #28 repro, and verify acceptance.

## What to do

1. Add a host-level stress test (in the project's test harness) that
   runs many small parse/eval transactions in one session — for example,
   parse and evaluate a few hundred independent `let` and arithmetic
   expressions, plus a handful that allocate strings, lists, refs, and
   records. Assert the OCaml heap pointer at the end of the run is below
   a fixed bound (i.e., bounded growth, not monotonic).
2. Run the #28 repro: `bash ../sw-vibe-coding/tuplet/scripts/repro-ocaml-issue28.sh`.
   Confirm the second pass produces the expected token stream:
   ```
   IDENT  do
   IDENT  body
   IDENT  while
   IDENT  cond
   IDENT  end
   EOF
   ```
3. Run `just test` and verify zero regressions.
4. If anything fails, do not paper over it with another pool bump. Either
   the marker is missing a root, the sweeper is freeing live state, or
   the field traversal is wrong. Fix the root cause.
5. On success, post a comment to GitHub issues #28 and #29 noting the
   fix and pointing to the relevant commits, then close both with `gh
   issue close`.

## Done when

- Stress test exists and passes with bounded growth.
- #28 repro succeeds end-to-end.
- `just test` passes.
- Issues #28 and #29 closed with comments linking to the fix commits.
- Committed and pushed.
