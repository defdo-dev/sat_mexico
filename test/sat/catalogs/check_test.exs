defmodule SAT.Catalogs.CheckTest do
  use ExUnit.Case, async: true

  alias SAT.Catalogs.Check

  @body "safe synthetic SAT source bytes"
  @sha256 :crypto.hash(:sha256, @body) |> Base.encode16(case: :lower)

  test "unchanged source needs only HEAD metadata" do
    path = manifest_path(source())
    test_process = self()

    http = fn method, url ->
      send(test_process, {:request, method, url})
      {:ok, response(200, headers(), nil)}
    end

    assert {:ok, [%{id: "test-source", status: :unchanged}]} = Check.check(path, http: http)
    assert_received {:request, :head, "https://example.invalid/source.xls"}
    refute_received {:request, :get, _url}
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

    assert {:ok, [%{status: :unchanged}]} = Check.check(path, http: http)
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

    assert {:ok, [%{status: :changed}]} = Check.check(path, http: http)
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
             Check.check(path, http: http)

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
             Check.check(path, http: http)

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
             Check.check(path, http: http)
  end

  test "update writes refreshed metadata and hash" do
    path = manifest_path(source())
    updated_headers = headers("\"etag-2\"", "Tue, 20 Oct 2026 15:01:00 GMT")

    http = fn
      :head, _url -> {:ok, response(200, updated_headers, nil)}
      :get, _url -> {:ok, response(200, updated_headers, @body)}
    end

    assert {:ok, [%{status: :changed}]} = Check.check(path, http: http, update: true)
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

    assert {:ok, [%{status: :changed}]} = Check.check(path, http: http)
    assert File.read!(path) == original_contents
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
