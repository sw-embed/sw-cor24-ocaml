# Possible Features

This document lists standard or near-standard OCaml features that could make
sense for the COR24 OCaml subset, but are tabled for now in favor of the
new Tuplet-support issues.

The target remains integer-only and software-divide-only, so features should be
judged by their value for embedded protocol/state-machine/compiler code versus
their parser, evaluator, heap, and runtime cost.

## Currently Prioritized for Tuplet

The active work should follow the open GitHub issues filed for hosting Tuplet:

| Issue | Feature | Why It Comes First |
| --- | --- | --- |
| #5 | Multi-line match expressions | Tuplet lexer/parser/checker code is dominated by long matches; one-line arms are the largest readability gap. |
| #6 | Mutable references: `ref`, `!`, `:=` | Tuplet needs registries, environments, and symbol tables without threading state through every parser/checker call. |
| #7 | Record types and field access | Tuplet AST and signatures naturally have named fields; positional variants obscure intent. |
| #8 | List combinators | `List.map`, `List.fold_left`, and friends reduce repeated traversal code in compiler passes. |
| #9 | Block comments | Tuplet lexer/parser code needs inline explanations for byte-level and grammar decisions. |
| #10 | Char literals and `Char.code` / `Char.chr` | Replaces ASCII magic numbers in Tuplet's lexer with readable literals. |
| #11 | Exceptions or `Result` | Tuplet parser/checker/runtime paths need composable error propagation. |

## Tabled Feature Ideas

These features are plausible, but should wait until the Tuplet-support issues
above are handled or reprioritized.

| Feature | Fit for COR24 | Notes |
| --- | --- | --- |
| `let ... and ...` | Good | Useful syntax polish for related bindings. Low runtime impact, but less urgent than records/refs/matches. |
| Broader `let rec f x y = ...` compatibility | Good | Existing function sugar covers much of this; remaining gaps can be fixed when found by real Tuplet code. |
| Pattern aliases: `p as x` | Good | Helps avoid recomputation in patterns, but not currently blocking. |
| Or-patterns: `A | B -> ...` | Good | Useful in parsers; may be considered after multi-line match support. |
| `begin ... end` grouping | Good | Parser-only convenience. Could be a small follow-up once the bigger parser readability issues are fixed. |
| Bitwise integer operators: `land`, `lor`, `lxor`, `lsl`, `lsr`, `asr` | Very good | Strong fit for embedded code. More important for byte/protocol work than for Tuplet's immediate parser needs. |
| Small integer helpers: `abs`, `min`, `max`, `succ`, `pred`, `ignore` | Good | Cheap built-ins; useful but easy to work around. |
| Mutable arrays or byte buffers | Very good | Likely valuable for embedded and compiler workloads, but higher runtime/heap design cost than refs. |
| Fixed-width helpers: byte/word conversions, `get_byte`, `set_byte` | Good target extension | Not standard OCaml, but useful for COR24. Should be designed as target-specific APIs. |
| File-scoped `open Module` | Mixed | Convenient after module MVP, but qualified names are clearer and avoid ambiguity for now. |
| `.mli`-style interfaces | Later | Helpful only once multi-file programs grow; adds interface checking/design weight. |
| Full exceptions with arbitrary payloads | Mixed | Issue #11 may choose a smaller `Result` path first. Full exception machinery can wait. |
| `for` / `while` loops | Mixed | Useful with refs/arrays; can be revisited after mutable state exists. |

## Probably Out of Scope for This Target

These features are either too large for the current interpreter or poorly
matched to an integer-only embedded target:

- floats
- `Int64` / `Nativeint`
- objects and classes
- functors
- polymorphic variants
- GADTs
- full Hindley-Milner type inference
- full OCaml standard library compatibility
- separate compilation and object-level linking

## Guidance

Prefer features that:

- make Tuplet source shorter or clearer;
- avoid large runtime structures;
- preserve simple whole-program execution;
- improve embedded byte/protocol/state-machine code;
- can be validated with small `.ml` fixtures and reg-rs baselines.

Defer features that mostly improve source compatibility with desktop OCaml but
do not help Tuplet or COR24 programs directly.
