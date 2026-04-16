Characterize the fib trap. No source code changes in this step — pure investigation.

Goal: produce a small markdown table at docs/fib-trap-investigation.md (or in the step summary) showing, for N = 1..12, what 'let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2) in fib N' does on the interpreter:
  - exit status (clean / TRAP code / instruction-budget timeout)
  - last lines of UART output
  - executed-instruction count at end (cor24-run prints 'Executed N instructions')
  - approximate result (when it returns)

Also run a NON-recursive control: a let-chain of the same arithmetic depth, e.g. 'let a = 1 in let b = a + 1 in ... let z = y + 1 in z' for ~50 bindings. This separates "deep recursion / closure churn" from "lots of arithmetic ops".

Use ./scripts/run-ocaml.sh tests/<scratch>.ml with -n 1000000000 (1B) to make sure budget isn't the limit. Capture stderr too.

Write the .ml scratch files under /tmp/ — do not commit them. Only commit docs/fib-trap-investigation.md (or include the table verbatim in the step summary if a doc feels heavy).

Empirically already known: fib 8 returns 21 (succeeds); fib 10 traps with TRAP 4 (INVALID_OPCODE) even with a 1B budget; fib 7 returns 13 (per existing tests/eval_function_form_let.ml). Fill in the rest.

Deliverable: the table + a one-paragraph "what this rules in / out" interpretation at the bottom. Examples of useful interpretations:
  - "Trap kicks in at exactly N=K, instruction count plateaus near M — suggests fixed resource (closure heap / value stack) being exhausted."
  - "Trap N varies run-to-run — suggests UB or memory race."
  - "Non-recursive let-chain of depth 50 succeeds — heap is fine; the trap is recursion-specific."

Do not attempt the fix in this step. The next step diagnoses; the step after fixes or documents.