defmodule Support.InvoiceFixtures do
  @moduledoc false
  def expected_invoice do
    %{
      total: "2944.00",
      version: "4.0",
      encoding: "utf-8",
      metadata: %{
        cfdi: "http://www.sat.gob.mx/cfd/4",
        schema_location:
          "http://www.sat.gob.mx/cfd/4 http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd",
        xsi: "http://www.w3.org/2001/XMLSchema-instance"
      },
      currency: "MXN",
      certificate:
        "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",
      taxes: %{
        total_taxes_transferred: "452.56",
        total_taxes_withheld: "337.07",
        transferred: [
          %{
            base: "2828.51",
            amount: "452.56",
            factor_type: "Tasa",
            rate_quota: "0.160000",
            tax_id: "002"
          }
        ],
        withheld: [%{amount: "35.36", tax_id: "001"}, %{amount: "301.71", tax_id: "002"}]
      },
      concepts: [
        %{
          description: "Plan mixto",
          taxes: [
            withheld: [
              %{
                base: "2828.51",
                amount: "35.36",
                factor_type: "Tasa",
                rate_quota: "0.012500",
                tax_id: "001"
              },
              %{
                base: "2828.51",
                amount: "301.71",
                factor_type: "Tasa",
                rate_quota: "0.106667",
                tax_id: "002"
              }
            ],
            transferred: [
              %{
                base: "2828.51",
                amount: "452.56",
                factor_type: "Tasa",
                rate_quota: "0.160000",
                tax_id: "002"
              }
            ]
          ],
          amount: "2828.51",
          product_service_id: "81161700",
          quantity: "1.00",
          tax_object_id: "02",
          tax_reference: "2828.51",
          unity: "Unidad de servicio",
          unity_amount: "2828.51",
          unity_id: "E48"
        }
      ],
      complement: %{
        version: "1.1",
        metadata: %{
          schema_locations: [
            "http://www.sat.gob.mx/TimbreFiscalDigital",
            "http://www.sat.gob.mx/sitio_internet/cfd/TimbreFiscalDigital/TimbreFiscalDigitalv11.xsd"
          ],
          tfd: "http://www.sat.gob.mx/TimbreFiscalDigital"
        },
        uuid: "0C872345-422C-4C53-97A1-A144E8727B59",
        cfd_stamp:
          "BrxP52OFMkWUd8TXBHcuAVlg2K7L9UltfRHXZIJiG7GOCyOv/dYGSkLgyqWMQ9RLgwfqj9HdcK4JQnU0IdqV4p4rkT/whi+4UQKlpBw0TiQygwd2bcB/fC8urWjGeaFqPC2U4NYJBabeCdGwbZByxjV1/94dukAVc+Nw4Y9VeHDPk7qt+W+zBpKKiA559IiDQg5GRv2pbeYOIu9LQImX4c9J4VwFyy0UnoA6gMXnS6TnuPggmmjBsDJreF7IQAOI3arf5n9NuSzm0i+lmYgYmzniqn7y3Q5ne1My75nxnRUHo6zEfESxgM7mPHvMchrjiGv5s5ren3K7sVArfzm5lw==",
        provider_tax_id: "SAT970701NN3",
        sat_certificate_number: "00000000000504965321",
        sat_stamp:
          "kBlbP5ehu/kZnpvrCbahTEpWOLLqVEIEOEcf8SqrBhbKBD4FxD8OGqXxgxrugf60bnom1bybqq3xKaY/ZqYh30b/CnOefP/xyVlwZFG0cMxRiT+h3hGRYdgfmjR2EK8vSE1AIR+rxlLIeNvs1VXB7zLKDVhWcDK1lw5M898AMBcP4PqfMxl6m0zjjZH7WTokXszoed+l5YYyV65gRJbdLCOmAzmlbapUkflvK7S5PP9k9MH1o6VnXQkWoq1y1F9uNwPO/9zAtHrVE6zpacNgi2V6+ZoXQtbrDYjXbHMBNE4tYDQAK+CmjhHvGj9BTnAs+s9RjEqX88OSh+W0gb4Njg==",
        stamp_date: "2023-10-25T17:30:53"
      },
      recipient: %{
        name: "DEFDO COMPANY",
        tax_id: "XEX150902KXA",
        cfdi_usage_id: "G03",
        tax_regime_id: "601",
        tax_residence: "06006"
      },
      issuer: %{name: "DOE JOE", tax_id: "XAXR890508X85", tax_regime_id: "626"},
      certificate_number: "00000000000908633832",
      created_at: "2023-10-25T17:30:31",
      expedition_residence: "01989",
      export_id: "01",
      payment_method_id: "PUE",
      payment_way_id: "03",
      stamp:
        "BrxR52OOMkPUd8TXFHcuAVlk2K7LlUktf9HXZIJiG7GOCyOv/dYGSkLgyqWMQ9RLgwfqj9HdcK4JQnU0IdqV4p4rkT/whi+4UQKlpBw0TiQygwd2bcB/fC8urWjGeaFqPC2U4NYJBabeCdGwbZByxjV1/94dukAVc+Nw4Y9VeHDPk7qt+W+zBpKKiA559IiDQg5GRv2pbeYOIu9LQImX4c9J4VwFyy0UnoA6gMXnS6TnuPggmmjBsDJreF7IQAOI3arf5n9NuSzm0i+lmYgYmzniqn7y3Q5ne1My75nxnRUHo6zEfESxgM7mPHvMchrjiGv5s5ren3K7sVArfzm5lw==",
      sub_total: "2828.51",
      voucher_type_id: "I"
    }
  end

  def invoice_fixture do
    ~S"""
    <?xml version="1.0" encoding="utf-8"?>
      <cfdi:Comprobante xsi:schemaLocation="http://www.sat.gob.mx/cfd/4 http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd" Version="4.0" Fecha="2023-10-25T17:30:31" Sello="BrxR52OOMkPUd8TXFHcuAVlk2K7LlUktf9HXZIJiG7GOCyOv/dYGSkLgyqWMQ9RLgwfqj9HdcK4JQnU0IdqV4p4rkT/whi+4UQKlpBw0TiQygwd2bcB/fC8urWjGeaFqPC2U4NYJBabeCdGwbZByxjV1/94dukAVc+Nw4Y9VeHDPk7qt+W+zBpKKiA559IiDQg5GRv2pbeYOIu9LQImX4c9J4VwFyy0UnoA6gMXnS6TnuPggmmjBsDJreF7IQAOI3arf5n9NuSzm0i+lmYgYmzniqn7y3Q5ne1My75nxnRUHo6zEfESxgM7mPHvMchrjiGv5s5ren3K7sVArfzm5lw==" FormaPago="03" NoCertificado="00000000000908633832" Certificado="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" SubTotal="2828.51" Moneda="MXN" Total="2944.00" TipoDeComprobante="I" Exportacion="01" MetodoPago="PUE" LugarExpedicion="01989" xmlns:cfdi="http://www.sat.gob.mx/cfd/4" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <cfdi:Emisor Rfc="XAXR890508X85" Nombre="DOE JOE" RegimenFiscal="626" />
      <cfdi:Receptor Rfc="XEX150902KXA" Nombre="DEFDO COMPANY" DomicilioFiscalReceptor="06006" RegimenFiscalReceptor="601" UsoCFDI="G03" />
      <cfdi:Conceptos>
        <cfdi:Concepto ClaveProdServ="81161700" Cantidad="1.00" ClaveUnidad="E48" Unidad="Unidad de servicio" Descripcion="Plan mixto" ValorUnitario="2828.51" Importe="2828.51" ObjetoImp="02">
          <cfdi:Impuestos>
            <cfdi:Traslados>
              <cfdi:Traslado Base="2828.51" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="452.56" />
            </cfdi:Traslados>
            <cfdi:Retenciones>
              <cfdi:Retencion Base="2828.51" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.106667" Importe="301.71" />
              <cfdi:Retencion Base="2828.51" Impuesto="001" TipoFactor="Tasa" TasaOCuota="0.012500" Importe="35.36" />
            </cfdi:Retenciones>
          </cfdi:Impuestos>
        </cfdi:Concepto>
      </cfdi:Conceptos>
      <cfdi:Impuestos TotalImpuestosTrasladados="452.56" TotalImpuestosRetenidos="337.07">
        <cfdi:Retenciones>
          <cfdi:Retencion Impuesto="002" Importe="301.71" />
          <cfdi:Retencion Impuesto="001" Importe="35.36" />
        </cfdi:Retenciones>
        <cfdi:Traslados>
          <cfdi:Traslado Base="2828.51" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="452.56" />
        </cfdi:Traslados>
      </cfdi:Impuestos>
      <cfdi:Complemento>
        <tfd:TimbreFiscalDigital xmlns:tfd="http://www.sat.gob.mx/TimbreFiscalDigital" xsi:schemaLocation="http://www.sat.gob.mx/TimbreFiscalDigital http://www.sat.gob.mx/sitio_internet/cfd/TimbreFiscalDigital/TimbreFiscalDigitalv11.xsd" Version="1.1" UUID="0C872345-422C-4C53-97A1-A144E8727B59" FechaTimbrado="2023-10-25T17:30:53" RfcProvCertif="SAT970701NN3" SelloCFD="BrxP52OFMkWUd8TXBHcuAVlg2K7L9UltfRHXZIJiG7GOCyOv/dYGSkLgyqWMQ9RLgwfqj9HdcK4JQnU0IdqV4p4rkT/whi+4UQKlpBw0TiQygwd2bcB/fC8urWjGeaFqPC2U4NYJBabeCdGwbZByxjV1/94dukAVc+Nw4Y9VeHDPk7qt+W+zBpKKiA559IiDQg5GRv2pbeYOIu9LQImX4c9J4VwFyy0UnoA6gMXnS6TnuPggmmjBsDJreF7IQAOI3arf5n9NuSzm0i+lmYgYmzniqn7y3Q5ne1My75nxnRUHo6zEfESxgM7mPHvMchrjiGv5s5ren3K7sVArfzm5lw==" NoCertificadoSAT="00000000000504965321" SelloSAT="kBlbP5ehu/kZnpvrCbahTEpWOLLqVEIEOEcf8SqrBhbKBD4FxD8OGqXxgxrugf60bnom1bybqq3xKaY/ZqYh30b/CnOefP/xyVlwZFG0cMxRiT+h3hGRYdgfmjR2EK8vSE1AIR+rxlLIeNvs1VXB7zLKDVhWcDK1lw5M898AMBcP4PqfMxl6m0zjjZH7WTokXszoed+l5YYyV65gRJbdLCOmAzmlbapUkflvK7S5PP9k9MH1o6VnXQkWoq1y1F9uNwPO/9zAtHrVE6zpacNgi2V6+ZoXQtbrDYjXbHMBNE4tYDQAK+CmjhHvGj9BTnAs+s9RjEqX88OSh+W0gb4Njg==" />
      </cfdi:Complemento>
    </cfdi:Comprobante>
    """
  end
end
