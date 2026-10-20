defmodule SAT.Catalogs.CheckTest do
  use ExUnit.Case, async: true

  alias SAT.Catalogs.Check

  @url "https://sat.gob.mx/catalogs/catCFDI_V_4.xls"
  @discovery_url "https://sat.gob.mx/anexo_20"
  @old_modified "Mon, 20 Oct 2025 10:00:00 GMT"
  @new_modified "Tue, 20 Oct 2026 10:00:00 GMT"

  test "reports unchanged without downloading when validators match" do
    manifest = [source()]
    before = Jason.encode!(manifest, pretty: true) <> "\n"
    path = write_manifest(manifest)

    http = fn
      :head, @url ->
        response(200, %{
          "last-modified" => @old_modified,
          "etag" => "\"v1\""
        })

      method, url ->
        flunk("unexpected #{method} request to #{url}")
    end

    assert {:ok, [%{id: "cfdi_4_0_catalogs", status: :unchanged}]} =
             Check.run(manifest_path: path, http: http, output: fn _ -> :ok end)

    assert File.read!(path) == before
  end

  test "detects an ETag change and leaves the manifest unchanged by default" do
    manifest = [source()]
    path = write_manifest(manifest)
    before = File.read!(path)

    http = fn
      :head, @url ->
        response(200, %{"last-modified" => @old_modified, "etag" => "\"v2\""})

      :get, @url ->
        response(200, %{}, "catalog-v2")
    end

    assert {:error, [%{status: :changed}]} =
             Check.run(manifest_path: path, http: http, output: fn _ -> :ok end)

    assert File.read!(path) == before
  end

  test "downloads to compare SHA-256 when Last-Modified changes but ETag does not" do
    manifest = [source()]
    path = write_manifest(manifest)

    http = fn
      :head, @url ->
        response(200, %{"last-modified" => @new_modified, "etag" => "\"v1\""})

      :get, @url ->
        response(200, %{}, "catalog-v2")
    end

    assert {:error, [%{status: :changed}]} =
             Check.run(manifest_path: path, http: http, output: fn _ -> :ok end)

    assert File.read!(path) == Jason.encode!(manifest, pretty: true) <> "\n"
  end

  test "finds a renamed file through the discovery page and records it with update" do
    manifest = [source()]
    path = write_manifest(manifest)
    new_url = "https://sat.gob.mx/catalogs/catCFDI_V_4_20261020.xls"
    page = ~s(<a href="/catalogs/catCFDI_V_4_20261020.xls">Catálogos CFDI 4.0</a>)

    http = fn
      :head, @url ->
        response(404)

      :get, @discovery_url ->
        response(200, %{}, page)

      :head, ^new_url ->
        response(200, %{"last-modified" => @new_modified, "etag" => "\"v2\""})

      :get, ^new_url ->
        response(200, %{}, "catalog-v2")
    end

    assert {:error, [%{status: :changed}]} =
             Check.run(
               manifest_path: path,
               http: http,
               update: true,
               output: fn _ -> :ok end
             )

    [updated] = Jason.decode!(File.read!(path))
    assert updated["url"] == new_url
    assert updated["etag"] == "\"v2\""
    assert updated["last_modified"] == @new_modified
    assert updated["sha256"] == sha256("catalog-v2")
  end

  test "checks the discovery page when the previous workbook URL is still live" do
    manifest = [Map.put(source(), "discover_on_each_check", true)]
    path = write_manifest(manifest)
    new_url = "https://sat.gob.mx/catalogs/catCFDI_V_4_20261020.xls"
    page = ~s(<a href="/catalogs/catCFDI_V_4_20261020.xls">Catálogos CFDI 4.0</a>)

    http = fn
      :get, @discovery_url ->
        response(200, %{}, page)

      :head, @url ->
        response(200, %{"last-modified" => @old_modified, "etag" => "\"v1\""})

      :head, ^new_url ->
        response(200, %{"last-modified" => @new_modified, "etag" => "\"v2\""})

      :get, ^new_url ->
        response(200, %{}, "catalog-v2")
    end

    assert {:error, [%{status: :changed}]} =
             Check.run(
               manifest_path: path,
               http: http,
               update: true,
               output: fn _ -> :ok end
             )

    [updated] = Jason.decode!(File.read!(path))
    assert updated["url"] == new_url
    assert updated["sha256"] == sha256("catalog-v2")
  end

  test "accepts SAT schema links whose binary URL has no xsd path suffix" do
    source =
      source()
      |> Map.put("id", "cfdi_4_0_catalog_schema")
      |> Map.put("url", "https://sat.gob.mx/catalogos/catCFDI.xsd")
      |> Map.put(
        "discovery_page_url",
        "https://wwwmat.sat.gob.mx/cs/Satellite?c=ConsultaInfo"
      )
      |> Map.put("discovery_match", "Catálogo de datos de CFDI")
      |> Map.put("expected_extension", ".xsd")

    manifest = [source]
    path = write_manifest(manifest)

    binary_url =
      "https://wwwmat.sat.gob.mx/cs/Satellite?blobcol=urldata&ssbinary=true"

    page =
      ~S|<a href="/cs/Satellite?blobcol=urldata&amp;ssbinary=true">Catálogo de datos de CFDI versión 4.0 (xsd)</a>|

    http = fn
      :head, "https://sat.gob.mx/catalogos/catCFDI.xsd" ->
        response(404)

      :get, "https://wwwmat.sat.gob.mx/cs/Satellite?c=ConsultaInfo" ->
        response(200, %{}, page)

      :head, ^binary_url ->
        response(200, %{"etag" => "\"zip-v1\""})

      :get, ^binary_url ->
        response(200, %{}, "schema-package")
    end

    assert {:error, [%{id: "cfdi_4_0_catalog_schema", status: :changed}]} =
             Check.run(manifest_path: path, http: http, output: fn _ -> :ok end)
  end

  test "reports unreachable when a source request fails" do
    manifest = [source()]
    path = write_manifest(manifest)
    http = fn :head, @url -> {:error, :timeout} end

    assert {:error, [%{id: "cfdi_4_0_catalogs", status: :unreachable}]} =
             Check.run(manifest_path: path, http: http, output: fn _ -> :ok end)
  end

  defp source do
    %{
      "id" => "cfdi_4_0_catalogs",
      "url" => @url,
      "discovery_page_url" => @discovery_url,
      "discovery_match" => "catCFDI",
      "expected_extension" => ".xls",
      "sheet_name" => "c_FormaPago",
      "header_row" => 1,
      "version" => "CFDI 4.0",
      "last_modified" => @old_modified,
      "etag" => "\"v1\"",
      "sha256" => sha256("catalog-v1")
    }
  end

  defp response(status, headers \\ %{}, body \\ "") do
    {:ok, %{status: status, headers: headers, body: body}}
  end

  defp write_manifest(manifest) do
    path =
      Path.join(
        System.tmp_dir!(),
        "sat-catalogs-#{System.unique_integer([:positive, :monotonic])}.json"
      )

    File.write!(path, Jason.encode!(manifest, pretty: true) <> "\n")
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end
