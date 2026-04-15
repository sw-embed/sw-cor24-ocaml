Update result printing in the REPL to display lists.

When the result is VK_NIL, print '[]'.
When the result is VK_CONS, recursively print '[h; t1; t2; ...]'
where h is head and t1..tn come from walking the tail.

Add helper procedure print_value(v: PVal) that handles all value kinds
including recursive cons walks.

Test:
  [1; 2; 3]   -> [1; 2; 3]
  []          -> []
  1 :: [2; 3] -> [1; 2; 3]