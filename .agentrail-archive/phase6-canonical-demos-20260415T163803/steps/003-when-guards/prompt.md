Add 'when' guards to match arms: 'match x with n when n < 0 -> -n | n -> n'.

Parser:
- Extend parse_match arms and parse_function_expr arms. After parsing the pattern, check for tok = TK_WHEN. If present: lex_next, parse an expression (the guard), then require TK_ARROW and proceed with body.
- Store the guard in a new field on EK_MATCH_ARM. The Expr record has 'extra: PExpr' which is currently nil for arms — use that.
- Add TK_WHEN token (next available after TK_TYPE=24). Classify 4-letter identifier 'when'.

Evaluator:
- In EK_MATCH dispatch, after try_match succeeds and extends env with bindings, if arm^.extra is non-nil, evaluate it in the extended env. If the guard result is not VK_BOOL with ival=1, treat as a failed match and continue to the next arm.

Test: tests/eval_when_guards.ml:
  let abs x = match x with n when n < 0 -> -n | n -> n in abs (-5)             => 5
  let abs x = match x with n when n < 0 -> -n | n -> n in abs 7                => 7
  let sign x = match x with n when n < 0 -> -1 | 0 -> 0 | _ -> 1 in sign (-10) => -1
  let sign x = match x with n when n < 0 -> -1 | 0 -> 0 | _ -> 1 in sign 0     => 0
  let sign x = match x with n when n < 0 -> -1 | 0 -> 0 | _ -> 1 in sign 99    => 1
  match 7 with n when n > 10 -> "big" | n when n > 5 -> "mid" | _ -> "small"  => "mid"

Register with reg-rs. Keep src/ocaml.pas well under 131K.