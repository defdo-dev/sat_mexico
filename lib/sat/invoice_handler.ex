defmodule SAT.InvoiceHandler do
  @moduledoc false
  @behaviour Saxy.Handler

  def handle_event(:start_document, prolog, _initial_state) do
    {:ok, Map.new(prolog)}
  end

  def handle_event(:end_document, _data, state) do
    {:ok, state}
  end

  def handle_event(:start_element, {"cfdi:Comprobante", attributes}, state) do
    attrs = Map.new(attributes)

    params = %{
      version: attrs["Version"],
      created_at: attrs["Fecha"],
      stamp: attrs["Sello"],
      payment_way_id: attrs["FormaPago"],
      certificate_number: attrs["NoCertificado"],
      certificate: attrs["Certificado"],
      sub_total: attrs["SubTotal"],
      currency: attrs["Moneda"],
      total: attrs["Total"],
      voucher_type_id: attrs["TipoDeComprobante"],
      export_id: attrs["Exportacion"],
      payment_method_id: attrs["MetodoPago"],
      expedition_residence: attrs["LugarExpedicion"],
      metadata: %{
        schema_location: attrs["xsi:schemaLocation"],
        cfdi: attrs["xmlns:cfdi"],
        xsi: attrs["xmlns:xsi"]
      }
    }

    {:ok, Map.merge(state, params)}
  end

  def handle_event(:start_element, {"cfdi:Emisor", attributes}, state) do
    attrs = Map.new(attributes)

    params =
      %{
        issuer: %{
          name: attrs["Nombre"],
          tax_regime_id: attrs["RegimenFiscal"],
          tax_id: attrs["Rfc"]
        }
      }

    {:ok, Map.merge(state, params)}
  end

  def handle_event(:start_element, {"cfdi:Receptor", attributes}, state) do
    attrs = Map.new(attributes)

    params = %{
      recipient: %{
        name: attrs["Nombre"],
        tax_id: attrs["Rfc"],
        tax_residence: attrs["DomicilioFiscalReceptor"],
        tax_regime_id: attrs["RegimenFiscalReceptor"],
        cfdi_usage_id: attrs["UsoCFDI"]
      }
    }

    {:ok, Map.merge(state, params)}
  end

  def handle_event(:start_element, {"cfdi:Concepto", attributes}, state) do
    attrs = Map.new(attributes)
    path = [:concepts]

    concept = %{
      tax_reference: attrs["Importe"],
      product_service_id: attrs["ClaveProdServ"],
      quantity: attrs["Cantidad"],
      unity_id: attrs["ClaveUnidad"],
      unity: attrs["Unidad"],
      unity_amount: attrs["ValorUnitario"],
      amount: attrs["Importe"],
      tax_object_id: attrs["ObjetoImp"],
      description: attrs["Descripcion"]
    }

    state =
      if current = get_in(state, path) do
        put_in(state, path, [concept | current])
      else
        put_in(state, path, [concept])
      end

    {:ok, state}
  end

  def handle_event(:start_element, {"cfdi:Impuestos", []}, state) do
    concepts = Enum.map(state.concepts, &Map.merge(&1, %{taxes: []}))
    state = put_in(state, [:concepts], concepts)
    {:ok, state}
  end

  def handle_event(:start_element, {"cfdi:Traslado", attributes}, state)
      when is_map_key(state, :taxes) do
    attrs = Map.new(attributes)
    concept_path = [:taxes, :transferred]

    params = %{
      base: attrs["Base"],
      tax_id: attrs["Impuesto"],
      factor_type: attrs["TipoFactor"],
      rate_quota: attrs["TasaOCuota"],
      amount: attrs["Importe"]
    }

    state =
      if current = get_in(state, concept_path) do
        put_in(state, concept_path, [params | current])
      else
        put_in(state, concept_path, [params])
      end

    {:ok, state}
  end

  def handle_event(:start_element, {"cfdi:Traslado", attributes}, state) do
    attrs = Map.new(attributes)
    concept_path = [:taxes, :transferred]

    params = %{
      base: attrs["Base"],
      tax_id: attrs["Impuesto"],
      factor_type: attrs["TipoFactor"],
      rate_quota: attrs["TasaOCuota"],
      amount: attrs["Importe"]
    }

    concepts =
      Enum.map(state.concepts, fn concept ->
        if concept.tax_reference == params.base do
          if current = get_in(concept, concept_path) do
            put_in(concept, concept_path, [params | current])
          else
            put_in(concept, concept_path, [params])
          end
        else
          concept
        end
      end)

    state = put_in(state, [:concepts], concepts)

    {:ok, state}
  end

  def handle_event(:start_element, {"cfdi:Impuestos", attributes}, state) do
    attrs = Map.new(attributes)
    total_taxes_transferred = attrs["TotalImpuestosTrasladados"]
    total_taxes_withheld = attrs["TotalImpuestosRetenidos"]

    params = %{
      taxes: %{
        total_taxes_transferred: total_taxes_transferred,
        total_taxes_withheld: total_taxes_withheld
      }
    }

    {:ok, Map.merge(state, params)}
  end

  def handle_event(:start_element, {"cfdi:Retencion", attributes}, state)
      when is_map_key(state, :taxes) do
    attrs = Map.new(attributes)
    path = [:taxes, :withheld]

    params = %{
      tax_id: attrs["Impuesto"],
      amount: attrs["Importe"]
    }

    state =
      if current = get_in(state, path) do
        put_in(state, path, [params | current])
      else
        put_in(state, path, [params])
      end

    {:ok, state}
  end

  def handle_event(:start_element, {"cfdi:Retencion", attributes}, state) do
    attrs = Map.new(attributes)
    concept_path = [:taxes, :withheld]

    params = %{
      base: attrs["Base"],
      tax_id: attrs["Impuesto"],
      factor_type: attrs["TipoFactor"],
      rate_quota: attrs["TasaOCuota"],
      amount: attrs["Importe"]
    }

    concepts =
      Enum.map(state.concepts, fn concept ->
        if concept.tax_reference == params.base do
          if current = get_in(concept, concept_path) do
            put_in(concept, concept_path, [params | current])
          else
            put_in(concept, concept_path, [params])
          end
        else
          concept
        end
      end)

    state = put_in(state, [:concepts], concepts)

    {:ok, state}
  end

  def handle_event(:start_element, {"tfd:TimbreFiscalDigital", attributes}, state) do
    attrs = Map.new(attributes)

    locations =
      if schema_locations = attrs["xsi:schemaLocation"] do
        String.split(schema_locations, " ")
      else
        []
      end

    params = %{
      version: attrs["Version"],
      uuid: attrs["UUID"],
      stamp_date: attrs["FechaTimbrado"],
      provider_tax_id: attrs["RfcProvCertif"],
      cfd_stamp: attrs["SelloCFD"],
      sat_certificate_number: attrs["NoCertificadoSAT"],
      sat_stamp: attrs["SelloSAT"],
      metadata: %{
        tfd: attrs["xmlns:tfd"],
        schema_locations: locations
      }
    }

    {:ok, Map.put(state, :complement, params)}
  end

  def handle_event(:start_element, _, state), do: {:ok, state}
  def handle_event(:end_element, _, state), do: {:ok, state}
  def handle_event(:characters, _, state), do: {:ok, state}
end
