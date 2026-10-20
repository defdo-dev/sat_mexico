# Decision: sat_mexico and defdo_cfdi ownership (SM-00, owner-approved 2026-10-20)

- **sat_mexico** (public, Apache-2.0, Hex-public, no database) owns SAT reference
  data and reading: it imports SAT catalogs from OFFICIAL SAT sources only,
  answers lookups by date (`valid_from`/`valid_to`, catalog revision), and reads
  CFDI XML.
- **defdo_cfdi** (private) owns issuing: CFDI emission, PAC integration, signing,
  cancellation, storage. It depends on sat_mexico for catalogs and keeps NO copy
  of catalog data.
- **No copying from open-source projects.** Code and data from other CFDI/SAT
  projects (for example phpcfdi, satcfdi or catalog dumps) is never copied,
  vendored or ported. They may be read for concepts only. Catalog data comes
  from SAT's own published files; fixtures are written by us.
