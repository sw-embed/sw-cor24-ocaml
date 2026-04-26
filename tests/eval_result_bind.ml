Ok 41
Error "bad"
Result.bind (Ok 41) (fun n -> Ok (n + 1))
Result.bind (Error "stop") (fun n -> Ok (n + 1))
let parse_int s = if s = "42" then Ok 42 else Error ("bad int: " ^ s)
let checked_div x y = if y = 0 then Error "divide by zero" else Ok (x / y)
Result.bind (parse_int "42") (fun n -> checked_div n 2)
Result.bind (parse_int "nope") (fun n -> checked_div n 2)
match Result.bind (Ok 5) (fun n -> Ok (n * 2)) with
  | Ok n -> n
  | Error _ -> 0
