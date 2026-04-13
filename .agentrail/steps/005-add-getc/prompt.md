Add getc for interactive UART input.

Use the SNOBOL4 REPL pattern:
- lex_init reads source from UART until EOT (chr(4)) -- already works
- After EOT, the UART is still open for live input
- getc reads the next character from UART via Pascal read(ch)
- Run with --terminal mode for interactive input

Add built-in: getc : unit -> int (read one char, return ordinal)

Update run-ocaml.sh to support --terminal mode.
Test: a program that reads a character and echoes it.
Create reg-rs baselines (use -u for scripted input after source EOT).