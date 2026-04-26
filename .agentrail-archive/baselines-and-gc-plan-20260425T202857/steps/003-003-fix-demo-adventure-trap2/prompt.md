Fix GitHub issue #1: TRAP 2 in `demo_adventure` after returning to Cave and
taking the lamp again.

Issue URL: https://github.com/sw-embed/sw-cor24-ocaml/issues/1

Repro:

```bash
OCAML_STDIN=$'look\ntake\ninventory\nn\ns\ntake\nquit\n' ./scripts/run-ocaml.sh tests/demo_adventure.ml
```

Observed tail:

```text
Damp cave. A lamp lies here. Exits: n.
take
TRAP 2
```

Notable constraints:

- `take`, `take`, `quit` does not trap.
- The trap only appears after `go` returns `Some Cave` and the loop re-enters
  with `(r2, inv)`.
- Treat this as interpreter/PVM behavior, not web-side behavior.

Work plan:

1. Reproduce the issue from a clean build and capture the exact trap site if
   tooling supports it.
2. Inspect value/env lifetime around pairs, variants, list cons, closures, and
   tail-call loop state in `src/oc_eval.pas`, `src/oc_value.pas`, and
   `src/ocaml.pas`.
3. Narrow the minimal source that reproduces `Some Cave` followed by
   `it :: inv`, so the fix is not tied only to the demo.
4. Fix the interpreter/runtime bug without changing `tests/demo_adventure.ml`
   semantics.
5. Add or update reg-rs coverage for the failing command sequence.
6. Run the focused repro, the demo adventure regression, and the standard test
   gate used in this repo.

Out of scope:

- Web embedding work in `../web-sw-cor24-ocaml`.
- Rewriting the adventure demo to avoid the bug.
- Garbage collection design unless the repro proves heap exhaustion is the
  actual cause.
