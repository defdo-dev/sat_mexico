---
kind: implementation
set: sat-catalogs
repository: sat_mexico
serves: []
skills: [defdo-exunit-quality-tests, defdo-safe-test-data]
---

# Slice SM-02 — Importer core: c_RegimenFiscal and c_UsoCFDI from SAT

Depends on SM-01. Official SAT data only; no OSS code or data (concepts only).

## Step 1 — importer core
`mix sat.catalogs.import` reads the official workbook listed in the manifest
(converted to CSV in a CI-only step if the format needs it; nothing at runtime),
asserts the exact header row per sheet (fail loudly on any change), and maps to
typed rows: `code`, `description`, `valid_from`, `valid_to` (nil = open),
catalog-specific fields, and `source_revision` on every row. Output: committed
`priv/catalogs/<revision>/<catalog>.json` (reviewable diffs).

## Step 2 — the two catalogs
c_RegimenFiscal (física/moral flags) and c_UsoCFDI (física/moral flags, allowed
receptor regimes). Generated from the official file, not hand-typed.

## Step 3 — compatibility
`SAT.TaxRegime` and `SAT.CFDIUsage` keep every public function and return shape
my_mvno uses (grep defdo_my_mvno for the calls; list them in the slice's
commit) but read from the imported data. Mark the old shape `@deprecated` where
a new API replaces it.

## Tests
Importer tests use small fixture sheets WE author in the official layout
(synthetic rows); a header change fails with a clear error; the compatibility
functions return the same results as before for every code in the current list.

## Verification
```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
git diff --check
```
