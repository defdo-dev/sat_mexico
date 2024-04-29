defmodule SAT.MixProject do
  @moduledoc false
  use Mix.Project

  @version File.read!("VERSION")
  @source_url "https://github.com/defdo-dev/sat_mexico"

  def project do
    [
      app: :sat_mexico,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      preferred_cli_env: [
        "test.watch": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SAT.Application, []}
    ]
  end

  defp package do
    [
      files: ~w(lib CHANGELOG.md LICENSE.md mix.exs README.md VERSION .formatter.exs),
      description:
        "An approach to interacting with invoices for SAT Mexico.",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 2.1"},
      {:saxy, "~> 1.5"},
      {:ex_doc, ">= 0.0.0", only: [:dev, :docs]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

   defp docs do
    [
      main: "SAT",
      logo: "logo.png",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "CHANGELOG.md"
      ]
    ]
   end
end
