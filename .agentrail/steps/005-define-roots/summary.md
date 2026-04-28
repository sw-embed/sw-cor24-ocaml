# Step 005 — define-roots: findings

## Departure from the original step prompt

The prompt called for a push/pop root-stack API and parser/eval
instrumentation so the future collector could safely run mid-eval.
After thinking through #28's failure mode and the proc/symbol budget
established in step 004, I went with a leaner design and recorded
the tradeoffs in `docs/gc-design.md`.

The leaner design:

- **Collection runs only at the top of REPL**, between top-level
  transactions. At that moment, all parser/eval call frames have
  unwound and no heap object is referenced solely from a Pascal
  stack local.
- **The root set collapses to one pointer: `top_env`.** Everything
  else reachable (closures, captured envs, AST bodies, refs,
  records, lists, pairs, options, ctors) is reachable through it.
- **No push/pop API needed** — there are no transient roots to
  track at REPL boundary.

This is sufficient for #28 (which traps between top-level transactions,
not inside a single expression) and saves a non-trivial amount of
proc-cap budget that step 006 will need for the marker/sweeper.

A future iteration could add mid-eval collection with proper
push/pop roots if a real workload appears that allocates more in a
single transaction than a freshly-collected heap can hold. The known
acceptance fixtures don't.

## What landed

1. `mark_bit: integer` field added to each of the four heap record
   types (`Expr`, `Pat`, `Val`, `EnvEntry`). Single new field name,
   four record instances. Step 006's marker will set/clear this bit.
   Field is uninitialized at `new()` time; the collector's first
   action will be a clear pass over all four alloc lists.
2. `docs/gc-design.md` records the design choices: collection
   trigger, root set, the per-VK pointer-field map for the marker,
   sweep policy, mark-bit lifecycle, and proc-budget implications.

## Proc/symbol-budget update

A new GitHub issue was filed upstream against
`sw-embed/sw-cor24-pascal#21` to **double `MAX_PROCS` from 128 to 256**
in `compiler/src/parser.h`. If/when that ships and we re-vendor, step
006 (and any future host work) will have ~125 free proc slots, which
removes the constraint that has shaped this saga's middle steps.

Until that upstream fix lands, step 006 must still respect the 127-proc
ceiling. The design doc spells out the implication: implement
`gc_collect` as a single procedure with `case` dispatch rather than
per-type helpers.

## Verification

- `./scripts/build.sh` — succeeds.
- `just test` — 100/100.
- No mark/sweep code yet, so #28 still traps. Expected.

## Next step (006 — mark-sweep)

Step 006 adds a single `gc_collect` procedure that:

1. Walks all four `*_alloc_head` lists and clears `mark_bit := 0` on
   every live allocation.
2. Marks reachable objects starting from `top_env` (per the
   pointer-field map in `docs/gc-design.md`).
3. Sweeps each list: splice out unmarked nodes and `dispose()` them;
   reset `mark_bit := 0` on survivors.
4. Is invoked at the top of the REPL loop in `src/ocaml.pas`, between
   transactions.

Acceptance: `bash $TUPLET_REPO/scripts/repro-ocaml-issue28.sh` runs
through the second pass without `TRAP 5`, and `just test` stays at
100/100.
