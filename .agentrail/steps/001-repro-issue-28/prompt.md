# Step: repro-issue-28

Reproduce GitHub issue #28 (two-pass memory-backed Tuplet parse traps after
syntax registration) from this host repo and confirm or refute the
reporter's diagnosis that the trap is heap exhaustion in the OCaml runtime,
not a lexer or state bug.

## Context

- Issue #28: https://github.com/<repo>/issues/28
- Repro script (in sibling repo): `../sw-vibe-coding/tuplet/scripts/repro-ocaml-issue28.sh`
- Host commit at filing: 529c9e2 (current HEAD)
- Host runner: `run-ocaml.sh` (loads `ocaml.p24m` at 0x040000, heap_limit
  patched to 0x03F000, fixture at 0x080000)
- The first parse pass succeeds and prints the syntax-expand AST. The trap
  occurs mid-token in the second lex pass with `TRAP 5`.
- Sibling-repo rule: per CLAUDE.md, do not modify sibling repos without
  explicit auth. You may run their scripts and read their files.

## What to do

1. Run the repro script and capture the full output.
2. Identify which TRAP fires, where in the host runtime, and what the heap
   pointer / heap limit are at the trap point. Use whatever
   instrumentation is least invasive (existing debug prints are fine; if
   you add any, they go on this branch in this repo only).
3. Decide: is this OOM in the OCaml heap (consistent with #29's diagnosis),
   or is it a different bug (lexer state, parser state machine, two-pass
   restart logic)?
4. Record findings in the step summary.

## Out of scope

- Do not fix anything yet. This step is research only.
- Do not edit sibling repos.
- Do not bump pool sizes or heap limits as a workaround.

## Done when

- Repro reproduced on this host.
- Yes/no answer recorded: "is #28 a heap-exhaustion bug in the OCaml runtime?"
- Any instrumentation added is committed (or reverted if not needed).
