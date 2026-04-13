Wire everything together into a complete interpreter and build the demo.

Create src/oc_main.pas:
- Read OCaml source from input (file, embedded text, or stdin)
- Lex -> Parse -> Eval pipeline
- Error reporting with position and message
- Exit with appropriate code

Integration testing:
- Compile all Pascal sources to p-code via vendored compiler
- Package interpreter p-code with P-code VM
- Build COR24 binary via vendored assembler
- Run demo on vendored emulator

Demo program: let x = 41 + 1 in print_int x
Expected output: 42

Set up reg-rs baseline tests for the demo and key expressions.
This is the final step of the initial-spike saga.