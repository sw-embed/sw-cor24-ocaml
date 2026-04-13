let rec loop = fun u ->
  let s = switch () in
  set_led s;
  loop ()
in loop ()