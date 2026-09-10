# pathout-shapes

Path-**insensitive** CodeXM checkers, one per defect *shape*, for hunting the
siblings of a defect that escaped Coverity because its function exceeded
the path limit (PATHOUT). They are deliberately noisy: they reason about
structure only, and are meant to be run over a whole intermediate directory
and then filtered to the PATHOUT functions where the corresponding
path-sensitive checker was cut off. The procedure, the filter and the
confirmation step live in the
[`coverity-pathout` skill](https://github.com/edtice-goog/CoveritySkills/tree/master/coverity-pathout)
(`references/escape-hunt.md`); this repository is only the checkers.

| checker | shape | stands in for | relevant components for the filter |
|---|---|---|---|
| `null_check_then_deref` | a pointer null-tested somewhere in the function and dereferenced where no test of it guards | FORWARD_NULL, REVERSE_INULL, NULL_RETURNS | `FORWARD_NULL`, `NULL_RETURNS` (`REVERSE_INULL` as a second pass) |
| `zero_check_then_divide` | an integer tested against zero and used as a divisor where no test guards | DIVIDE_BY_ZERO | `DIVIDE_BY_ZERO` |
| `double_free` | the same variable passed to a releasing call at two sites in one function | USE_AFTER_FREE (double free) | `USE_AFTER_FREE` |
| `unbounded_copy_into_fixed_buffer` | a fixed-size local array receives `strcpy`/`strcat`/`sprintf`/`gets` | STRING_OVERFLOW, OVERRUN | `STRING_OVERFLOW`, `OVERRUN` |
| `alloc_never_released` | a local receives an allocator's result and is never freed, passed, returned or stored | RESOURCE_LEAK (the leaks-on-every-path subset) | `RESOURCE_LEAK` |

## Running

```bash
cov-analyze --dir <idir-copy> --disable-default --codexm checkers/<shape>.cxm
cov-format-errors --dir <idir-copy> --json-output-v10 candidates.json
```

`bin/run_fixtures.sh <install>/bin` compiles `fixtures/` and checks each
checker against the `HIT` markers in them.

## What they cannot do, on purpose

No order (CodeXM's `sourceloc` has no fields and `happens-before` is only
valid inside the path-sensitive `sequence()`), no value tracking, no
feasibility, no reassignment. The checkers that need order (use after
free, uninitialized read, lock without unlock) are not here for that reason;
their order-blind approximations were too noisy to be worth a filter.

## Provenance

Every checker was developed against a fixture and then run over the
subversion 1.14 + sqlite idir in tool-interop. The numbers are recorded in
the skill's `CALIBRATION.md`. Nothing here came from customer code.
