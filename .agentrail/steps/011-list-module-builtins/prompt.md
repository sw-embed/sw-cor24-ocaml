Implement List.length, List.rev, List.hd, List.tl, List.is_empty.

Intern each qualified name. Add EK_VAR dispatch returning closures.
Add EK_APP dispatch with implementation.

- List.hd, List.tl, List.is_empty: alias to the existing hd/tl/is_empty
  implementations (just match by name, dispatch to same code)
- List.length: walk cons chain counting. Recursive Pascal function.
- List.rev: walk cons chain building reversed cons. Recursive Pascal function.

Tests:
  List.length [1; 2; 3]  -> 3
  List.length []         -> 0
  List.rev [1; 2; 3]     -> [3; 2; 1]
  List.rev []            -> []
  List.hd [42]           -> 42
  List.is_empty []       -> true
  List.is_empty [1]      -> false