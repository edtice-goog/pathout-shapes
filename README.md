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
| `unchecked_null_return_deref` | a local receives a may-return-null call (`malloc`, `fopen`, `getenv`, `strchr`, ...), is dereferenced, and is never null-tested in the function | NULL_RETURNS | `NULL_RETURNS`, `FORWARD_NULL` |
| `source_length_into_fixed_buffer` | `strncpy`/`memcpy`/`strncat` into a fixed-size local array, bounded by `strlen(src)` or by a variable that receives it and is never compared (the shape behind CVE-2025-0282) | STRING_OVERFLOW, OVERRUN | `STRING_OVERFLOW`, `OVERRUN`, `BUFFER_SIZE` |
| `unchecked_array_index` | a fixed-size local array indexed by a variable never compared in the function | OVERRUN, NEGATIVE_RETURNS | `OVERRUN`, `NEGATIVE_RETURNS`, `TAINTED_SCALAR` |
| `overflow_before_alloc` | `malloc`/`realloc`/`alloca` size contains `*` or `<<` with a variable operand never compared | INTEGER_OVERFLOW, OVERFLOW_BEFORE_WIDEN | `INTEGER_OVERFLOW`, `OVERFLOW_BEFORE_WIDEN`, `TAINTED_SCALAR` |
| `free_of_nonheap` | `free` of `&x`, a local array, a string literal, or `p + n` | BAD_FREE | `BAD_FREE`, `USE_AFTER_FREE` |
| `nonliteral_format_string` | a `printf`-family call whose format is not a literal and which passes nothing after it | PRINTF_ARGS, FORMAT_STRING_INJECTION | `PRINTF_ARGS`, `FORMAT_STRING_INJECTION`, `TAINTED_STRING` |
| `sizeof_pointer_as_size` | `sizeof` of a pointer variable as the size of `memset`/`memcpy`/`malloc`/... | SIZEOF_MISMATCH, BAD_SIZEOF | `SIZEOF_MISMATCH`, `BAD_SIZEOF` |

## Running

When a defect has escaped, run the one checker for its shape:

```bash
cov-analyze --dir <idir-copy> --disable-default --codexm checkers/<shape>.cxm
cov-format-errors --dir <idir-copy> --json-output-v10 candidates.json
```

When only a PATHOUT is known and no defect yet, every shape is a
hypothesis; run them all in one pass:

```bash
bin/run_all.sh <install>/bin <idir-copy> [outdir]      # -> <outdir>/candidates.json, count per checker
```

It refuses an idir that already has an `output/` (the original
`analysis-log.txt` is what the skill reads first) unless `IN_PLACE=1`. Then
filter to PATHOUT functions with the skill's `tools/pathout_filter.py`,
passing the last column of the table as `--relevant` for each checker's
hits.

`bin/run_fixtures.sh <install>/bin` compiles `fixtures/` and checks each
checker against the `HIT` markers in them.

## What they cannot do, on purpose

No order (CodeXM's `sourceloc` has no fields and `happens-before` is only
valid inside the path-sensitive `sequence()`), no value tracking, no
feasibility, no reassignment. The checkers that need order (use after
free, uninitialized read, lock without unlock) are not here for that reason;
their order-blind approximations were too noisy to be worth a filter.

## Provenance

Every checker was developed against a fixture (`fixtures/shapes.c`,
`fixtures/shapes2.c`, `fixtures/null_check_then_deref.c`), and the first
five were run over the subversion 1.14 + sqlite idir in tool-interop; the
whole catalogue was run over lua, zstd, nginx and redis idirs (counts in
the skill's `CALIBRATION.md`). `source_length_into_fixed_buffer` is the
shape of CVE-2025-0282 (a bounded copy whose bound is the source's own
length). Nothing here came from customer code.

One CodeXM trap is worth stating here because it silently disabled parts
of three of these checkers until 2026-09-10: `exists a in X where P ||
exists b in Y where Q` parses as ONE `exists` with the second nested in the
first's `where`, so an empty X makes the whole disjunction false.
Parenthesize every `exists` in an `||` chain.
