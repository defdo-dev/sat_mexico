# SAT Mexico

SAT Mexico reads CFDI XML and is developing an importer and date-aware lookup
for reference catalogs published by Mexico's tax authority (SAT). Catalog data
will come from official SAT sources; catalog import and lookup are still under
development.

## Current features

- Parse CFDI XML into structured Elixir data with `SAT.InvoiceHandler`.
- Check the official SAT catalog source files recorded in `priv/sources.json`:
  `mix sat.catalogs.check` reports whether each source is unchanged, changed,
  or unreachable. It uses the discovered URL and HTTP Last-Modified/ETag values
  to decide when to download and refresh a file's SHA-256. It updates the
  manifest only when run with `--update`.

## Installation

Add `sat_mexico` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sat_mexico, "~> 0.2.0"}
  ]
end
```

## Parsing a CFDI invoice

```elixir
{:ok, document} = File.read("path/to/invoice.xml")
{:ok, invoice} = Saxy.parse_string(document, SAT.InvoiceHandler, [])

invoice.total
invoice.currency
invoice.issuer.tax_id
```

## Documentation

Full documentation is available at <https://hexdocs.pm/sat_mexico>.

## License

SAT Mexico is licensed under Apache-2.0. See [LICENSE.md](./LICENSE.md).
