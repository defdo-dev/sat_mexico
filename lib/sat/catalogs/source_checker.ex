defmodule SAT.Catalogs.SourceChecker do
  @moduledoc false

  @type source :: %{String.t() => term()}
  @type result :: %{source: source(), status: :unchanged | :changed | :unreachable}

  @spec check([source()], (atom(), String.t() -> term())) :: [result()]
  def check(sources, request_fun \\ &request/2) do
    Enum.map(sources, &check_source(&1, request_fun))
  end

  @doc false
  def request(method, url) do
    Req.request(method: method, url: url, receive_timeout: 120_000, max_redirects: 5)
  end

  defp check_source(source, request_fun) do
    # The prior SAT file can stay reachable after its discovery page links a replacement.
    previous_head = request_fun.(:head, source["url"])

    with {:ok, %{status: page_status, body: html}}
         when page_status in 200..299 and is_binary(html) <-
           request_fun.(:get, source["discovery_url"]),
         {:ok, url} <- find_current_url(source, html),
         {:ok, %{status: file_status} = response}
         when file_status in 200..299 <- current_head(source, url, previous_head, request_fun) do
      source_from_response(source, url, response, request_fun)
    else
      _unavailable ->
        result(source, :unreachable)
    end
  end

  defp current_head(source, url, previous_head, request_fun) do
    if url == source["url"], do: previous_head, else: request_fun.(:head, url)
  end

  defp source_from_response(source, url, response, request_fun) do
    metadata = %{
      "last_modified" => header(response, "last-modified"),
      "etag" => header(response, "etag")
    }

    url_changed? = url != source["url"]
    metadata_changed? = Enum.any?(metadata, fn {key, value} -> source[key] != value end)

    # An unchanged URL and Last-Modified/ETag are trusted as the download gate.
    # SHA-256 is refreshed only after one of those validators changes.
    if not url_changed? and not metadata_changed? do
      result(source, :unchanged)
    else
      source_with_body(source, url, metadata, request_fun)
    end
  end

  defp source_with_body(source, url, metadata, request_fun) do
    case request_fun.(:get, url) do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
        checksum = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

        updated =
          source
          |> Map.merge(metadata)
          |> Map.put("url", url)
          |> Map.put("sha256", checksum)

        changed? =
          url != source["url"] or Enum.any?(metadata, fn {key, value} -> source[key] != value end) or
            checksum != source["sha256"]

        result(updated, if(changed?, do: :changed, else: :unchanged))

      _unavailable ->
        result(source, :unreachable)
    end
  end

  defp find_current_url(source, html) do
    pattern = Regex.compile!(source["discovery_match"], "i")

    html
    |> then(&Regex.scan(~r/href\s*=\s*["']([^"']+)["']/i, &1, capture: :all_but_first))
    |> Enum.map(fn [href] -> href end)
    |> Enum.map(&URI.merge(source["discovery_url"], &1))
    |> Enum.find_value(fn uri ->
      if Regex.match?(pattern, Path.basename(uri.path || "")), do: URI.to_string(uri)
    end)
    |> case do
      nil -> :error
      url -> {:ok, keep_existing_url(source["url"], url)}
    end
  end

  defp keep_existing_url(existing_url, discovered_url) do
    existing = URI.parse(existing_url)
    discovered = URI.parse(discovered_url)

    same_resource? =
      existing.host == discovered.host and existing.path == discovered.path and
        existing.query == discovered.query

    preserve_existing? =
      same_resource? and
        (existing.scheme == discovered.scheme or
           (existing.scheme == "https" and discovered.scheme == "http"))

    if preserve_existing? do
      existing_url
    else
      discovered_url
    end
  end

  defp header(%{headers: headers}, name) do
    headers
    |> Map.get(name, [])
    |> List.wrap()
    |> List.first()
  end

  defp result(source, status), do: %{source: source, status: status}
end
