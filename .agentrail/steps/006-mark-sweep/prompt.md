# Step: mark-sweep

Implement mark/sweep over the typed allocations from step 3 using the
roots defined in step 4. Trigger collection at the end of each top-level
eval transaction and before reporting heap overflow.

## What to do

1. Add a `mark` bit to each tracked allocation kind (one bit per object;
   reuse a spare bit in an existing field if available, otherwise add).
2. Implement `gc_mark_from_roots`: start from `gc_iter_roots`, traverse
   the pointer fields documented in the step 2 survey, set mark bits.
3. Implement `gc_sweep_kind`: for each allocation list, free objects
   without the mark bit and clear the bit on survivors. Use the
   underlying runtime's existing `dispose` (the issue notes p-code
   already has dispose support).
4. Call `gc_collect = mark + sweep` at:
   - The top of each top-level REPL/eval transaction once the prior
     transaction has finished.
   - Inside `alloc_*` helpers when they would otherwise raise heap
     overflow — collect once, retry once, then propagate the overflow.
5. Add per-kind sweep counters and a debug hook to print
   alloc/marked/swept tallies after each collection.
6. Run the existing test suite. All tests must pass.

## Risks to watch for

- Under-rooting → use-after-free → spurious crashes that *look* random.
  If you see one, the right fix is to identify the missing root and add
  it in step 4's instrumentation, not to disable the collector.
- Cycles: closures and refs can produce them. Mark/sweep handles cycles
  natively (unlike refcounting), but be sure the traversal does not loop
  forever — set the mark bit *before* recursing into children.
- Dispose ordering: do not dispose an object that other survivors still
  point at via fields the marker did not visit. Cross-check field lists
  with the survey.

## Done when

- `gc_collect` is implemented and called at the documented points.
- Counters expose alloc/marked/swept per kind.
- `just test` passes.
- Committed and pushed.
