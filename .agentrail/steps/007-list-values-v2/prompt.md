Add list value type and runtime support. Re-attempt after sw-cor24-pascal#17 fix (bracketed strings now print correctly with --load-addr).

Extend Val record with head: PVal and tail: PVal fields.
Add VK_NIL=5 and VK_CONS=6 constants.
Add mk_val_nil and mk_val_cons constructors (init all fields including the new head/tail in every existing mk_val_*).
Add built-in primitive 'nil' (nullary, returns VK_NIL) recognized in EK_VAR.
Update main REPL result printer to handle VK_NIL -> '[]' and VK_CONS -> 'cons' (we'll do proper list printing in step 003-list-printing).

Defer hd/tl/is_empty to the list-syntax step since they need actual cons cells to test.

Test:
  > nil
  []

Commit with green tests.