defmodule Mix.Tasks.Sat.Catalogs.Check do
  use Mix.Task

  @shortdoc "Check the official SAT source files against priv/sources.json"
  @moduledoc """
  Checks the current SAT catalog workbook and CFDI XSD against the packaged source manifest.

  Prints one line per source as `<id> unchanged|changed|unreachable`. Exits with
  status 0 only when every source is unchanged; changed, unreachable, or invalid
  manifest results exit non-zero. `--update` writes changed metadata and hashes
  to `priv/sources.json` in the current repository.
  """

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest} = OptionParser.parse!(args, strict: [update: :boolean])

    if rest != [] do
      Mix.raise("unexpected arguments: #{Enum.join(rest, " ")}")
    end

    update? = Keyword.get(opts, :update, false)
    check_opts = [update: update?]

    check_opts =
      if http = Application.get_env(:sat_mexico, :catalogs_check_http),
        do: Keyword.put(check_opts, :http, http),
        else: check_opts

    check_path =
      if update?,
        do: Application.get_env(:sat_mexico, :catalogs_check_manifest_path, "priv/sources.json"),
        else: nil

    result =
      case check_path do
        nil -> SAT.Catalogs.Check.check(check_opts)
        path -> SAT.Catalogs.Check.check(path, check_opts)
      end

    case result do
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
