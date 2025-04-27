# SAT Mexico ISR Report

This tutorial will guide you through using the SAT.Report.ISR module to generate ISR (Impuesto Sobre la Renta) reports from your SAT XML invoices.

## Overview

The SAT.Report.ISR module helps you process SAT XML invoices to extract and summarize ISR tax withholding information. It supports:

- Processing individual XML files
- Processing ZIP files containing XML files
- Searching in nested directories
- Summarizing withholding data
- Rounding according to SAT rules

## Basic Usage

### 1. Generate Withholding Report

```elixir
# Basic usage - process all XML and ZIP files in a directory and its subdirectories
withholdings = SAT.Report.ISR.withholdings("/path/to/your/invoices")

# Disable nested directory search (only process files in the top directory)
withholdings = SAT.Report.ISR.withholdings("/path/to/your/invoices", false)
```

The withholdings/2 function returns a map where:

- Keys are the retainer tax IDs
- Values are lists of records containing:
  - retainer_tax_id : The tax ID of the entity that withheld the tax
  - amount_incoming : The total invoice amount
  - amount_withheld : The ISR tax amount withheld

### 2. Summarize Withholding Data

```elixir
# Get a simple summary as tuples {tax_id, total_incoming, total_withheld}
summary = SAT.Report.ISR.withholdings_summarize(withholdings)

# Get a detailed summary as maps with keys :tax_id, :incoming, :withheld
detailed_summary = SAT.Report.ISR.withholdings_summarize_detailed(withholdings)
```

### 3. Apply SAT Rounding Rules

```elixir
# Round according to SAT rules (as tuples)
rounded = SAT.Report.ISR.round_withholdings(withholdings)

# Round according to SAT rules (as maps)
rounded_detailed = SAT.Report.ISR.round_withholdings_detailed(withholdings)
```

## Complete Example

```elixir
# Process all XML and ZIP files in a directory and its subdirectories
withholdings = SAT.Report.ISR.withholdings("/Volumes/data/defdo_projects/defdo_my_mvno/priv/sat/xml")

# Get a detailed summary with SAT rounding applied
result = withholdings
  |> SAT.Report.ISR.withholdings_summarize_detailed()
  |> SAT.Report.ISR.round_withholdings_detailed()

# Print the results
Enum.each(result, fn %{tax_id: tax_id, incoming: incoming, withheld: withheld} ->
  IO.puts("Tax ID: #{tax_id}, Total: #{incoming}, Withheld: #{withheld}")
end)
```

or if you don't want detailed summary:

```elixir
withholdings = SAT.Report.ISR.withholdings("/path/to/your/invoices" )

result = 
    withholdings
    |> SAT.Report.ISR.withholdings() 
    |> SAT.Report.ISR.withholdings_summarize()
    |> SAT.Report.ISR.round_withholdings() 

Enum.each(result, fn {tax_id, incoming, withheld} -> 
    IO.puts("#{tax_id}|#{incoming}|#{withheld}")
end)
```

## Advanced Features

### Custom Rounding

The module uses a special rounding rule for SAT:

- If fractional part ≥ 0.60, round up
- If fractional part < 0.60, round down
You can use this rounding function directly:

```elixir
# Round a decimal value according to SAT rules
rounded = SAT.Report.ISR.custom_round(Decimal.new("123.59"))  # Returns 123
rounded = SAT.Report.ISR.custom_round(Decimal.new("123.61"))  # Returns 124
```

### File Support

The module supports:

- Individual XML files
- ZIP files containing XML files
- Nested directory structures
When processing ZIP files, the module:

1. Extracts the ZIP files to a temporary directory
2. Processes all XML files found inside
3. Automatically cleans up the temporary files

## Notes

- The module specifically looks for ISR tax withholdings (tax ID "001")
- Make sure your XML files are valid CFDI documents
- For large datasets, consider the memory implications of processing many files at once
This tutorial should help you remember how to use the `SAT.Report.ISR` module for generating ISR reports from your SAT XML invoices.
