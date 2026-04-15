let f = function 0 -> 100 | 1 -> 101 | _ -> 999 in f 0
let f = function 0 -> 100 | 1 -> 101 | _ -> 999 in f 1
let f = function 0 -> 100 | 1 -> 101 | _ -> 999 in f 5
let f = function [] -> 0 | h :: t -> h in f [42; 99]
(function 0 -> 100 | _ -> 0) 0
let classify = function Some n -> n | None -> 0 in classify (Some 42)
let classify = function Some n -> n | None -> 0 in classify None
