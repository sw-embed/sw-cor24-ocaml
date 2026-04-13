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

Evaluator complete. The interpreter can lex, parse, and evaluate
the full Phase 0 subset including recursive functions:

```
let rec fact = fun n -> if n = 0 then 1 else n * fact (n - 1) in print_int (fact 5)
```

outputs `120`.

Next step: wire into a standalone COR24 binary (main integration).
See `docs/plan.md` and `.agentrail/` for saga tracking.

## Quick Start

```bash
./scripts/vendor-fetch.sh           # fetch vendored toolchain
just test                            # run 17 regression tests
just smoke                           # run Pascal smoke tests
./scripts/run-eval-test.sh tests/eval_fact.ml 500000000   # run factorial
```

## Documentation

- `docs/prd.md` -- Product requirements
- `docs/architecture.md` -- System architecture and runtime stack
- `docs/design.md` -- Grammar, AST, and value representations
- `docs/plan.md` -- Implementation plan
- `docs/research.txt` -- Research notes on OCaml implementation strategy

## License

MIT License. See `LICENSE` for details.
