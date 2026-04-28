# Step: promotion-and-cleanup

Final validation gate.

## What to do

1. Run the full test suite end to end.
2. Run focused fixture suites called out in the project README / CLAUDE.md
   if any (e.g., interactive demo build for both `ocaml.p24` and the
   relocated `ocaml.p24m`).
3. Run a brief throughput smoke: time a parse/eval workload before and
   after this saga's branch tip if a baseline is easy to capture. Record
   the number for the saga record.
4. `agentrail audit` — confirm no orphan commits and no orphan steps.
5. If anything externally observable changed (heap reporting, instrumentation
   output, test commands), update README or AGENTS.md accordingly.
6. Mark the saga done with `--done`.

## Done when

- Full test suite green.
- `agentrail audit` clean.
- Saga marked done.
