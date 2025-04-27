defmodule SATTest do
  use ExUnit.Case, async: true
  alias SAT.InvoiceHandler
  alias SAT.Report.ISR
  import Support.InvoiceFixtures

  describe "Invoice" do
    test "parse an invoice" do
      document = invoice_fixture()
      assert {:ok, expected_invoice()} == Saxy.parse_string(document, InvoiceHandler, [])
    end
  end

  describe "ISR Report" do
    test "extracts ISR withholdings from invoice" do
      document = invoice_fixture()
      {:ok, invoice} = Saxy.parse_string(document, InvoiceHandler, [])

      # Verify the invoice has ISR withholding tax (tax_id "001")
      assert Enum.any?(invoice.taxes.withheld, fn tax -> tax.tax_id == "001" end)

      # Get the ISR tax amount from the invoice
      isr_tax = Enum.find(invoice.taxes.withheld, fn tax -> tax.tax_id == "001" end)
      assert isr_tax.amount == "35.36"
    end

    test "summarizes withholdings correctly" do
      # Mock the result of withholdings/1 function
      withholdings = %{
        "XEX150902KXA" => [
          %{
            retainer_tax_id: "XEX150902KXA",
            amount_incoming: Decimal.new("2828.51"),
            amount_withheld: Decimal.new("35.36")
          }
        ]
      }

      # Test withholdings_summarize
      summarized = ISR.withholdings_summarize(withholdings)
      assert length(summarized) == 1
      {tax_id, incoming, withheld} = List.first(summarized)
      assert tax_id == "XEX150902KXA"
      assert Decimal.eq?(incoming, Decimal.new("2828.51"))
      assert Decimal.eq?(withheld, Decimal.new("35.36"))

      # Test withholdings_summarize_detailed
      detailed = ISR.withholdings_summarize_detailed(withholdings)
      assert length(detailed) == 1
      detail = List.first(detailed)
      assert detail.tax_id == "XEX150902KXA"
      assert Decimal.eq?(detail.incoming, Decimal.new("2828.51"))
      assert Decimal.eq?(detail.withheld, Decimal.new("35.36"))
    end

    test "rounds withholdings according to SAT rules" do
      # Test data
      withholdings = [
        {"XEX150902KXA", Decimal.new("2828.61"), Decimal.new("35.36")}
      ]

      # Test round_withholdings
      rounded = ISR.round_withholdings(withholdings)
      assert length(rounded) == 1
      {tax_id, rounded_incoming, rounded_withheld} = List.first(rounded)
      assert tax_id == "XEX150902KXA"
      assert rounded_incoming == 2829
      assert rounded_withheld == 35

      # Test round_withholdings_detailed
      detailed_withholdings = [
        %{tax_id: "XEX150902KXA", incoming: Decimal.new("2828.51"), withheld: Decimal.new("35.36")}
      ]

      rounded_detailed = ISR.round_withholdings_detailed(detailed_withholdings)
      assert length(rounded_detailed) == 1
      detail = List.first(rounded_detailed)
      assert detail.tax_id == "XEX150902KXA"
      assert detail.incoming == 2828
      assert detail.withheld == 35
    end
  end
end
