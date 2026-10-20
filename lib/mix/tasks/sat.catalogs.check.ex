defmodule Mix.Tasks.Sat.Catalogs.Check do
  @moduledoc """
  Checks the SAT catalog sources recorded in `priv/sources.json`.

  Pass `--update` to write new URLs, modification metadata, and checksums to the manifest.
  """
  use Mix.Task

  alias SAT.Catalogs.SourceChecker

  @shortdoc "Checks official SAT catalog source files"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest} = OptionParser.parse!(args, strict: [update: :boolean, sources: :string])

    if rest != [] do
      Mix.raise("unexpected arguments: #{Enum.join(rest, " ")}")
    end

    path = Keyword.get(opts, :sources, default_sources_path())
    sources = path |> File.read!() |> Jason.decode!()

    request_fun =
      Application.get_env(:sat_mexico, :catalogs_http_request, &SourceChecker.request/2)

    results = SourceChecker.check(sources, request_fun)

    Enum.each(results, fn %{source: source, status: status} ->
      Mix.shell().info("#{status} #{source["id"]}")
    end)

    if opts[:update] do
      write_manifest(path, Enum.map(results, & &1.source))
    end

    failed? = Enum.any?(results, fn %{status: status} -> status != :unchanged end)

    if failed? and not Keyword.get(opts, :update, false) do
      Mix.raise(
        "SAT catalog sources changed or are unreachable; review the output and rerun with --update to accept changes"
      )
    end

    if Keyword.get(opts, :update, false) and Enum.any?(results, &(&1.status == :unreachable)) do
      Mix.raise(
        "one or more SAT catalog sources are unreachable; the manifest was not updated for those sources"
      )
    end
  end

  defp write_manifest(path, sources) do
    updated = Jason.encode!(sources, pretty: true) <> "\n"
    temporary_path = path <> ".tmp"

    File.write!(temporary_path, updated)
    File.rename!(temporary_path, path)
  end

  defp default_sources_path do
    if Mix.Project.config()[:app] == :sat_mexico do
      Path.join(File.cwd!(), "priv/sources.json")
    else
      case :code.priv_dir(:sat_mexico) do
        {:error, reason} ->
          Mix.raise("could not locate sat_mexico priv directory: #{inspect(reason)}")

        directory ->
          Path.join(directory, "sources.json")
      end
    end
  end
end
