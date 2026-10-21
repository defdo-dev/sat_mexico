defmodule Mix.Tasks.Sat.Catalogs.CheckTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @manifest_path "priv/sources.json"

  test "prints unchanged source lines and exits successfully" do
    with_task_config(fn _method, _url -> {:error, :unused} end, nil, fn ->
      http = task_http(:unchanged)
      Application.put_env(:sat_mexico, :catalogs_check_http, http)
      output = capture_io(fn -> Mix.Tasks.Sat.Catalogs.Check.run([]) end)
      assert output =~ "cfdi-4.0-catalogs unchanged"
      assert output =~ "cfdi-4.0-catcfdi-xsd unchanged"
    end)
  end

  test "changed source exits non-zero and --update writes the injected manifest" do
    temp_path =
      Path.join(System.tmp_dir!(), "sat-catalog-task-#{System.unique_integer([:positive])}.json")

    File.cp!(@manifest_path, temp_path)

    try do
      with_task_config(task_http(:changed), temp_path, fn ->
        output =
          capture_io(fn ->
            assert_raise Mix.Error, fn -> Mix.Tasks.Sat.Catalogs.Check.run(["--update"]) end
          end)

        assert output =~ "cfdi-4.0-catalogs changed"
        {:ok, updated} = temp_path |> File.read!() |> Jason.decode()
        assert [%{"etag" => "\"updated-etag\""} | _] = updated["sources"]
      end)
    after
      File.rm(temp_path)
    end
  end

  defp with_task_config(http, manifest_path, fun) do
    old_http = Application.get_env(:sat_mexico, :catalogs_check_http)
    old_path = Application.get_env(:sat_mexico, :catalogs_check_manifest_path)
    Application.put_env(:sat_mexico, :catalogs_check_http, http)

    if manifest_path,
      do: Application.put_env(:sat_mexico, :catalogs_check_manifest_path, manifest_path)

    Mix.Task.reenable("sat.catalogs.check")

    try do
      fun.()
    after
      restore_env(:catalogs_check_http, old_http)
      restore_env(:catalogs_check_manifest_path, old_path)
      Mix.Task.reenable("sat.catalogs.check")
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:sat_mexico, key)
  defp restore_env(key, value), do: Application.put_env(:sat_mexico, key, value)

  defp task_http(mode) do
    {:ok, manifest} = @manifest_path |> File.read!() |> Jason.decode()
    sources = manifest["sources"]

    fn method, url ->
      if method == :get and Enum.any?(sources, &(&1["discovery_page_url"] == url)) do
        links =
          sources
          |> Enum.filter(&(&1["discovery_page_url"] == url))
          |> Enum.map(fn source ->
            "<a href=\"#{source["url"]}\">#{source["discovery_link_text"]}</a>"
          end)
          |> Enum.join(" ")

        {:ok, %{status: 200, headers: %{}, body: links}}
      else
        case method do
          :head ->
            source = Enum.find(sources, &(&1["url"] == url))

            etag =
              if mode == :changed and source["id"] == "cfdi-4.0-catalogs",
                do: "\"updated-etag\"",
                else: source["etag"]

            headers = %{
              "etag" => [etag],
              "last-modified" => [source["last_modified"]],
              "content-length" => [to_string(source["content_length"])],
              "content-disposition" => ["attachment; filename=\"#{source["filename"]}\""]
            }

            {:ok, %{status: 200, headers: headers, body: nil}}

          :get ->
            source = Enum.find(sources, &(&1["url"] == url))
            {:ok, %{status: 200, headers: %{}, body: "synthetic update for #{source["id"]}"}}
        end
      end
    end
  end
end
