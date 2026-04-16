# Runtime stdin, `getc`, and `read_line`

## The primitives

`getc : unit -> int` reads one byte from UART and returns it as an int
(0..255). It is the foundation for all interactive input.

`read_line : unit -> string` reads bytes until a newline (LF, 0x0A) or
carriage return (CR, 0x0D) and returns the accumulated bytes as a
string. Neither terminator is included. Backspace (0x08 or 0x7F) erases
the last char of the in-progress line. Each non-terminator byte is
echoed to UART so a live terminal user sees their typing — the echo is
harmless for automated drivers feeding input via `OCAML_STDIN`.

Source: `src/ocaml.pas` — both interned in `intern_board`, dispatched in
`eval_expr`'s apply block. `read_line` accumulates into `string_pool`
(the same store used by `print_endline`, `string_of_int`, etc.).

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

Fix: `getc` (and `read_line`, on its very first byte) discards a leading
0x04 and reads again. This only fires on the first runtime read after
source ingestion — later reads bypass the lookahead and go straight to
`sys_getc`, so they behave normally.

Consequence: the literal byte 0x04 cannot be a user's very first input
byte (a second `getc` would block waiting). This is harmless for any
realistic use case (calculators, chatbots, adventures).

## CR vs LF in `read_line`

A bare LF or a bare CR both terminate cleanly. CRLF is handled by
accident rather than design: the CR terminates the line as expected, and
the trailing LF becomes an empty string the *next* time `read_line` is
called. If you care, strip leading empty lines at the call site, or feed
LF-terminated input.

We don't peek ahead to consume a CR's following LF because the Pascal
runtime has no un-read primitive — reading one byte past the CR would
cost us that byte permanently.

## Smoke tests

    tests/eval_getc_echo.ml:        let c = getc () in putc c
    tests/eval_read_line_echo.ml:   let s = read_line () in print_endline s

Run via `just demo-echo` (feeds `Z`, prints `Z`) and `just demo-readline`
(feeds `hello\n`, prints `hello`). Regression tests:
`work/reg-rs/eval_getc_echo.rgt`, `work/reg-rs/eval_read_line_echo.rgt`.

## Interactive loops

Once `read_line` and string `(=)` are both available, an interactive
REPL-style loop is a single recursive function. Two canonical patterns:

**Echo-until-sentinel** (`tests/demo_echo_loop.ml`): read a line, stop
on `"quit"`, otherwise print it and recurse.

    let rec loop = fun u ->
      let s = read_line () in
      if s = "quit" then print_endline "bye"
      else (print_endline s; loop ())
    in loop ()

The `fun u ->` is a dummy unit parameter — the parser's `let rec`
binding wants a function value, and a zero-arg `fun () -> ...` is not
currently supported, so we pass `()` through an ignored name.

**Read-and-compare** (`tests/demo_guess.ml`): parse input with
`int_of_string`, branch on the parsed value.

    let rec loop = fun u ->
      let g = int_of_string (read_line ()) in
      if g = 42 then print_endline "correct!"
      else if g < 42 then (print_endline "too low"; loop ())
      else (print_endline "too high"; loop ())
    in loop ()

`int_of_string` raises EVAL ERROR on non-numeric input, so the driver
must feed well-formed integers; the demo has no recovery path.

Run: `just demo-echo-loop`, `just demo-guess`. Regression tests:
`work/reg-rs/demo_echo_loop.rgt`, `work/reg-rs/demo_guess.rgt`.

## What's still missing for richer interactive programs

The echo/guess demos are deliberately small. A text-adventure-class
program additionally wants:

- Lexicographic ordering on strings (`<`, `<=`, etc.) — currently only
  `(=)` and `(<>)` work on `VK_STRING`.
- Char ops: splitting a string into tokens, uppercasing, comparing one
  char of a line. No `String.get`, `String.length`, or `Char.*` yet.
- Graceful `int_of_string` (returning `int option` instead of raising).

These aren't blockers for simple interactive loops but are the
next-most-likely things a demo will reach for.
