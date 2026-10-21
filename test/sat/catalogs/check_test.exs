defmodule SAT.Catalogs.CheckTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Sat.Catalogs.Check, as: CheckTask
  alias SAT.Catalogs.Check

  @body "safe synthetic SAT source bytes"
  @sha256 :crypto.hash(:sha256, @body) |> Base.encode16(case: :lower)

  test "source manifest tracks the Anexo 20 workbook and canonical XSD" do
    {:ok, %{"sources" => sources}} = "priv/sources.json" |> File.read!() |> Jason.decode()
    workbook = Enum.find(sources, &(&1["id"] == "cfdi-4.0-catalogs"))
    xsd = Enum.find(sources, &(&1["id"] == "cfdi-4.0-catcfdi-xsd"))

    assert workbook["discovery_page_url"] ==
             "http://omawww.sat.gob.mx/tramitesyservicios/Paginas/anexo_20.htm"

    assert workbook["discovery_link_text"] == "Catálogos CFDI Versión 4.0 (xls)"
    assert workbook["filename"] == "catCFDI_V_4_20261015.xls"

    assert workbook["url"] ==
             "http://omawww.sat.gob.mx/tramitesyservicios/Paginas/documentos/catCFDI_V_4_20261015.xls"

    assert workbook["content_length"] == 48_774_656
    assert workbook["last_modified"] == "Thu, 15 Oct 2026 15:08:36 GMT"
    assert workbook["last_modified_reliable"]
    assert workbook["etag"] == "\"{E7E51874-8C0A-4E8B-9EC3-4283E85BBBD3},1\""

    assert workbook["sha256"] ==
             "fde78b456d1e0d90366bfc68f8312f9edce5703ad5dc8ccebf09c462db13a079"

    assert Enum.map(workbook["expected_sheets"], &{&1["sheet_name"], &1["header_row"]}) == [
             {"c_RegimenFiscal", 6},
             {"c_UsoCFDI", 5},
             {"c_TipoDeComprobante", 5},
             {"c_FormaPago", 6},
             {"c_MetodoPago", 6},
             {"c_Impuesto", 5},
             {"c_TipoFactor", 5},
             {"c_ObjetoImp", 5},
             {"c_TipoRelacion", 5},
             {"c_Exportacion", 5},
             {"c_Moneda", 5},
             {"c_Periodicidad", 5},
             {"c_Meses", 5},
             {"c_TasaOCuota", 5}
           ]

    assert xsd["url"] == "http://www.sat.gob.mx/sitio_internet/cfd/catalogos/catCFDI.xsd"
    assert xsd["content_length"] == 5_984_046
    assert xsd["sha256"] == "6c58936cb77576f839a4d7915953ceaf252b9eb9319f9458fe5bb67ae2bb0bb1"
    assert xsd["etag"] == "\"e29ac5164fd253d5734a4d931127ecd2\""
    assert xsd["last_modified"] == "Fri, 13 Dec 2024 19:59:34 GMT"
    assert xsd["last_modified_reliable"]
    refute Map.has_key?(xsd, "archive_member")
  end

  test "unchanged source needs only HEAD metadata" do
    path = manifest_path(source())
    test_process = self()

    http = fn method, url ->
      send(test_process, {:request, method, url})
      {:ok, response(200, headers(), nil)}
    end

    assert {:ok, [%{id: "test-source", status: :unchanged}]} =
             Check.check(path, http: discovery_http(http))

    assert_received {:request, :get, "https://example.invalid/discovery"}
    assert_received {:request, :head, "https://example.invalid/source.xls"}
    refute_received {:request, :get, "https://example.invalid/source.xls"}
  end

  test "falls back to a one-byte range when HEAD is unsupported" do
    path =
      source()
      |> Map.put("content_length", 1)
      |> Map.put("last_modified_reliable", false)
      |> then(&manifest_path/1)

    updated_headers =
      headers("\"etag-1\"", "Tue, 20 Oct 2026 15:01:00 GMT")
      |> Map.put("content-range", ["bytes 0-0/1"])

    test_process = self()

    http = fn
      :head, url ->
        send(test_process, {:request, :head, url})
        {:ok, response(405, %{}, nil)}

      :get_range, url ->
        send(test_process, {:request, :get_range, url})
        {:ok, response(206, updated_headers, "x")}
    end

    assert {:ok, [%{status: :unchanged}]} = Check.check(path, http: discovery_http(http))
    assert_received {:request, :get, "https://example.invalid/discovery"}
    assert_received {:request, :head, "https://example.invalid/source.xls"}
    assert_received {:request, :get_range, "https://example.invalid/source.xls"}
    refute_received {:request, :get, _url}
  end

  test "hashes the body when SAT provides no stable validator" do
    path =
      source()
      |> Map.put("etag", nil)
      |> Map.put("content_length", 1)
      |> Map.put("last_modified_reliable", false)
      |> then(&manifest_path/1)

    updated_headers =
      headers()
      |> Map.delete("etag")
      |> Map.put("content-range", ["bytes 0-0/1"])

    test_process = self()

    http = fn
      :head, url ->
        send(test_process, {:request, :head, url})
        {:ok, response(405, %{}, nil)}

      :get_range, url ->
        send(test_process, {:request, :get_range, url})
        {:ok, response(206, updated_headers, "x")}

      :get, url ->
        send(test_process, {:request, :get, url})
        {:ok, response(200, updated_headers, "changed bytes")}
    end

    assert {:ok, [%{status: :changed}]} = Check.check(path, http: discovery_http(http))
    assert_received {:request, :get_range, "https://example.invalid/source.xls"}
    assert_received {:request, :get, "https://example.invalid/source.xls"}
  end

  test "changed ETag downloads the source and reports changed" do
    path = manifest_path(source())
    test_process = self()

    http = fn
      :head, url ->
        send(test_process, {:request, :head, url})
        {:ok, response(200, headers("\"etag-2\""), nil)}

      :get, url ->
        send(test_process, {:request, :get, url})
        {:ok, response(200, headers("\"etag-2\""), @body)}
    end

    assert {:ok, [%{status: :changed, source: %{"etag" => "\"etag-2\"", "sha256" => @sha256}}]} =
             Check.check(path, http: discovery_http(http))

    assert_received {:request, :head, "https://example.invalid/source.xls"}
    assert_received {:request, :get, "https://example.invalid/source.xls"}
  end

  test "changed SHA is detected when ETag stays the same" do
    path = manifest_path(source())
    updated_headers = headers("\"etag-1\"", "Tue, 20 Oct 2026 15:01:00 GMT")

    http = fn
      :head, _url -> {:ok, response(200, updated_headers, nil)}
      :get, _url -> {:ok, response(200, updated_headers, "different safe synthetic bytes")}
    end

    assert {:ok, [%{status: :changed, source: %{"etag" => "\"etag-1\"", "sha256" => sha256}}]} =
             Check.check(path, http: discovery_http(http))

    refute sha256 == @sha256
  end

  test "a renamed file is resolved from its discovery page" do
    path = manifest_path(source())
    new_url = "https://example.invalid/releases/current.xls"
    test_process = self()

    http = fn
      :head, "https://example.invalid/source.xls" ->
        send(test_process, {:request, :head, "https://example.invalid/source.xls"})
        {:ok, response(404, %{}, nil)}

      :get, "https://example.invalid/discovery" ->
        send(test_process, {:request, :get, "https://example.invalid/discovery"})
        body = ~s(<a href='/releases/current.xls'>Synthetic catalog</a>)
        {:ok, response(200, %{}, body)}

      :head, ^new_url ->
        send(test_process, {:request, :head, new_url})
        renamed_headers = headers("\"etag-2\"", "Tue, 20 Oct 2026 15:01:00 GMT", "current.xls")
        {:ok, response(200, renamed_headers, nil)}

      :get, ^new_url ->
        send(test_process, {:request, :get, new_url})

        {:ok,
         response(
           200,
           headers("\"etag-2\"", "Tue, 20 Oct 2026 15:01:00 GMT", "current.xls"),
           @body
         )}
    end

    assert {:ok, [%{status: :changed, source: %{"url" => ^new_url, "filename" => "current.xls"}}]} =
             Check.check(path, http: http)

    assert_received {:request, :get, "https://example.invalid/discovery"}
    assert_received {:request, :head, ^new_url}
  end

  test "unreachable HTTP sources report unreachable" do
    path = manifest_path(source())
    http = fn :head, _url -> {:ok, response(503, %{}, nil)} end

    assert {:ok, [%{status: :unreachable, reason: {:http_status, 503}}]} =
             Check.check(path, http: discovery_http(http))
  end

  test "update writes refreshed metadata and hash" do
    path = manifest_path(source())
    updated_headers = headers("\"etag-2\"", "Tue, 20 Oct 2026 15:01:00 GMT")

    http = fn
      :head, _url -> {:ok, response(200, updated_headers, nil)}
      :get, _url -> {:ok, response(200, updated_headers, @body)}
    end

    assert {:ok, [%{status: :changed}]} =
             Check.check(path, http: discovery_http(http), update: true)

    assert {:ok, manifest} = path |> File.read!() |> Jason.decode()
    assert [%{"etag" => "\"etag-2\"", "sha256" => @sha256}] = manifest["sources"]
  end

  test "default run never writes refreshed metadata" do
    original = source()
    path = manifest_path(original)
    original_contents = File.read!(path)
    updated_headers = headers("\"etag-2\"", "Tue, 20 Oct 2026 15:01:00 GMT")

    http = fn
      :head, _url -> {:ok, response(200, updated_headers, nil)}
      :get, _url -> {:ok, response(200, updated_headers, @body)}
    end

    assert {:ok, [%{status: :changed}]} = Check.check(path, http: discovery_http(http))
    assert File.read!(path) == original_contents
  end

  test "task succeeds for unchanged sources and fails for changed sources" do
    output =
      with_task_http(packaged_manifest_http(), fn ->
        capture_io(fn -> assert is_nil(CheckTask.run([])) end)
      end)

    assert output == "cfdi-4.0-catalogs unchanged\ncfdi-4.0-catcfdi-xsd unchanged\n"

    assert_raise Mix.Error, fn ->
      with_task_http(packaged_manifest_http("cfdi-4.0-catalogs"), fn ->
        capture_io(fn -> CheckTask.run([]) end)
      end)
    end
  end

  test "task --update writes the discovered URL and derived filename before reporting changed" do
    path = manifest_path(source())
    url = "https://example.invalid/documentos/catCFDI_V_4_20270115.xls"
    updated_headers = headers() |> Map.delete("content-disposition")

    http = fn
      :get, "https://example.invalid/discovery" ->
        {:ok,
         response(
           200,
           %{},
           ~s(<a href="documentos/catCFDI_V_4_20270115.xls">Synthetic catalog</a>)
         )}

      :head, ^url ->
        {:ok, response(200, updated_headers, nil)}

      :get, ^url ->
        {:ok, response(200, updated_headers, @body)}
    end

    assert_raise Mix.Error, fn ->
      with_task_config(http, path, fn ->
        capture_io(fn -> CheckTask.run(["--update"]) end)
      end)
    end

    assert {:ok,
            %{
              "sources" => [
                %{
                  "url" => ^url,
                  "filename" => "catCFDI_V_4_20270115.xls",
                  "etag" => "\"etag-1\"",
                  "sha256" => @sha256
                }
              ]
            }} =
             path |> File.read!() |> Jason.decode()
  end

  test "a stable validator still hashes content and stays unchanged when the hash matches" do
    path =
      source()
      |> Map.put("etag", nil)
      |> Map.put("last_modified_reliable", false)
      |> then(&manifest_path/1)

    test_process = self()
    hash_headers = headers() |> Map.delete("etag")

    http = fn
      :head, url ->
        send(test_process, {:request, :head, url})
        {:ok, response(200, hash_headers, nil)}

      :get, url ->
        send(test_process, {:request, :get, url})
        {:ok, response(200, hash_headers, @body)}
    end

    assert {:ok, [%{status: :unchanged}]} =
             Check.check(path, http: discovery_http(http))

    assert_received {:request, :get, "https://example.invalid/discovery"}
    assert_received {:request, :get, "https://example.invalid/source.xls"}
  end

  test "discovers a new URL even while the old URL still responds successfully" do
    path = manifest_path(source())
    new_url = "https://example.invalid/releases/updated.xls"
    test_process = self()

    http = fn
      :get, "https://example.invalid/discovery" ->
        send(test_process, {:request, :get, "https://example.invalid/discovery"})
        {:ok, response(200, %{}, ~s(<a href="/releases/updated.xls">Synthetic catalog</a>))}

      :head, "https://example.invalid/source.xls" ->
        send(test_process, {:request, :head, "https://example.invalid/source.xls"})
        {:ok, response(200, headers(), nil)}

      :head, ^new_url ->
        send(test_process, {:request, :head, new_url})

        {:ok, response(200, headers(), nil)}

      :get, ^new_url ->
        {:ok, response(200, headers(), @body)}
    end

    assert {:ok, [%{status: :changed, source: %{"url" => ^new_url}}]} =
             Check.check(path, http: http)

    assert_received {:request, :get, "https://example.invalid/discovery"}
    assert_received {:request, :head, ^new_url}
    refute_received {:request, :head, "https://example.invalid/source.xls"}
  end

  test "same discovered URL with a new response filename is reported changed" do
    path = manifest_path(source())
    test_process = self()

    http = fn
      :get, "https://example.invalid/discovery" ->
        send(test_process, {:request, :get, "https://example.invalid/discovery"})
        {:ok, response(200, %{}, ~s(<a href="/source.xls">Synthetic catalog</a>))}

      :head, "https://example.invalid/source.xls" ->
        send(test_process, {:request, :head, "https://example.invalid/source.xls"})
        new_headers = headers("\"etag-1\"", "Tue, 20 Oct 2026 15:00:00 GMT", "renamed.xls")
        {:ok, response(200, new_headers, nil)}

      :get, "https://example.invalid/source.xls" ->
        new_headers = headers("\"etag-1\"", "Tue, 20 Oct 2026 15:00:00 GMT", "renamed.xls")
        {:ok, response(200, new_headers, @body)}
    end

    assert {:ok,
            [
              %{
                status: :changed,
                source: %{
                  "url" => "https://example.invalid/source.xls",
                  "filename" => "renamed.xls"
                }
              }
            ]} =
             Check.check(path, http: http)

    assert_received {:request, :get, "https://example.invalid/discovery"}
    assert_received {:request, :head, "https://example.invalid/source.xls"}
  end

  test "invalid Content-Length is ignored as unknown metadata" do
    path = manifest_path(source())
    invalid_headers = headers() |> Map.put("content-length", ["12 "])

    http = fn
      :head, _url -> {:ok, response(200, invalid_headers, nil)}
      :get, _url -> {:ok, response(200, invalid_headers, @body)}
    end

    assert {:ok, [%{status: :unchanged}]} = Check.check(path, http: discovery_http(http))
  end

  test "default manifest is read from the package when cwd has no priv directory" do
    original_cwd = File.cwd!()

    outside_repo =
      Path.join(System.tmp_dir!(), "sat-catalogs-cwd-#{System.unique_integer([:positive])}")

    File.mkdir_p!(outside_repo)

    on_exit(fn ->
      File.cd!(original_cwd)
      File.rm_rf!(outside_repo)
    end)

    File.cd!(outside_repo)

    http = fn _method, _url -> {:error, :offline_fixture} end
    assert {:ok, [%{status: :unreachable}, %{status: :unreachable}]} = Check.check(http: http)
  end

  test "link text normalizes named and numeric HTML entities" do
    path = manifest_path(Map.put(source(), "discovery_link_text", "Catálogos & Síntesis"))

    http = fn
      :get, "https://example.invalid/discovery" ->
        {:ok,
         response(200, %{}, ~s(<a href="/source.xls">​Cat&aacute;logos &#38; S&iacute;ntesis</a>))}

      :head, _url ->
        {:ok, response(200, headers(), nil)}

      :get, _url ->
        {:ok, response(200, headers(), @body)}
    end

    assert {:ok, [%{status: :unchanged}]} = Check.check(path, http: http)
  end

  defp source do
    %{
      "id" => "test-source",
      "url" => "https://example.invalid/source.xls",
      "discovery_page_url" => "https://example.invalid/discovery",
      "discovery_link_text" => "Synthetic catalog",
      "filename" => "source.xls",
      "last_modified" => "Tue, 20 Oct 2026 15:00:00 GMT",
      "etag" => "\"etag-1\"",
      "sha256" => @sha256
    }
  end

  defp headers(
         etag \\ "\"etag-1\"",
         last_modified \\ "Tue, 20 Oct 2026 15:00:00 GMT",
         filename \\ "source.xls"
       ) do
    %{
      "last-modified" => [last_modified],
      "etag" => [etag],
      "content-disposition" => ["attachment; filename=\"#{filename}\""]
    }
  end

  defp response(status, headers, body) do
    %{status: status, headers: headers, body: body}
  end

  defp discovery_http(http) do
    fn
      :get, "https://example.invalid/discovery" ->
        send(self(), {:request, :get, "https://example.invalid/discovery"})
        {:ok, response(200, %{}, ~s(<a href="/source.xls">Synthetic catalog</a>))}

      method, url ->
        http.(method, url)
    end
  end

  defp with_task_config(http, path, fun) do
    config_keys = [:catalogs_check_http, :catalogs_check_manifest_path]
    previous = Enum.map(config_keys, &{&1, Application.fetch_env(:sat_mexico, &1)})

    Application.put_env(:sat_mexico, :catalogs_check_http, http)
    Application.put_env(:sat_mexico, :catalogs_check_manifest_path, path)

    try do
      fun.()
    after
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:sat_mexico, key, value)
        {key, :error} -> Application.delete_env(:sat_mexico, key)
      end)
    end
  end

  defp with_task_http(http, fun) do
    previous = Application.fetch_env(:sat_mexico, :catalogs_check_http)
    Application.put_env(:sat_mexico, :catalogs_check_http, http)

    try do
      fun.()
    after
      case previous do
        {:ok, value} -> Application.put_env(:sat_mexico, :catalogs_check_http, value)
        :error -> Application.delete_env(:sat_mexico, :catalogs_check_http)
      end
    end
  end

  defp packaged_manifest_http(changed_id \\ nil) do
    {:ok, %{"sources" => sources}} = "priv/sources.json" |> File.read!() |> Jason.decode()
    discovery_url = hd(sources)["discovery_page_url"]

    discovery_body =
      Enum.map_join(sources, "\n", fn source ->
        ~s(<a href="#{source["url"]}">#{source["discovery_link_text"]}</a>)
      end)

    fn
      :get, ^discovery_url ->
        {:ok, response(200, %{}, discovery_body)}

      method, url when method in [:head, :get] ->
        source = Enum.find(sources, &(&1["url"] == url)) || raise "unexpected source URL: #{url}"
        etag = if source["id"] == changed_id, do: "\"changed-etag\"", else: source["etag"]

        source_headers = %{
          "last-modified" => [source["last_modified"]],
          "etag" => [etag],
          "content-length" => [Integer.to_string(source["content_length"])],
          "content-disposition" => ["attachment; filename=\"#{source["filename"]}\""]
        }

        {:ok, response(200, source_headers, if(method == :get, do: @body))}
    end
  end

  defp manifest_path(source) do
    path =
      Path.join(
        System.tmp_dir!(),
        "sat-catalogs-check-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, Jason.encode!(%{"version" => 1, "sources" => [source]}, pretty: true))
    on_exit(fn -> File.rm(path) end)
    path
  end
end
