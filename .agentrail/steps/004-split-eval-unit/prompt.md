Split the evaluator out of ocaml.pas into a separate unit.

Create src/oc_eval_unit.pas containing:
- Value types (Val, PVal, EnvEntry, PEnv)
- Value constants (VK_xxx)
- Environment functions (env_lookup, env_extend)
- Value constructors (mk_val_int, etc.)
- Built-in name globals and intern procedures
- eval_expr function

Update src/ocaml.pas to be a thin main that imports all units.
All 26 regression tests must still pass.
Verify memory pressure is reduced (more room for heap/stack).