defmodule SAT.Report.ISR do
  @moduledoc """
  Get a `summarized` report for withholdings ISR taxes.
  """
  alias SAT.FileManager
  alias SAT.InvoiceHandler

  @isr_id "001"

  @doc """
  Expects a directory with the `XML` invoices to build the a grouped list.
  Supports both individual XML files and ZIP files containing XML files.
  """
  @spec withholdings(path_dir :: String.t(), nested_lookup :: boolean()) ::
          withholdings :: map() | {:error, message :: String.t()}
  def withholdings(path_dir, nested_lookup \\ true) do
    if File.dir?(path_dir) do
      # Get all XML files directly in the directory
      xml_wildcard = if nested_lookup, do: "**/*.xml", else: "*.xml"
      zip_wildcard = if nested_lookup, do: "**/*.zip", else: "*.zip"

      xml_paths =
        Path.join(path_dir, xml_wildcard)
        |> Path.wildcard()

      # Get all ZIP files in the directory
      zip_paths =
        Path.join(path_dir, zip_wildcard)
        |> Path.wildcard()

      # Process ZIP files and extract XML files
      extracted_xml_paths =
        zip_paths
        |> Enum.flat_map(fn zip_path ->
          temp_dir = Path.join(System.tmp_dir!(), "sat_xml_#{:rand.uniform(1_000_000)}")
          File.mkdir_p!(temp_dir)

          try do
            {:ok, _} =
              :zip.extract(String.to_charlist(zip_path), [{:cwd, String.to_charlist(temp_dir)}])

            # Find all XML files in the extracted directory
            Path.join(temp_dir, "**/*.xml")
            |> Path.wildcard()
          rescue
            _ -> []
          end
        end)

      # Combine direct XML files and extracted XML files
      all_xml_paths = xml_paths ++ extracted_xml_paths

      # Process all XML files
      result =
        Enum.map(all_xml_paths, fn path ->
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

      # Clean up temporary directories
      extracted_xml_paths
      |> Enum.map(&Path.dirname/1)
      |> Enum.uniq()
      |> Enum.each(fn dir ->
        if String.starts_with?(dir, System.tmp_dir!()) && String.contains?(dir, "sat_xml_") do
          File.rm_rf!(dir)
        end
      end)

      result
    else
      {:error, "Ensure you give a directory where SAT xml files exists."}
    end
  end

  @doc """
  Expects the output obtained via `withholdings/1` to return the summarized result.

  This helps to get the right values to do the details for withheld tax by a moral person.
  """
  @spec withholdings_summarize(data :: map()) :: withholdings :: []
  def withholdings_summarize(data) do
    Enum.map(data, fn {retainer_tax_id, record} ->
      amount_incoming = Enum.reduce(record, Decimal.new(0), &Decimal.add(&1.amount_incoming, &2))
      amount_withheld = Enum.reduce(record, Decimal.new(0), &Decimal.add(&1.amount_withheld, &2))
      {retainer_tax_id, amount_incoming, amount_withheld}
    end)
  end

  @doc """
  Expects the output obtained via `withholdings/1` to return the summarized result.
  This helps to get the right values to do the details for withheld tax by a moral person.

  The output is a list of maps with the following keys:
  - `tax_id`: The tax ID of the person who is withholding the tax.
  - `incoming`: The total amount of the invoice.
  - `withheld`: The total amount of the tax withheld.
  """
  @spec withholdings_summarize_detailed(withholdings :: map() | list()) :: []
  def withholdings_summarize_detailed(withholdings) do
    Enum.map(withholdings_summarize(withholdings), fn {retainer_tax_id, amount_incoming,
                                                       amount_withheld} ->
      %{tax_id: retainer_tax_id, incoming: amount_incoming, withheld: amount_withheld}
    end)
  end

  @doc """
  Apply SAT rounding to each {tax_id, gross_amount, tax_withheld} tuple,
  returning {tax_id, rounded_gross, rounded_withheld} with integer values.
  """
  def round_withholdings(withholdings) do
    Enum.map(withholdings, fn
      {tax_id, gross, withheld} ->
        rounded_gross = custom_round(gross) |> Decimal.to_integer()
        rounded_withheld = custom_round(withheld) |> Decimal.to_integer()
        {tax_id, rounded_gross, rounded_withheld}

      %{tax_id: tax_id, incoming: gross, withheld: withheld} ->
        rounded_gross = custom_round(gross) |> Decimal.to_integer()
        rounded_withheld = custom_round(withheld) |> Decimal.to_integer()
        {tax_id, rounded_gross, rounded_withheld}
    end)
  end

  @doc """
  Apply SAT rounding to each {tax_id, gross_amount, tax_withheld} tuple,
  returning {tax_id, rounded_gross, rounded_withheld} with integer values.
  The output is a list of maps with the following keys:
  - `tax_id`: The tax ID of the person who is withholding the tax.
  - `incoming`: The total amount of the invoice.
  - `withheld`: The total amount of the tax withheld.
  """
  @spec round_withholdings_detailed(withholdings :: map()) :: []
  def round_withholdings_detailed(withholdings) do
    Enum.map(round_withholdings(withholdings), fn {retainer_tax_id, amount_incoming,
                                                   amount_withheld} ->
      %{tax_id: retainer_tax_id, incoming: amount_incoming, withheld: amount_withheld}
    end)
  end

  @doc """
  Round according to SAT: fractional part > 0.50 → up; else (≤ 0.50) → down.
  """
  def custom_round(decimal) do
    # 1) get integer part by truncating (round down)
    integer_part = Decimal.round(decimal, 0, :down)

    # 2) compute fractional part
    fraction = Decimal.sub(decimal, integer_part)

    # 3) if fraction ≥ 0.60 → up, else → down
    if Decimal.gte?(fraction, Decimal.new("0.60")) do
      Decimal.add(integer_part, Decimal.new("1"))
    else
      integer_part
    end
  end
end
