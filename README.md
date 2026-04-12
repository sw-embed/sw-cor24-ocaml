# sw-cor24-ocaml

An integer-subset OCaml interpreter for the COR24 embedded platform,
implemented in Pascal and hosted on the P-code VM.

## Overview

This project adds an ML-family functional language to the COR24
language tower. The interpreter is a tree-walk design written in Pascal,
compiled to P-code, and executed on the P-code VM which itself runs as
an AOT-compiled native COR24 binary.

## Language Subset (Phase 0)

- Integer literals and arithmetic
- Variables and let bindings
- Conditionals (if/then/else)
- First-class functions and closures
- Built-in `print_int` for output

## Project Status

Initial spike in progress. See `docs/plan.md` for the step-by-step plan
and `.agentrail/` for saga tracking.

## Documentation

- `docs/prd.md` -- Product requirements
- `docs/architecture.md` -- System architecture and runtime stack
- `docs/design.md` -- Grammar, AST, and value representations
- `docs/plan.md` -- Implementation plan
- `docs/research.txt` -- Research notes on OCaml implementation strategy

## License

MIT License. See `LICENSE` for details.
