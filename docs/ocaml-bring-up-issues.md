# OCaml Interpreter Bring-Up Issues

Detailed analysis of the unit-mode build pipeline and the input
reading issue blocking the OCaml interpreter.

## What Works

### Unit-mode pipeline (no input)

Programs that only produce output work correctly:

```
program TestUnitMode;
uses units;
begin
  writeln(42)
end.
```

Build: p24p -> pa24r -> p24-load -> pvm.bin + image.p24m -> cor24-run
Output: `42` (correct, ~14K instructions)

### Old pipeline (with input)

The non-unit pipeline works for reading input:

```
cor24-run --run pvm.s
  --load-binary ocaml.bin@0x010000
  --load-binary code_ptr.bin@CODE_PTR
  -u "42\x04" --speed 0 -n 500000000
```

This uses `--run pvm.s` (assembles PVM inline) and the old
single-module .spc -> pl24r -> pa24r -> relocate pipeline.

## What Does Not Work

### Unit-mode pipeline with UART input

The OCaml interpreter reads source from UART via `read(ch)` in a
loop until `eof` returns true. In unit mode:

```
cor24-run --load-binary pvm.bin@0
  --load-binary ocaml.p24m@0x010000
  --patch "0x1047=0x010000"
  --entry 0 -u "42\x04" --speed 0 -n 2000000000
```

Result: reads first character '4', then spins consuming 654M+
instructions without progress. Never reaches `eof`.

## Detailed Execution Trace

### Build Steps

1. **Compile**: `cor24-run --run p24p.s -u "$(cat ocaml.pas)\x04"`
   - p24p runs on COR24 emulator, reads Pascal source from UART
   - Outputs .spc assembly to UART
   - `uses Hardware, units;` enables unit mode
   - Output contains `.unit ocaml`, `.import p24p_rt`, `.extern` decls
   - Uses `xcall` for runtime calls, `call` for intra-unit calls
   - Status: WORKS (compilation succeeds, ~270M instructions)

2. **Assemble**: `pa24r ocaml.spc -o ocaml.p24`
   - Converts .spc text assembly to .p24 v2 binary
   - Preserves unit metadata, import/export tables
   - Status: WORKS

3. **Link**: `p24-load ocaml.p24 p24p_rt.p24 -o ocaml.p24m`
   - Combines user code + runtime into multi-unit image
   - Resolves imports against exports
   - Builds Import Resolution Tables (IRTs)
   - Patches code relocations (jmp/call targets, global offsets)
   - Output: .p24m with header, unit table, IRTs, code, globals
   - Status: WORKS

4. **Pre-assemble PVM**: `cor24-run --assemble pvm.s pvm.bin pvm.lst`
   - Assembles PVM to native COR24 binary
   - Extracts `code_ptr` label address from listing
   - Status: WORKS (code_ptr @ 0x1047)

### Runtime Steps

5. **Load**: `cor24-run --load-binary pvm.bin@0 --load-binary ocaml.p24m@0x010000 --patch "0x1047=0x010000" --entry 0`
   - PVM binary loaded at address 0
   - OCaml p24m image loaded at 0x010000
   - code_ptr at 0x1047 patched to point to 0x010000 (image base)
   - Entry point: 0 (PVM's _start)
   - Status: WORKS

6. **PVM boot** (`_start` in pvm.s):
   - Initializes vm_state: pc=0, esp, csp, gp, hp
   - Reads code_ptr (0x1047) -> 0x010000
   - Prints "PVM OK\n" via UART
   - Detects magic "P24M" at 0x010000 -> enters init_p24m
   - Parses p24m header: entry_point, unit_count, code/globals offsets
   - Sets vm_state.code, gp, irt_base, unit_table_ptr
   - Jumps to vm_loop with pc = entry_point
   - Status: WORKS (PVM OK printed)

7. **User main begins**:
   - First instructions: `enter 0`, `xcall _p24p_io_init`, `xcall _p24p_heap_init`
   - `_p24p_io_init`: initializes I/O state, reads LOOKAHEAD character
   - `_p24p_heap_init`: initializes heap tracking
   - Status: PARTIALLY WORKS (io_init runs)

8. **io_init reads lookahead**:
   - The runtime's `_p24p_io_init` reads one character ahead (lookahead)
   - This consumes the first byte of UART input
   - For input "42\x04": lookahead = '4', remaining UART = "2\x04"
   - Status: THIS IS THE LIKELY ISSUE

9. **lex_init calls read(ch) in a loop**:
   - Pascal `read(ch)` compiles to `xcall _p24p_read_char`
   - `_p24p_read_char` uses sys 2 (GETC) which polls UART
   - With `-u "42\x04"`: UART buffer has '4', '2', '\x04' preloaded
   - io_init consumed '4' as lookahead
   - First read(ch) should get '4' from lookahead, then read '2' from UART
   - `eof` checks if lookahead == chr(4) (EOT)
   - Status: FAILS -- spins after reading '4'

## Root Cause Hypothesis

The `_p24p_io_init` lookahead mechanism and the `_p24p_eof`
implementation may have a timing or state issue in unit mode:

1. io_init reads the first char ('4') into a lookahead global variable
2. The first `read(ch)` returns the lookahead ('4') and reads ahead
   the next char ('2') -- but this second GETC (sys 2) may be
   blocking because the UART buffer timing is different in
   `--load-binary` mode vs `--run` mode
3. Or the lookahead global variable is in unit 0's global space
   but the runtime (unit 1) writes to unit 1's global space --
   a cross-unit global access bug

Specific questions:
- Is the io_state (lookahead buffer) stored as a runtime global?
- Does the user code access it correctly via xloadg/xstoreg?
- When the runtime's io_init sets the lookahead, is it visible
  to the runtime's eof function?
- Is sys 2 (GETC) blocking differently with -u preloaded data
  vs --terminal live input?

## What Needs Investigation

1. **Add debug output to io_init**: print the lookahead char after
   io_init to verify it reads correctly

2. **Test eof separately**: write a minimal unit-mode program that
   does `while not eof do read(ch)` and see if it terminates

3. **Check UART buffer with -u**: verify that all bytes from -u
   are available to sys 2 GETC when using --load-binary mode

4. **Check cross-unit globals**: verify that runtime globals
   (io_state) are accessible from runtime procedures after
   xloadg/xstoreg patching by p24-load

## Alternative Approaches

### A: Memory-mapped source (SNOBOL4 pattern)

Load source at fixed address (0x080000) via --load-binary.
Interpreter reads via peek() instead of read().
Pro: decouples source loading from UART
Con: not good for REPL, requires changing lex_init

### B: Fix the UART/eof issue

Debug and fix why read(ch)/eof loop doesn't terminate in unit mode.
This is the better long-term fix since it enables both batch
and REPL modes.

### C: Hybrid

Use --terminal mode. Pipe source into stdin of cor24-run.
The emulator feeds stdin to UART. After source ends (EOF),
UART returns nothing and eof becomes true.

## File References

- src/ocaml.pas -- interpreter source (lex_init at line 111)
- scripts/build.sh -- unit-mode build pipeline
- scripts/run-ocaml.sh -- execution wrapper
- vendor/sw-pascal/v0.1.0/bin/p24p_rt.p24 -- pre-built runtime
- vendor/sw-pcode/v0.1.0/bin/pvm.s -- PVM source
- Runtime io_init: runtime/runtime-unit.spc (in Pascal compiler repo)
- PVM GETC: pvm.s sys_getc handler (polls UART status port)
