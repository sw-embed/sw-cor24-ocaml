Add support for negative integer literals in atom position.

Currently -42 parses as (- 0 42) which works but is awkward.
Handle the case where - appears at atom start by parsing it as a
negative literal or unary minus at the atom level.

This is a parser-only change. The evaluator already handles subtraction.

Test: let x = -1 in print_int x  outputs -1
Test: print_int (-42)  outputs -42