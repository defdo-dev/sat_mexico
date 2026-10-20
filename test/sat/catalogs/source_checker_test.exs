defmodule SAT.Catalogs.SourceCheckerTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Sat.Catalogs.Check
  alias SAT.Catalogs.SourceChecker

  @base_source %{
    "id" => "cfdi_40_catalogs",
    "url" => "https://sat.example/catalogs.xls",
    "discovery_url" => "https://sat.example/anexo-20.html",
    "discovery_match" => "^catalogs.*\\.xls$",
    "expected_sheet_name" => "Catalog",
    "header_row" => 1,
    "version" => "CFDI 4.0",
    "last_modified" => "Tue, 01 Jan 2024 00:00:00 GMT",
    "etag" => "\"old-etag\"",
    "sha256" => :crypto.hash(:sha256, "original") |> Base.encode16(case: :lower)
  }

  test "unchanged metadata skips download" do
    request = fn
      :head, "https://sat.example/catalogs.xls" ->
        {:ok, response(200, @base_source, "")}

      :get, "https://sat.example/anexo-20.html" ->
        {:ok, response(200, %{}, ~s(<a href="/catalogs.xls">Catalogs</a>))}

      method, url ->
        flunk("unexpected #{method} request to #{url}")
    end

    assert [%{status: :unchanged, source: @base_source}] =
             SourceChecker.check([@base_source], request)
  end

  test "changed ETag downloads the file and detects new content" do
    changed_headers = Map.put(@base_source, "etag", "\"new-etag\"")
    request = source_request(changed_headers, "updated")

    assert [%{status: :changed, source: updated}] = SourceChecker.check([@base_source], request)
    assert updated["etag"] == "\"new-etag\""
    assert updated["sha256"] == sha256("updated")
  end

  test "changed content is detected with the same ETag and a new Last-Modified" do
    changed_headers = Map.put(@base_source, "last_modified", "Wed, 02 Jan 2024 00:00:00 GMT")
    request = source_request(changed_headers, "silently changed")

    assert [%{status: :changed, source: updated}] = SourceChecker.check([@base_source], request)
    assert updated["etag"] == @base_source["etag"]
    assert updated["sha256"] == sha256("silently changed")
  end

  test "a renamed file is located even if the old URL remains reachable" do
    renamed_url = "https://sat.example/catalogs-2026.xls"

    request = fn
      :head, "https://sat.example/catalogs.xls" ->
        {:ok, response(200, @base_source, "")}

      :get, "https://sat.example/anexo-20.html" ->
        {:ok, response(200, %{}, ~s(<a href="/catalogs-2026.xls">Catalogs</a>))}

      :head, ^renamed_url ->
        {:ok, response(200, @base_source, "")}

      :get, ^renamed_url ->
        {:ok, response(200, %{}, "renamed contents")}

      method, url ->
        flunk("unexpected #{method} request to #{url}")
    end

    assert [%{status: :changed, source: updated}] = SourceChecker.check([@base_source], request)
    assert updated["url"] == renamed_url
    assert updated["sha256"] == sha256("renamed contents")
  end

  test "an HTTPS discovery link upgrades an existing HTTP URL" do
    source = Map.put(@base_source, "url", "http://sat.example/catalogs.xls")

    request = fn
      :head, "http://sat.example/catalogs.xls" ->
        {:error, :econnrefused}

      :get, "https://sat.example/anexo-20.html" ->
        {:ok, response(200, %{}, ~s(<a href="https://sat.example/catalogs.xls">Catalogs</a>))}

      :head, "https://sat.example/catalogs.xls" ->
        {:ok, response(200, @base_source, "")}

      :get, "https://sat.example/catalogs.xls" ->
        {:ok, response(200, %{}, "secure contents")}

      method, url ->
        flunk("unexpected #{method} request to #{url}")
    end

    assert [%{status: :changed, source: updated}] = SourceChecker.check([source], request)
    assert updated["url"] == "https://sat.example/catalogs.xls"
    assert updated["sha256"] == sha256("secure contents")
  end

  test "unreachable sources are reported" do
    request = fn
      :head, "https://sat.example/catalogs.xls" -> {:error, :timeout}
      :get, "https://sat.example/anexo-20.html" -> {:error, :timeout}
      method, url -> flunk("unexpected #{method} request to #{url}")
    end

    assert [%{status: :unreachable}] = SourceChecker.check([@base_source], request)
  end

  test "--update writes changed values to the manifest" do
    with_manifest(fn path ->
      changed_headers = Map.put(@base_source, "etag", "\"new-etag\"")

      Application.put_env(
        :sat_mexico,
        :catalogs_http_request,
        source_request(changed_headers, "updated")
      )

      Mix.Task.reenable("sat.catalogs.check")

      File.cd!(Path.dirname(Path.dirname(Path.dirname(path))), fn ->
        Check.run(["--update", "--sources", path])
      end)

      [updated] = path |> File.read!() |> Jason.decode!()
      assert updated["etag"] == "\"new-etag\""
      assert updated["sha256"] == sha256("updated")
    end)
  end

  test "a default run never writes the manifest" do
    with_manifest(fn path ->
      original = File.read!(path)
      changed_headers = Map.put(@base_source, "etag", "\"new-etag\"")

      Application.put_env(
        :sat_mexico,
        :catalogs_http_request,
        source_request(changed_headers, "updated")
      )

      Mix.Task.reenable("sat.catalogs.check")

      assert_raise Mix.Error, fn ->
        File.cd!(Path.dirname(Path.dirname(Path.dirname(path))), fn ->
          Check.run(["--sources", path])
        end)
      end

      assert File.read!(path) == original
    end)
  end

  defp source_request(headers, body) do
    fn
      :head, "https://sat.example/catalogs.xls" ->
        {:ok, response(200, headers, "")}

      :get, "https://sat.example/anexo-20.html" ->
        {:ok, response(200, %{}, ~s(<a href="/catalogs.xls">Catalogs</a>))}

      :get, "https://sat.example/catalogs.xls" ->
        {:ok, response(200, %{}, body)}

      method, url ->
        flunk("unexpected #{method} request to #{url}")
    end
  end

  defp response(status, source, body) do
    headers = %{
      "last-modified" => source["last_modified"],
      "etag" => source["etag"]
    }

    %{
      status: status,
      headers: headers |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> Map.new(),
      body: body
    }
  end

  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

  defp with_manifest(fun) do
    root = Path.join(System.tmp_dir!(), "sat-catalog-check-#{System.unique_integer([:positive])}")
    priv = Path.join(root, "priv")
    File.mkdir_p!(priv)
    path = Path.join(priv, "sources.json")
    File.write!(path, Jason.encode!([@base_source], pretty: true))
    previous_http_request = Application.fetch_env(:sat_mexico, :catalogs_http_request)

    on_exit(fn ->
      case previous_http_request do
        {:ok, request} -> Application.put_env(:sat_mexico, :catalogs_http_request, request)
        :error -> Application.delete_env(:sat_mexico, :catalogs_http_request)
      end

      File.rm_rf!(root)
    end)

    fun.(path)
  end
end
