type syntax_entry = SyntaxEntry of string * string * string list * string list
type syntax_match = NoSyntaxMatch | SyntaxMatch of string * string list * string list * string list * int
let syntax_entries = ref []
let syntax_next_order = ref 0
let add_syntax mode template expansion = let order = !syntax_next_order in let order_s = string_of_int order in let _ = syntax_next_order := order + 1 in syntax_entries := SyntaxEntry (order_s, mode, template, expansion) :: !syntax_entries
let is_slot s = s = "slot"
let has_capture cap = match cap with [] -> false | _ -> true
let rec rev_items xs acc = match xs with [] -> acc | h :: t -> rev_items t (h :: acc)
let rec append_items xs ys = match xs with [] -> ys | h :: t -> h :: append_items t ys
let rec template_len xs = match xs with [] -> 0 | h :: t -> 1 + template_len t
