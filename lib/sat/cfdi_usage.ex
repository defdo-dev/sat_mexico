defmodule SAT.CFDIUsage do
  @moduledoc false

  @doc """
  Get a tax regime from regime id.
  """
  @spec get_cfdi_usage(String.t()) :: map() | nil
  def get_cfdi_usage(cfdi_usage_id) do
    cfdi_usages()
    |> Enum.filter(&(&1.usage_id == cfdi_usage_id))
    |> List.first()
  end

  @doc """
  CFDI usages for Mexico invoices

  Based on catalog 2.0 from CFDI V4.0 2024-04-26.
  """
  def cfdi_usages do
    [
      %{
        usage_id: "G01",
        description: "Adquisición de mercancías.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "G02",
        description: "Devoluciones, descuentos o bonificaciones.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 616, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "G03",
        description: "Gastos en general.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "I01",
        description: "Construcciones.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "I02",
        description: "Mobiliario y equipo de oficina por inversiones.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "I03",
        description: "Equipo de transporte.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "I04",
        description: "Equipo de computo y accesorios.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "I05",
        description: "Dados, troqueles, moldes, matrices y herramental.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "I06",
        description: "Comunicaciones telefónicas.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "I07",
        description: "Comunicaciones satelitales.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "I08",
        description: "Otra maquinaria y equipo.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [601, 603, 606, 612, 620, 621, 622, 623, 624, 625, 626]
      },
      %{
        usage_id: "D01",
        description: "Honorarios médicos, dentales y gastos hospitalarios.",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D02",
        description: "Gastos médicos por incapacidad o discapacidad.",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D03",
        description: "Gastos funerales.",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D04",
        description: "Donativos.",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D05",
        description:
          "Intereses reales efectivamente pagados por créditos hipotecarios (casa habitación).",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D06",
        description: "Aportaciones voluntarias al SAR.",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D07",
        description: "Primas por seguros de gastos médicos.",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D08",
        description: "Gastos de transportación escolar obligatoria.",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D09",
        description:
          "Depósitos en cuentas para el ahorro, primas que tengan como base planes de pensiones.",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "D10",
        description: "Pagos por servicios educativos (colegiaturas).",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605, 606, 608, 611, 612, 614, 607, 615, 625]
      },
      %{
        usage_id: "S01",
        description: "Sin efectos fiscales.",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [
          601,
          603,
          605,
          606,
          608,
          610,
          611,
          612,
          614,
          616,
          620,
          621,
          622,
          623,
          624,
          607,
          615,
          625,
          626
        ]
      },
      %{
        usage_id: "CP01",
        description: "Pagos",
        applies_physic: true,
        applies_moral: true,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [
          601,
          603,
          605,
          606,
          608,
          610,
          611,
          612,
          614,
          616,
          620,
          621,
          622,
          623,
          624,
          607,
          615,
          625,
          626
        ]
      },
      %{
        usage_id: "CN01",
        description: "Nómina",
        applies_physic: true,
        applies_moral: false,
        valid_from: ~D[2022-01-01],
        valid_to: nil,
        recipient_tax_regime_ids: [605]
      }
    ]
  end
end
