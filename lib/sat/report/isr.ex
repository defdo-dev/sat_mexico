defmodule SAT.Report.ISR do
  @moduledoc """
  Get a `summarized` report for withholdings ISR taxes.
  """
  alias SAT.FileManager
  alias SAT.InvoiceHandler

  @isr_id "001"

  @doc """
  Expects a directory with the `XML` invoices to build the a grouped list.
  """
  @spec withholdings(path_dir :: String.t()) :: map() | {:error, message :: String.t()}
  def withholdings(path_dir) do
    if File.dir?(path_dir) do
      paths =
        Path.join(path_dir, "*.xml")
        |> Path.wildcard()

      Enum.map(paths, fn path ->
        document = FileManager.read(path)
        {:ok, invoice} = Saxy.parse_string(document, InvoiceHandler, [])

        if is_map_key(invoice.taxes, :withheld) do
          {_, amount_withheld} =
            invoice.taxes.withheld
            |> Enum.filter(&(&1.tax_id == @isr_id))
            |> Enum.map_reduce(Decimal.new(0), fn tax, acc ->
              value = Decimal.new(tax.amount)
              {tax, Decimal.add(acc, value)}
            end)

          amount_incoming = Decimal.new(invoice.total)

          %{
            retainer_tax_id: invoice.recipient.tax_id,
            amount_incoming: amount_incoming,
            amount_withheld: amount_withheld
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.group_by(& &1.retainer_tax_id)
    else
      {:error, "Ensure you give a directory where SAT xml files exists."}
    end
  end

  @doc """
  Expects the output obtained via `withholdings/1` to return the summarized result.

  This helps to get the right values to do the details for withheld tax by a moral person.
  """
  @spec withholdings_summarize(data :: map()) :: []
  def withholdings_summarize(data) do
    Enum.map(data, fn {retainer_tax_id, record} ->
      amount_incoming = Enum.reduce(record, Decimal.new(0), &Decimal.add(&1.amount_incoming, &2))
      amount_withheld = Enum.reduce(record, Decimal.new(0), &Decimal.add(&1.amount_withheld, &2))
      {retainer_tax_id, amount_incoming, amount_withheld}
    end)
  end
end
