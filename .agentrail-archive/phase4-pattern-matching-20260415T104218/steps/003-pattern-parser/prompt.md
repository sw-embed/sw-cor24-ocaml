Parse patterns.

New function: parse_pattern : PPat
- INT_LITERAL -> PK_INT with ival
- TRUE/FALSE -> PK_BOOL
- IDENT 'None' -> PK_NONE
- IDENT 'Some' followed by atom-pattern -> PK_SOME with sub1
- IDENT '_' -> PK_WILDCARD
- IDENT other -> PK_VAR with noff/nlen (binds)
- [] -> PK_NIL
- [p1; p2; p3] -> PK_LIST (desugar to PK_CONS chain with PK_NIL tail)
- p1 :: p2 -> PK_CONS (right-assoc like in expressions)
- (p) -> parenthesized
- (p1, p2) -> PK_PAIR

Right-assoc :: at pattern level mirrors expression parse_cons.

Test: write a small pattern-reading function that reads patterns
terminated by TK_ARROW and dumps them as s-expressions. Commit
the test harness as an internal debug tool (or skip and just let
the match-parser step exercise it).