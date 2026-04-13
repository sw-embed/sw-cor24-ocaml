# Unit Compilation Notes

Research on p24p multi-unit compilation for the OCaml interpreter.

## Current State

p24p supports `uses units;` which enables:
- `.unit`/`.endunit` directives in .spc output
- `xcall` for cross-unit calls to runtime procs
- Linking with pre-built runtime via `p24-load`
- p24m image format with proper segment layout

## Key Limitation

**The compiler can only produce ONE user unit per compilation.**

There is no mechanism to compile multiple .pas files as separate units
and link them together. Only the runtime (`p24p_rt.p24`) comes as a
separate pre-built unit.

This means the planned split of the interpreter into lexer/parser/eval
units is **not possible** with the current compiler.

## What We Can Do

### Switch to unit-mode build pipeline

Change `src/ocaml.pas` to use `uses units;` and build via:

```
.pas -> p24p -> .spc -> pa24r -> .p24 -> p24-load (+ p24p_rt.p24) -> .p24m
```

Benefits:
- Pre-built runtime (no need to link runtime.spc at compile time)
- p24m format has proper segment headers and bounds
- Potentially better memory layout

### Future: multi-user-unit support

Would require enhancing the compiler to:
- Compile a .pas file as a named unit with exports
- Support importing user-defined units (not just runtime)
- Share type definitions across unit boundaries
- Share globals or provide cross-unit global access

## Build Pipeline (unit mode)

```bash
# 1. Compile to .spc (unit mode)
cor24-run --run p24p.s -u "$(cat src/ocaml.pas)"$'\x04' --speed 0 -n 500000000

# 2. Extract .unit section
sed -n '/^\.unit/,/^\.endunit/p' > build/ocaml.spc

# 3. Assemble
pa24r build/ocaml.spc -o build/ocaml.p24

# 4. Link with pre-built runtime
p24-load build/ocaml.p24 vendor/sw-pascal/v0.1.0/bin/p24p_rt.p24 -o build/ocaml.p24m

# 5. Run on PVM (pre-assembled)
cor24-run --load-binary pvm.bin@0 \
  --load-binary build/ocaml.p24m@0x010000 \
  --patch "CODE_PTR=0x010000" \
  --entry 0 --speed 0 --terminal
```

## Syntax

Unit mode program:
```pascal
program OCaml;
uses Hardware, units;
{ ... code ... }
```

- `uses units;` enables unit mode
- `uses Hardware;` registers LedOn/LedOff/ReadSwitch
- Runtime procs emit `xcall` instead of `call`
- User procs within the unit use regular `call`
