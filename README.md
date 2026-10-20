# SAT Mexico

An Elixir library that imports reference catalogs from official SAT sources and reads Mexican CFDI XML.

## Features

- CFDI XML Parsing: Transform CFDI (Comprobante Fiscal Digital por Internet) invoices from XML format to structured Elixir maps
- ISR Tax Reporting: Generate withholding tax (ISR - Impuesto Sobre la Renta) reports from invoice data
- Batch Processing: Process multiple invoices from directories, including nested XML files and ZIPs
- SAT Compliant: Implements official SAT rounding rules and tax calculations
- Reference Data: Checks official SAT source files and includes catalogs for tax regimes and CFDI usage codes

### Check SAT source revisions

Run `mix sat.catalogs.check` to compare the packaged source manifest with the
current links on SAT's Anexo 20 page. It prints one status line per source and
returns a non-zero exit status if any source changed or is unreachable. Pass
`--update` to write the new metadata and SHA-256 hashes to `priv/sources.json`.

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

For more detailed examples, see the [ISR Report Guide](lib/sat/guides/isr_report.md).

## Reference Data

The library includes comprehensive reference data for:

- Tax Regimes: Complete catalog of Mexican tax regimes with validity dates and applicability
- CFDI Usage Codes: Full catalog of CFDI usage codes with descriptions and validity information

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
