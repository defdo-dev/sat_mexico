defmodule SAT.Catalogs.Check do
  @moduledoc """
  Checks official SAT source metadata and content hashes against `priv/sources.json`.

  The HTTP function is injectable so the checker can be tested without network access.
  It receives `:head`, `:get_range`, or `:get` and a URL, and returns an HTTP response or an error.
  `:get_range` is a one-byte GET used when a source rejects HEAD.
  """

  @type http_response :: %{status: pos_integer(), headers: map(), body: binary() | nil}
  @type http_fun :: (atom(), String.t() -> {:ok, http_response()} | {:error, term()})

  @spec check(keyword()) :: {:ok, [map()]} | {:error, term()}
  @spec check(Path.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def check(opts) when is_list(opts), do: check(packaged_manifest_path(), opts)

  def check(path \\ packaged_manifest_path(), opts \\ []) do
    http = Keyword.get(opts, :http, &request/2)

    with {:ok, contents} <- File.read(path),
         {:ok, manifest} <- Jason.decode(contents),
         sources when is_list(sources) <- Map.get(manifest, "sources") do
      results = Enum.map(sources, &check_source(&1, http))

      if Keyword.get(opts, :update, false) and Enum.any?(results, &(&1.status == :changed)) do
        updated_manifest = Map.put(manifest, "sources", Enum.map(results, & &1.source))

        updated_manifest =
          Map.put(updated_manifest, "verified_on", Date.utc_today() |> Date.to_iso8601())

        File.write!(path, Jason.encode!(updated_manifest, pretty: true) <> "\n")
      end

      {:ok, results}
    else
      nil -> {:error, :missing_sources}
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_sources}
    end
  end

  defp check_source(source, http) do
    case current_source(source, http) do
      {:ok, url, headers} ->
        check_metadata(source, url, headers, http)

      {:error, reason} ->
        result(source, :unreachable, reason)
    end
  end

  defp current_source(source, http) do
    discover_and_head(source, http)
  end

  defp discover_and_head(source, http) do
    with {:ok, %{status: status, body: body}} when status in 200..299 <-
           call_http(http, :get, source["discovery_page_url"]),
         {:ok, url} <-
           find_source_url(body, source["discovery_page_url"], source["discovery_link_text"]),
         {:ok, %{status: status, headers: headers}} when status in 200..299 <-
           call_http(http, :head, url) do
      {:ok, url, headers}
    else
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
      _other -> {:error, :discovery_link_not_found}
    end
  end

  defp check_metadata(source, url, headers, http) do
    live_metadata = %{
      "url" => url,
      "filename" => response_filename(headers) || source["filename"],
      "last_modified" => response_header(headers, "last-modified"),
      "etag" => response_header(headers, "etag"),
      "content_length" => content_length(headers)
    }

    metadata_changed? =
      Enum.any?(change_keys(source), fn key -> live_metadata[key] != source[key] end)

    # Without a stable validator, only hashing the body can prove the source is unchanged.
    hash_required? =
      is_nil(source["etag"]) and not Map.get(source, "last_modified_reliable", true)

    if metadata_changed? or hash_required? do
      download_and_hash(source, live_metadata, http)
    else
      result(source, :unchanged, nil)
    end
  end

  defp download_and_hash(source, live_metadata, http) do
    case call_http(http, :get, live_metadata["url"]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        sha256 = :crypto.hash(:sha256, body || "") |> Base.encode16(case: :lower)
        updated_source = Map.merge(source, Map.put(live_metadata, "sha256", sha256))

        status =
          if sha256 == source["sha256"] and metadata_equal?(live_metadata, source),
            do: :unchanged,
            else: :changed

        result(updated_source, status, nil)

      {:ok, %{status: status}} ->
        result(source, :unreachable, {:http_status, status})

      {:error, reason} ->
        result(source, :unreachable, reason)
    end
  end

  defp metadata_equal?(left, right) do
    Enum.all?(change_keys(right), fn key -> left[key] == right[key] end)
  end

  defp change_keys(source) do
    keys = ["url", "filename", "etag", "content_length"]

    # SAT's WCM downloads reject HEAD and return a request-time Last-Modified for ranged GETs.
    if Map.get(source, "last_modified_reliable", true) do
      ["last_modified" | keys]
    else
      keys
    end
  end

  defp find_source_url(body, discovery_url, link_text) when is_binary(body) do
    expected_text = normalize_link_text(link_text)

    body
    |> then(&Regex.scan(~r/<a\b([^>]*)>(.*?)<\/a\s*>/is, &1))
    |> Enum.find_value(fn [_, attributes, content] ->
      if normalize_link_text(content) == expected_text do
        attributes
        |> link_href()
        |> case do
          nil -> nil
          href -> URI.merge(discovery_url, href) |> URI.to_string()
        end
      end
    end)
    |> case do
      nil -> {:error, :discovery_link_not_found}
      url -> {:ok, url}
    end
  end

  defp find_source_url(_body, _discovery_url, _link_text), do: {:error, :discovery_link_not_found}

  defp link_href(attributes) do
    case Regex.run(~r/\bhref\s*=\s*["']([^"']*)["']/i, attributes) do
      [_, quoted] ->
        quoted

      _ ->
        case Regex.run(~r/\bhref\s*=\s*([^\s>]+)/i, attributes) do
          [_, unquoted] -> unquoted
          _ -> nil
        end
    end
  end

  defp normalize_link_text(content) do
    content
    |> String.replace(~r/<[^>]+>/, " ")
    |> decode_html_entities()
    |> String.replace(~r/[\x{200B}\x{FEFF}]/u, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.downcase()
  end

  defp decode_html_entities(text) do
    Regex.replace(~r/&(#x[0-9a-f]+|#\d+|[a-z][a-z0-9]+);/i, text, fn entity, name ->
      case String.downcase(name) do
        "amp" -> "&"
        "lt" -> "<"
        "gt" -> ">"
        "quot" -> "\""
        "apos" -> "'"
        "nbsp" -> " "
        "aacute" -> "á"
        "eacute" -> "é"
        "iacute" -> "í"
        "oacute" -> "ó"
        "uacute" -> "ú"
        "ntilde" -> "ñ"
        "uuml" -> "ü"
        "#" <> digits -> decode_numeric_entity(String.downcase(digits), entity)
        _ -> entity
      end
    end)
  end

  defp decode_numeric_entity("x" <> hex, original), do: decode_codepoint(hex, 16, original)
  defp decode_numeric_entity(digits, original), do: decode_codepoint(digits, 10, original)

  defp decode_codepoint(digits, base, original) do
    case Integer.parse(digits, base) do
      {codepoint, ""} when codepoint in 0..0x10FFFF -> <<codepoint::utf8>>
      _ -> original
    end
  rescue
    _ -> original
  end

  defp response_filename(headers) do
    disposition = response_header(headers, "content-disposition") || ""

    case Regex.run(~r/filename\*\s*=\s*UTF-8''([^;]+)/i, disposition) do
      [_, encoded] ->
        URI.decode(encoded)

      _ ->
        case Regex.run(~r/filename\s*=\s*["']?([^;"']+)/i, disposition) do
          [_, filename] -> String.trim(filename)
          _ -> nil
        end
    end
  end

  defp content_length(headers) do
    content_range = response_header(headers, "content-range") || ""

    case Regex.run(~r/bytes\s+\d+-\d+\/(\d+)/i, content_range) do
      [_, length] ->
        parse_integer(length)

      _ ->
        case response_header(headers, "content-length") do
          nil -> nil
          length -> parse_integer(length)
        end
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp response_header(headers, name) do
    value =
      Enum.find_value(headers, fn {key, value} ->
        if String.downcase(to_string(key)) == name, do: value
      end)

    case value do
      [first | _] -> first
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  defp call_http(http, method, url) do
    case http.(method, url) do
      {:ok, %{status: 405}} when method == :head ->
        call_http(http, :get_range, url)

      {:ok, %{status: status, headers: headers} = response} when is_integer(status) ->
        {:ok, %{response | headers: headers || %{}, body: Map.get(response, :body)}}

      {:error, _reason} = error ->
        error

      other ->
        {:error, {:invalid_http_response, other}}
    end
  rescue
    exception -> {:error, exception}
  end

  defp request(method, url) do
    options = if method == :get_range, do: [headers: [{"range", "bytes=0-0"}]], else: []
    request_method = if method == :get_range, do: :get, else: method

    case Req.request(
           Keyword.merge([method: request_method, url: url, receive_timeout: 120_000], options)
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp result(source, status, reason) do
    %{id: source["id"], status: status, source: source, reason: reason}
  end

  defp packaged_manifest_path do
    Application.app_dir(:sat_mexico, "priv/sources.json")
  end
end
