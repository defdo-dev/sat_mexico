defmodule Mix.Tasks.Sat.Catalogs.Check do
  use Mix.Task

  @shortdoc "Checks official SAT catalog sources against priv/sources.json"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    {opts, rest} = OptionParser.parse!(args, strict: [update: :boolean])

    if rest != [] do
      Mix.raise("unexpected arguments: #{Enum.join(rest, " ")}")
    end

    output = fn line -> Mix.shell().info(line) end

    case SAT.Catalogs.Check.run(update: opts[:update] || false, output: output) do
      {:ok, _results} ->
        :ok

      {:error, results} ->
        failures =
          Enum.filter(results, &(&1.status != :unchanged))
          |> Enum.map_join(", ", &"#{&1.id}=#{&1.status}")

        Mix.raise("SAT catalog source check failed: #{failures}")
    end
  end
end
