# Step: typed-allocators

Introduce typed allocator helpers (`alloc_expr`, `alloc_pat`, `alloc_val`,
`alloc_env`, `alloc_string`, `alloc_list`, plus any others surfaced in
`docs/heap-survey.md`) and route every `new(...)` call from the survey
through them. No collection logic yet — this step is a refactor that must
preserve current behavior.

## What to do

1. Add allocator helpers in the appropriate host module. Each helper:
   - Allocates the underlying record via `new(...)`.
   - Threads the new object onto a per-kind tracking list (intrusive
     `next_alloc` field is fine if records permit; otherwise a parallel
     metadata table). Pick whichever shape fits the existing record
     layouts cleanly.
   - Returns the typed pointer.
2. Replace every `new(...)` site listed in `docs/heap-survey.md` with the
   matching helper.
3. Add per-kind counters incremented in the helpers (alloc count). Do not
   wire any sweep/free yet.
4. Run the full test suite. It must pass with zero regressions. The #28
   repro will still trap — that is expected at this step.

## Out of scope

- No mark/sweep code yet.
- No root tracking yet.
- Do not change the meaning of any allocation; the helpers are pass-through.

## Done when

- Every survey-listed `new(...)` is replaced by an `alloc_*` helper.
- Each kind has an alloc counter readable for debugging.
- `just test` passes.
- Committed and pushed.
