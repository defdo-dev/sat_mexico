# SAT Mexico

sat_mexico is the Elixir library for importing official SAT catalogs and reading CFDI XML. It currently provides CFDI parsing, ISR reporting, and a source manifest/checker for official SAT files. Catalog imports and date-aware catalog lookups are still pending.

## Features

- CFDI XML parsing into structured Elixir maps
- ISR withholding reports from invoice data
- Batch processing of XML and ZIP files in nested directories
- SAT source tracking for the CFDI 4.0 catalog workbook and catalog schema
- Existing tax regime and CFDI usage helpers; catalog importing and date-aware lookups are pending

## Installation

Add sat_mexico to your list of dependencies in mix.exs:

```elixir
def deps do
  [
    {:sat_mexico, "~> 0.2.0"}
  ]
end
```

## Usage

### Parsing CFDI Invoices

```elixir
# Parse a single XML invoice
{:ok, document} = File.read("path/to/invoice.xml")
{:ok, invoice} = Saxy.parse_string(document, SAT.InvoiceHandler, [])

# Access invoice data
invoice.total          # => "2944.00"
invoice.currency       # => "MXN"
invoice.issuer.tax_id  # => "SAT970701NN3"
```

Generating ISR Reports

```elixir
# Process all XML and ZIP files in a directory and its subdirectories
withholdings = SAT.Report.ISR.withholdings("/path/to/invoices")

# Get a detailed summary with SAT rounding applied
result = withholdings
  |> SAT.Report.ISR.withholdings_summarize_detailed()
  |> SAT.Report.ISR.round_withholdings_detailed()

# Print the results
Enum.each(result, fn %{tax_id: tax_id, incoming: incoming, withheld: withheld} ->
  IO.puts("Tax ID: #{tax_id}, Total: #{incoming}, Withheld: #{withheld}")
end)
```

## Catalog Sources

Check the pinned official SAT source files with:

```sh
mix sat.catalogs.check
```

The command prints one status per source and exits non-zero if a source changed or could not be reached. Pass `--update` to write the current URLs, HTTP metadata, and SHA-256 values to `priv/sources.json`.

## Documentation

Full documentation is available at <https://hexdocs.pm/sat_mexico>.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (git checkout -b feature/amazing-feature)
3. Commit your changes (git commit -m 'Add some amazing feature')
4. Push to the branch (git push origin feature/amazing-feature)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE.md](./LICENSE.md) file for details.

## About

SAT Mexico is maintained by [defdo](https://defdo.dev).
