Add tokens and AST nodes for pattern matching -- structure only, no parsing/eval yet.

Tokens:
- TK_MATCH (keyword)
- TK_WITH (keyword)
- TK_PIPE '|' (single, distinct from TK_OROR '||')
- TK_UNDERSCORE -- actually '_' is already handled as an identifier.
  Reserve it: after reading an identifier, if it's exactly '_', treat
  as wildcard. Keep as TK_IDENT but recognize in pattern parser.

AST kinds:
- EK_MATCH=11 with left=scrutinee, right=first arm (chained)
- EK_MATCH_ARM=12 with pattern field (separate type) + body + next arm

Pattern AST (new record type PPat):
  type PPat = ^Pat;
  Pat = record
    pk: integer;       (* PK_ constant *)
    ival: integer;     (* for PK_INT *)
    noff, nlen: integer;  (* for PK_VAR *)
    sub1, sub2: PPat   (* for PK_CONS, PK_PAIR, PK_SOME *)
  end;
  PK_WILDCARD=0
  PK_INT=1
  PK_BOOL=2
  PK_VAR=3
  PK_NIL=4
  PK_CONS=5   (* sub1 = head pattern, sub2 = tail pattern *)
  PK_PAIR=6   (* sub1 = first, sub2 = second *)
  PK_NONE=7
  PK_SOME=8   (* sub1 = payload pattern *)
  PK_LIST=... (sugar for [p1; p2; p3] -> cons chain)

Add mk_pat_* constructors.

Update EK_MATCH to chain arms via a linked list through right pointer, 
OR use an array of arms. Simplest: linked list of (pattern, body, next)
records. Actually simpler: use extra field of Expr to point to next arm.

No parser or evaluator changes yet. Just define the data structures.

Commit and move to parser step.