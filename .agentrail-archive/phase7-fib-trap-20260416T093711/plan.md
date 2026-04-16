Investigate why naive 'let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2) in fib 10' traps with TRAP 4 (INVALID_OPCODE) on the COR24 OCaml interpreter, even with a 1-billion instruction budget. Empirically: fib 8 returns 21; fib 10 traps. fib 10 makes ~177 recursive calls at depth 10, so the failure is not algorithmic — something in the runtime is failing.

TRAP 4 = INVALID_OPCODE in pvm.s, meaning the program counter landed on a byte that is not a valid p-code opcode. Two broad causes:
  (a) PC jumped off the end of valid code (bad jmp/call/ret target)
  (b) Code memory was overwritten by the heap, value stack, or activation records

This matters because fib is THE canonical OCaml demo and "fib 10 doesn't work" is a credibility problem. It is also likely foundational — if there is a heap/stack/closure bug here, every recursive program with non-trivial depth is at risk.

Plan (3 short steps):

1. Characterize: write a tiny shell/test driver that runs 'fib N' for N=1..12, capturing the smallest failing N, the exit reason for each, and (where possible) the executed-instruction count at failure. Compare against a non-recursive baseline (e.g. let-binding chain of similar arithmetic depth) to separate "recursion depth" from "data heap consumption". Output a small markdown table. No code changes in this step.

2. Diagnose: based on (1)'s failing N, instrument or trace to determine whether the trap is (a) bad PC target, or (b) overwritten code memory. Likely tools: cor24-run trace mode, examining the .p24m layout, watching PC at the trap site. Look at how closures/activation records are allocated and freed (or not) per recursive call. Identify the root cause — write it up in a short doc, but do not yet fix.

3. Fix or document the limit: if root cause is small (e.g. an off-by-one in allocator, missing release of an activation record, stack pointer not advancing correctly), fix it and add a regression test (canonical_fib.ml with fib 10). If the cause is structural (e.g. fixed value-stack size that genuinely cannot hold fib 10's frames), document the limit clearly, add a guard that reports a clean error instead of TRAP 4, and add a regression test for the largest N that does work plus a test that confirms the new clean error for too-large N.

Hard constraint: src/ocaml.pas is approaching the p24p ~65KB Pascal-source limit. Any fix must be compact or paid for by removing older code. Measure before committing.

Out of scope: rewriting the activation-record / closure / stack model from scratch; adding GC; adding tail-call elimination. If the diagnosis points there, that becomes its own saga, not work inside this one.