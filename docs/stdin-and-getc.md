# Runtime stdin and `getc`

## The primitive

`getc : unit -> int` reads one byte from UART and returns it as an int
(0..255). It is the foundation for all interactive input — `read_line`,
calculators, text adventures, etc. are built on top.

Source: `src/ocaml.pas` — interned in `intern_board`, dispatched in
`eval_expr`'s apply block.

## The wire: source and runtime share a UART

On COR24, there is one UART. The driver (`scripts/run-ocaml.sh`) feeds it:

    <source bytes> 0x04 <runtime input bytes>

`0x04` (EOT) terminates the source. The lexer's `lex_init` reads a line
at a time from UART and stops when it sees 0x04 or a newline. After
source is consumed, further UART bytes are runtime input for `getc`.

To append runtime input, set the `OCAML_STDIN` env var before invoking
`run-ocaml.sh`:

    OCAML_STDIN='hello' ./scripts/run-ocaml.sh program.ml

## The EOT-lookahead quirk

The Pascal runtime (`vendor/sw-pascal/.../runtime.spc`, `_p24p_read_char`)
uses a one-byte lookahead buffer. The `eof` function pre-reads one byte
to decide the result. This means when the lexer's `while not eof do`
loop sees the source's 0x04 terminator, 0x04 is already sitting in the
lookahead — and the very first runtime `read(ch)` call (i.e., the first
`getc`) returns 0x04 instead of the user's first byte.

Fix: `getc` discards a leading 0x04 and reads again. This only fires on
the first `getc` after source ingestion — later calls bypass the
lookahead and go straight to `sys_getc`, so they behave normally.

Consequence: the literal byte 0x04 cannot be a user's very first input
byte (a second `getc` would block waiting). This is harmless for any
realistic use case (calculators, chatbots, adventures).

## Smoke test

    tests/eval_getc_echo.ml:  let c = getc () in putc c

Run via `just demo-echo` (feeds `Z`, prints `Z`) or the regression test
`work/reg-rs/eval_getc_echo.rgt`.
