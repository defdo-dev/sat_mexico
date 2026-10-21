# SM-01c — owner exception round (final): filename on URL move

Read `01-sources-and-check.md` and `01b-review-fixes.md`; all still holds. Scope is exactly this:

1. `lib/sat/catalogs/check.ex` (~line 74): when the response has no Content-Disposition (live omawww sends none), derive the filename from the URL's last path segment instead of keeping the old manifest value. Test: discovery page links `documentos/catCFDI_V_4_20270115.xls`, no Content-Disposition → `--update` writes that URL AND filename `catCFDI_V_4_20270115.xls`.
2. The new-filename test and the newer-URL test in `test/sat/catalogs/check_test.exs` keep the ETag CONSTANT, so each isolates URL/filename detection.
3. Drop `mix credo --strict` from the 01/01b acceptance text (the repo has no credo).
4. Complete CHANGELOG Unreleased: Elixir requirement 1.14 → 1.15, new `req`/`jason` runtime deps, removal of `SAT.Application`; and do not claim the checker verifies sheets/header rows (it never opens the workbook).

## Verification
```sh
set -o pipefail
mix format --check-formatted
mix compile --warnings-as-errors
mix test
git diff --check
```

Escalation: two failed attempts → stop and report. Never run `mix ecto.drop`/`ecto.reset`; never print secrets.
