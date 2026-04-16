Build read_line : unit -> string on top of getc.

## Scope

Add a read_line built-in that reads characters via getc until newline (0x0A) or carriage return (0x0D), returning the accumulated bytes as a VK_STRING value. This is the second input primitive — once this exists, idiomatic interactive OCaml becomes possible (match on read_line () results, etc.).

## Design

- Read into the existing string_pool (mirror how print_endline / mk_val_string produce strings).
- Terminator: LF (10) or CR (13). Eat a following LF after a CR so CR LF and LF both work. Neither terminator is included in the returned string.
- Backspace (8 or 127) erases the last char and echoes backspace-space-backspace, matching lex_init's behavior — so the user sees their input if they're typing live.
- Echo each typed char to UART (again, mirror lex_init). For automated drivers feeding input via OCAML_STDIN, the echo is harmless.
- Empty line → empty string.
- No EOF handling beyond what getc already does (blocking on sys_getc is fine — that IS waiting for input).

## Implementation sketch

In src/ocaml.pas:
1. Add read_line_noff, read_line_nlen globals.
2. Intern 'read_line' (9 chars). Add the intern call to the main init sequence.
3. Add VAR-lookup dispatch returning a closure.
4. Add apply dispatch that:
   - Records string_pool_len as start.
   - Loops: read(ch) via getc (handle leading 0x04 same way as getc does, or rely on getc itself).
   - Actually cleaner: reuse the existing getc_ch path. Or just call read(ch) directly and replicate the EOT-skip.
   - On LF/CR: break. On CR, do one more read — if the next is LF, consume it; otherwise (tricky — can't un-read without a lookahead). Simplest: treat CR alone as terminator, and if the driver sends CRLF we'll get an empty read_line next time. Document this choice.
   - On backspace: decrement the in-progress length in string_pool (if > start), echo BS-space-BS.
   - Else: echo the char, append to string_pool.
   - Return mk_val_string(start, string_pool_len - start).

## Testing

tests/eval_read_line_echo.ml:
    let s = read_line () in print_endline s

Run with OCAML_STDIN='hello\n' — should output 'hello'. Register as a regression test with expected output. Also try an input with no trailing newline terminated by the emulator running out of -u bytes — the program should block (test with a timeout is fine) or, better, with OCAML_STDIN='hello\n'.

## Deliverables

- src/ocaml.pas: read_line built-in
- tests/eval_read_line_echo.ml smoke test
- work/reg-rs/eval_read_line_echo.{rgt,out} registered
- justfile: demo-readline target
- docs/stdin-and-getc.md updated with read_line notes

## Scope discipline

- Do not implement the guess-the-number or echo-loop demo yet — that's step 003.
- Do not start the text adventure — step 004.
- Keep the implementation simple: a tight loop over getc. No special String.sub or trimming.