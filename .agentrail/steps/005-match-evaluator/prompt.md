Evaluate pattern matches.

Main function: try_match(p: PPat; v: PVal; env: PEnv): PEnv
- Returns extended env if pattern matches, nil if not.
- For PK_VAR: always matches, adds binding to env.
- For PK_WILDCARD: always matches, no binding.
- For PK_INT: matches if v is VK_INT with same ival.
- For PK_BOOL: matches if v is VK_BOOL with same ival.
- For PK_NIL: matches if v is VK_NIL.
- For PK_CONS: matches if v is VK_CONS, recursively match head/tail.
- For PK_PAIR: matches if v is VK_PAIR, recursively match.
- For PK_NONE/PK_SOME: match value kind, optionally recurse into payload.
- For PK_LIST: desugared already to PK_CONS chain.

In eval_expr, add EK_MATCH case:
- Evaluate scrutinee.
- Walk arms: for each, call try_match. On success, eval body in extended env.
- On no match: eval_error := true, print 'Match failure' or similar.

Tests (combining with existing features):
  let rec sum = fun l -> match l with [] -> 0 | h :: t -> h + sum t in sum [1;2;3;4]
  = 10
  
  let rec length = fun l -> match l with [] -> 0 | _ :: t -> 1 + length t in length [10;20;30]
  = 3
  
  let rec map = fun f l -> match l with [] -> [] | h :: t -> f h :: map f t in map (fun x -> x * 2) [1;2;3]
  = [2; 4; 6]
  
  let safe_div = fun x y -> if y = 0 then None else Some (x / y) in safe_div 10 3
  = Some 3
  
  match Some 7 with None -> 0 | Some n -> n + 1
  = 8