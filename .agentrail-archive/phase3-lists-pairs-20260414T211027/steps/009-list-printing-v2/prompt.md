Implement recursive list pretty-printing for VK_CONS values.

Current: VK_CONS prints 'cons'.
Target: [1; 2; 3] prints [1; 2; 3].

Add a procedure print_value(v: PVal) that handles all value kinds
recursively. For VK_CONS, walk the cons chain:
  [
  print first element
  while tail is VK_CONS, print '; ' and next element
  print ']'

Be careful with int printing vs other types (strings not supported
yet, so probably just recurse to print each element).

Update the main REPL result printer to call print_value instead of
the special cases for VK_NIL/VK_CONS.

Test:
  [1; 2; 3]  -> [1; 2; 3]
  1 :: nil   -> [1]
  hd [42]    -> 42  (no bracket)
  tl [1;2;3] -> [2; 3]
  nil        -> []