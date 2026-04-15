Allow user-defined operator symbols via 'let (|>) x f = f x'.

Parser: in parse_expr's TK_LET branch, after 'let' if tok is TK_LPAREN
followed by operator chars followed by TK_RPAREN, read the operator
name as an identifier. Common operator chars: | > < = + - * / @ ^ &
but start simple with just |>.

Actually simpler: treat (|>) as an identifier whose name is '|>'.
In the lexer, recognize sequences like |>, <|, @|, etc.
Or: special-case the parser to read TK_LPAREN followed by a sequence
of operator chars into a tok_id and then TK_RPAREN.

Then use the operator by parsing 'x |> f' as app(app(|>, x), f). This
requires adding |> as a binop-level token and routing to the bound
function.

SIMPLER APPROACH: only support operator-as-function via (|>) as a call
syntax; user-defined operators must be called with prefix syntax:
  let (|>) x f = f x in (|>) 5 (fun x -> x + 1)
This avoids parser changes for infix operator lookup.

Tests (prefix call):
  > let (|>) x f = f x in (|>) [1;2;3] (fun l -> List.length l)   3
  > let compose f g x = f (g x) in (compose (fun x -> x + 1) (fun x -> x * 2)) 5   11

Mark this step DEFERRED if time-boxed; real |> support needs infix lookup.