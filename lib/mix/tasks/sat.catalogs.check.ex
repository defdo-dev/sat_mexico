defmodule Mix.Tasks.Sat.Catalogs.Check do
  use Mix.Task

  @shortdoc "Check the official SAT source files against priv/sources.json"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest} = OptionParser.parse!(args, strict: [update: :boolean])

    if rest != [] do
      Mix.raise("unexpected arguments: #{Enum.join(rest, " ")}")
    end

    case SAT.Catalogs.Check.check("priv/sources.json", update: Keyword.get(opts, :update, false)) do
      {:ok, results} ->
        Enum.each(results, fn %{id: id, status: status} ->
          Mix.shell().info("#{id} #{status}")
        end)

        if Enum.any?(results, &(&1.status != :unchanged)) do
          Mix.raise("SAT source files changed or are unreachable")
        end

      {:error, reason} ->
        Mix.raise("could not check SAT sources: #{inspect(reason)}")
    end
  end
end
