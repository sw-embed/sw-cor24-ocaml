string_of_int 42
string_of_int 0
string_of_int (-7)
string_of_int 123456
int_of_string "100"
int_of_string "-42"
int_of_string "0"
print_endline (string_of_int (List.length [1;2;3]))
string_of_int (List.fold_left (fun a x -> a + x) 0 [1;2;3;4;5])
int_of_string (string_of_int 789)
int_of_string "abc"
int_of_string ""
