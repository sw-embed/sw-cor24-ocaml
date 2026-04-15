Add pair (2-tuple) value support.

Add VK_PAIR value kind. Reuse left=first, right=second pointers
in the Val record.

Add value constructor: mk_val_pair : PVal -> PVal -> PVal

Add built-ins:
  fst : pair -> 'a   (first component)
  snd : pair -> 'b   (second component)

Add pair printing: (a, b)