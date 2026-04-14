Add list value type and runtime support.

Extend Val record with a new value kind:
  VK_NIL    - empty list
  VK_CONS   - cons cell with head (PVal) and tail (PVal)

The existing Val record has fields: vk, ival, noff, nlen, body, cenv.
Reuse left/right or add a tail field if needed (consider adding 'tail: PVal'
to the record).

Add value constructors:
  mk_val_nil : unit -> PVal       (creates the empty list value)
  mk_val_cons : PVal -> PVal -> PVal  (creates a cons cell)

Add built-in functions for list operations (recognized by name like print_int):
  is_empty : list -> bool   (true if VK_NIL, false if VK_CONS)
  hd : list -> 'a           (head of cons; error on nil)
  tl : list -> list         (tail of cons; error on nil)

Test programs that don't require new syntax yet:
  is_empty (mk_nil)              -- but mk_nil is not exposed yet
Tests will come in the next step once syntax is added.