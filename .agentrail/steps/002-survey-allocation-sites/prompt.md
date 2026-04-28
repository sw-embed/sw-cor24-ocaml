# Step: survey-allocation-sites

Catalog every OCaml-runtime heap allocation site in the host sources, by
kind, with retention relationships. No code changes — this step produces a
written survey that the next step (typed-allocators) will use as its
worklist.

## What to do

1. Grep all `new(...)` calls in `src/` and `runtime/` (or wherever host
   sources live for this project). Focus on `src/ocaml.pas`.
2. For each site, record:
   - File and line.
   - The Pascal type being allocated.
   - The logical OCaml runtime kind (expr / pat / val / env-entry /
     record / ref / closure / string / list-cons / other).
   - Caller context (one-line summary of why it allocates).
3. For each kind, document the pointer fields it carries — i.e., what
   other heap objects this kind can keep alive. This is the data the
   mark phase will need.
4. Identify any allocation that is *not* through `new(...)` (e.g., manual
   `mark`/`release` patterns, custom arenas) and flag them.
5. Produce a single markdown file `docs/heap-survey.md` (or wherever fits
   project layout) with the catalog. Commit it.

## Out of scope

- No changes to allocation behavior.
- No introduction of helpers yet (next step does that).

## Done when

- `docs/heap-survey.md` exists with: per-kind allocation site list,
  per-kind pointer-field map, and any "weird" allocators called out.
- Committed and pushed.
