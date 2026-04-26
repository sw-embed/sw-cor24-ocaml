List.find_opt (fun x -> x > 3) [1;2;4;5]
List.find_opt (fun x -> x > 10) [1;2;4;5]
let threshold = 2 in List.find_opt (fun x -> x > threshold) [1;2;3]
match List.find_opt (fun x -> x = 4) [1;2;3;4] with
  | None -> 0
  | Some n -> n + 1
