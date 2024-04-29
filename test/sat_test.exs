defmodule SATTest do
  use ExUnit.Case, async: true
  alias SAT.InvoiceHandler
  import Support.InvoiceFixtures

  describe "Invoice" do
    test "parse an invoice" do
      document = invoice_fixture()
      assert {:ok, expected_invoice()} == Saxy.parse_string(document, InvoiceHandler, [])
    end
  end
end
