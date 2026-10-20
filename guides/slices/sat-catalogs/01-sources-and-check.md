---
kind: implementation
set: sat-catalogs
repository: sat_mexico
serves: []
skills: [defdo-exunit-quality-tests, defdo-safe-test-data]
---

# Slice SM-01 — Official source manifest and `mix sat.catalogs.check`

Read `guides/decisions/0001-ownership.md` first: data comes from OFFICIAL SAT
sources only; never copy code or data from other open-source projects (concepts
only). No import yet.

## Step 1 — manifest
`priv/sources.json` (or `.exs`), one entry per catalog file: `id`, official file
URL, discovery page URL (the SAT page that links the current file), expected
sheet name and header row, CFDI/complement version, and the last seen
`last_modified`, `etag`, `sha256`. Start with the CFDI 4.0 catalog workbook from
SAT's Anexo 20 page and `catCFDI.xsd` (sat.gob.mx). Verify each URL by hand at
authoring time and record the date checked.

## Step 2 — `mix sat.catalogs.check`
For each source: HEAD for Last-Modified/ETag; if the file name changes, fetch the
discovery page and find the current link; download only when changed, compute
sha256 and compare with the lockfile. Print one line per source
(`unchanged | changed | unreachable`) and exit non-zero when anything changed or
is unreachable. It NEVER rewrites the manifest unless `--update` is given.
HTTP through `Req` (add the dep). Network is injectable for tests.

## Tests
With a fake HTTP adapter (no network): unchanged, changed by ETag, changed by
sha256 with the same ETag, renamed file found through the discovery page,
unreachable; `--update` writes the new values; default run never writes.

## Hygiene
README: purpose = SAT catalog importer and CFDI reader; remove the dead guide
link. Drop the unneeded `Application` supervisor if nothing uses it.

## Verification
```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
git diff --check
```
