type color = Red | Green | Blue
Red
Green
Blue
match Red with Red -> 1 | Green -> 2 | Blue -> 3
match Green with Red -> 1 | Green -> 2 | Blue -> 3
match Blue with Red -> 1 | Green -> 2 | Blue -> 3
let name = function Red -> "red" | Green -> "green" | Blue -> "blue" in name Blue
type shape = Circle | Square | Triangle
match Circle with Red -> 1 | Green -> 2 | Blue -> 3 | Circle -> 10 | Square -> 11 | Triangle -> 12
