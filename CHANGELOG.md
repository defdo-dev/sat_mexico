# Changelog

## 0.2.0 (2025-04-27)

- Support for processing ZIP files containing XML invoices.
- Support for nested directory searching when processing invoice files.
- Detailed summarization of withholding data with `withholdings_summarize` and `withholdings_summarize_detailed`.
- SAT-compliant rounding functionality for tax calculations.
- Automatic cleanup of temporary files after processing.

## 0.1.0 (2024-04-29)

- CFDI invoice transformation from `XML` to `map` struct via `SAT.Handler`.
- CFDI report for withholdings ISR taxes.
