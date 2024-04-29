defmodule SAT.TaxRegime do
  @moduledoc false

  @doc """
  Get a tax regime from regime id.
  """
  @spec get_tax_regime(integer()) :: map() | nil
  def get_tax_regime(regime_id) do
    tax_regimes()
    |> Enum.filter(&(&1.tax_id == regime_id))
    |> List.first()
  end

  @doc """
  Tax regimes for Mexico invoices

  Based on catalog 1.0 from CFDI V4.0 2024-04-26.
  """
  def tax_regimes do
    [
      %{
        tax_id: 601,
        description: "General de Ley Personas Morales",
        applies_physic: false,
        applies_moral: true,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 603,
        description: "Personas Morales con Fines no Lucrativos",
        applies_physic: false,
        applies_moral: true,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 605,
        description: "Sueldos y Salarios e Ingresos Asimilados a Salarios",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 606,
        description: "Arrendamiento",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 607,
        description: "Régimen de Enajenación o Adquisición de Bienes",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 608,
        description: "Demás ingresos",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 610,
        description: "Residentes en el Extranjero sin Establecimiento Permanente en México",
        applies_physic: true,
        applies_moral: true,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 611,
        description: "Ingresos por Dividendos (socios y accionistas)",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 612,
        description: "Personas Físicas con Actividades Empresariales y Profesionales",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 614,
        description: "Ingresos por intereses",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 615,
        description: "Régimen de los ingresos por obtención de premios",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 616,
        description: "Sin obligaciones fiscales",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 620,
        description: "Sociedades Cooperativas de Producción que optan por diferir sus ingresos",
        applies_physic: false,
        applies_moral: true,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 621,
        description: "Incorporación Fiscal",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 622,
        description: "Actividades Agrícolas, Ganaderas, Silvícolas y Pesqueras",
        applies_physic: false,
        applies_moral: true,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 623,
        description: "Opcional para Grupos de Sociedades",
        applies_physic: false,
        applies_moral: true,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 624,
        description: "Coordinados",
        applies_physic: false,
        applies_moral: true,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 625,
        description:
          "Régimen de las Actividades Empresariales con ingresos a través de Plataformas Tecnológicas",
        applies_physic: true,
        applies_moral: false,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      },
      %{
        tax_id: 626,
        description: "Régimen Simplificado de Confianza",
        applies_physic: true,
        applies_moral: true,
        validity_from: ~D[2022-01-01],
        validity_to: nil
      }
    ]
  end
end
