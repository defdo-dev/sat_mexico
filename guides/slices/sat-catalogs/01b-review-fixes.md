# SM-01b — review fixes for 01-sources-and-check

Serves: the same product scenarios as `01-sources-and-check.md`. Read that slice and
`00-conventions.md` first; everything they require still holds.

## Scope
Fix every finding below on top of the 01 branch. Nothing else changes. Do not
remove or weaken existing tests.

## Findings to fix (opus review da32cc02, round 1)
- FINDING P1 priv/sources.json:8 — The workbook is discovered from the border-region stimulus page instead of SAT's Anexo 20 page, as the slice requires. It pins catCFDI_V_4_20250213.xls, while http://omawww.sat.gob.mx/tramitesyservicios/Paginas/anexo_20.htm links catCFDI_V_4_20261015.xls (48774656 bytes, Last-Modified 2026-10-15, stable ETag). Today's live run prints "cfdi-4.0-catalogs unchanged" and exits 0, so SM-02 would import a stale revision; fix: point discovery_page_url at the Anexo 20 page with link text "Catálogos CFDI Versión 4.0 (xls)", track its documentos/catCFDI_V_4_20261015.xls with real ETag, Last-Modified and sha256 and last_modified_reliable true, and re-verify expected_sheets against that file.
- FINDING P1 lib/sat/catalogs/check.ex:51 — current_source only fetches the discovery page when the old URL returns 404 or a different Content-Disposition filename. SAT keeps superseded files live: catCFDI_V_4_20250213.xls still returns 200 after the 20261015 release. A probe with the old URL live and the discovery page linking a new file returned unchanged without ever fetching the page; fix: fetch the discovery page on every run, resolve the current link, and report changed when its URL or filename differs from the manifest.
- FINDING P2 priv/sources.json:37 — The XSD source is a zip from the "Reforma Fiscal 2022" page. Its catCFDI.xsd is dated 2022-02-24 and differs from SAT's canonical http://www.sat.gob.mx/sitio_internet/cfd/catalogs/catCFDI.xsd (Last-Modified 2024-12-13), which adds c_Moneda CNH, ESD, NIC, UYP and VES, one c_ClaveProdServ code, and c_ObjetoImp 04 to 08; fix: track the canonical XSD URL linked from the Anexo 20 page, which answers HEAD with a stable ETag so there is no need to download it every run, and drop archive_member.
- FINDING P3 lib/sat/catalogs/check.ex:30 — The update path re-encodes the whole manifest with keys sorted alphabetically and sheet objects expanded. Changing one hash in the real manifest produced a diff of 78 insertions and 36 deletions; fix: commit priv/sources.json in Jason's pretty output form, or decode with objects: :ordered_objects so key order survives.
- FINDING P3 lib/sat/catalogs/check.ex:214 — content_length calls String.to_integer outside the rescue in call_http. A malformed Content-Length such as "12 " raises ArgumentError out of check/2 instead of marking the source unreachable; fix: parse with Integer.parse and treat invalid values as nil.
- FINDING P3 lib/sat/catalogs/check.ex:183 — normalize_link_text decodes only &nbsp;, &#160; and &amp;. A link written as Cat&aacute;logos returned discovery_link_not_found, and the same SAT pages already use &aacute; in their body text; fix: decode named and numeric HTML entities before comparing link text.
- FINDING P3 lib/sat/catalogs/check.ex:10 — The default manifest path is relative to the current directory, but priv and the task now ship in the Hex package. Calling check/0 from another directory returned {:error, :enoent}; fix: read the packaged manifest through Application.app_dir(:sat_mexico, "priv/sources.json") and use the repo path only for the update flag, or keep the task out of the package.
- FINDING P3 mix.exs:12 — The project still declares Elixir ~> 1.14, but the new req 0.7.5, finch 0.24 and mint 1.11 dependencies require Elixir ~> 1.15; fix: raise the project requirement to ~> 1.15.
- FINDING P3 test/sat/catalogs/check_test.exs:52 — No test covers the path both real sources take on every run: no validator, body hashed, sha256 equal, result unchanged. Nothing tests the branch where the same URL serves a new filename, or the task's exit status and update flag; fix: add a hashed-but-unchanged case, a 200-with-new-filename discovery case, and a task-level test with an injectable HTTP function.
- FINDING P3 lib/mix/tasks/sat.catalogs.check.ex:1 — The task has no @moduledoc, so mix help sat.catalogs.check prints "There is no documentation for this task". The update flag and exit codes are documented nowhere, including the README; fix: add a @moduledoc that describes the output lines, the exit codes and the update flag.

## Rules
- Live SAT URLs are verified by hand when writing the manifest (record ETag,
  Last-Modified, sha256). Tests never hit the network; they use the injectable
  HTTP function.
- Never print a credential. Never run `mix ecto.drop`/`reset`.

## Acceptance gate
- `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`,
  `mix credo --strict`, `git diff --check` all pass.
- New tests exist for: hashed-but-unchanged, the same URL serving a new filename,
  the discovery page linking a newer file while the old URL is still live, an
  invalid Content-Length, an `&aacute;` link text, the task exit status, and the
  update flag.
- CHANGELOG Unreleased lists the fixes.
