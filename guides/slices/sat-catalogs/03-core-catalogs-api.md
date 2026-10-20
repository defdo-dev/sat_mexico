---
kind: implementation
set: sat-catalogs
repository: sat_mexico
serves: []
skills: [defdo-exunit-quality-tests]
---

# Slice SM-03 — CFDI 4.0 core catalogs and the `SAT.Catalog` lookup API

Depends on SM-02. Official SAT data only; no OSS code or data.

## Step 1 — catalogs
Import c_TipoDeComprobante, c_FormaPago, c_MetodoPago, c_Impuesto, c_TipoFactor,
c_ObjetoImp, c_TipoRelacion, c_Exportacion, c_Moneda (with decimals),
c_Periodicidad, c_Meses. c_TasaOCuota is a RULE table (ranges, duplicate keys):
model it as rules, not a key→value lookup.

## Step 2 — API
`SAT.Catalog.fetch(catalog, code, on: date)`, `valid?(catalog, code, on: date)`,
`list(catalog, on: date)`, `revision/0`. Lookups from compile-time data or
`persistent_term`; no database. Old revisions stay readable.

## Tests
Per catalog: a code valid on a date, not valid before `valid_from` / after
`valid_to`; unknown code; TasaOCuota range checks; `revision/0` matches the
committed data.

## Verification
```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
git diff --check
```
