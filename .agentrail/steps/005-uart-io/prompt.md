Add UART I/O primitives to the evaluator.

Add built-in functions:
  putc : int -> unit        (write character to UART)
  getc : unit -> int        (read character from UART, blocking)

Implementation:
- putc: use Pascal's write(chr(n)) to output a character
- getc: use Pascal's read(ch) then return ord(ch)

Note: getc may need special handling since the interpreter reads
its own source from stdin. Consider whether to support interactive
input or defer getc to a later phase.

Test: putc 72; putc 105; putc 10  outputs 'Hi' + newline
Update src/ocaml.pas, rebuild, create reg-rs baselines.