Create an interactive OCaml REPL.

Write an OCaml program that loops:
1. Print a prompt (putc for '>' and ' ')
2. Read a line of input via getc (until newline)
3. Parse and evaluate the expression
4. Print the result
5. Loop

This requires the interpreter to support re-parsing from a string
buffer. The simplest approach: make the source buffer writable
from the evaluator (read line into src, reset pos, lex+parse+eval).

Alternatively, add a built-in eval_line that does this internally.

This is the final step of the phase2-modular-repl saga.