Implement an interactive REPL for the OCaml interpreter.

Currently the interpreter reads source from UART once via lex_init,
evaluates one expression, and halts. For a REPL we need:

1. Modify lex_init to read ONE expression (until ; or newline+empty)
   and reset state so it can be called repeatedly
2. Add a main REPL loop that:
   - Prints prompt: putc '>' putc ' '
   - Calls lex_init to read input
   - Calls parse_seq + eval_expr
   - Prints result (already done for INT/BOOL/UNIT)
   - Loops until special exit condition
3. Reset name_pool_len, parse_error, eval_error each iteration
4. Update build/run scripts to use --terminal mode for live input
5. Provide both interactive (--terminal) and scripted (-u with newline-separated expressions) modes

Test both:
- Scripted: echo -e '42\nlet x = 1 in x + 1\n' | ocaml-repl -> 42, 2
- Interactive: ocaml-repl, type expressions live

Demo: factorial in REPL, then call it repeatedly with different args.

This is the focus of the saga rebooted as phase2-repl.