defmodule SAT.Catalogs.Check do
  @moduledoc """
  Checks pinned SAT catalog sources without changing the manifest by default.
  """

  @redirect_statuses [301, 302, 303, 307, 308]
  @max_redirects 10
  @anchor_regex ~r/<a\b[^>]*\bhref\s*=\s*(?:"([^"]+)"|'([^']+)')[^>]*>(.*?)<\/a>/isu

  @type status :: :unchanged | :changed | :unreachable
  @type result :: %{id: String.t(), status: status()}

  @doc """
  Checks every source in the manifest.

  Options:

    * manifest_path - path to a JSON source manifest
    * http - a (method, url) -> response function for HTTP injection
    * update - write fresh URL, HTTP metadata and SHA-256 values
    * output - callback for one status line per source

  The function returns {:ok, results} only when every source is unchanged.
  Changed and unreachable sources return {:error, results}.
  """
  @spec run(keyword()) :: {:ok, [result()]} | {:error, [result()]}
  def run(opts \\ []) do
    path = Keyword.get(opts, :manifest_path, default_manifest_path())
    http = Keyword.get(opts, :http, &SAT.Catalogs.Check.ReqHTTP.request/2)
    update? = Keyword.get(opts, :update, false)
    output = Keyword.get(opts, :output, &IO.puts/1)

    sources =
      path
      |> File.read!()
      |> Jason.decode!()

    unless is_list(sources) do
      raise ArgumentError, "SAT source manifest must be a JSON list"
    end

    checked =
      Enum.map(sources, fn source ->
        case check_source(source, http) do
          {:ok, status, updated_source} ->
            {updated_source, %{id: source["id"], status: status}}

          :unreachable ->
            {source, %{id: source["id"], status: :unreachable}}
        end
      end)

    Enum.each(checked, fn {_source, result} ->
      output.("#{result.id}: #{result.status}")
    end)

    if update? do
      updated_sources = Enum.map(checked, &elem(&1, 0))
      if updated_sources != sources, do: write_manifest(path, updated_sources)
    end

    results = Enum.map(checked, &elem(&1, 1))

    if Enum.all?(results, &(&1.status == :unchanged)) do
      {:ok, results}
    else
      {:error, results}
    end
  end

  defp check_source(source, http) do
    with {:ok, url, head} <- head_current(source, http),
         metadata = current_metadata(url, head),
         {:ok, sha256} <- current_sha256(source, url, metadata, http) do
      updated_source = Map.merge(source, metadata)
      updated_source = Map.put(updated_source, "sha256", sha256)

      status =
        if url != source["url"] or sha256 != source["sha256"] do
          :changed
        else
          :unchanged
        end

      {:ok, status, updated_source}
    else
      _ -> :unreachable
    end
  end

  defp head_current(source, http) do
    if sat_url?(source["url"]) do
      if source["discover_on_each_check"] do
        discover_current(source, http)
      else
        do_head_current(source, http)
      end
    else
      :unreachable
    end
  end

  defp do_head_current(source, http) do
    case request_following_redirects(http, :head, source["url"]) do
      {:ok, response, final_url} ->
        cond do
          successful?(response.status) and
              renamed_redirect?(source["url"], final_url, source["expected_extension"]) ->
            discover_current(source, http)

          successful?(response.status) ->
            {:ok, final_url, response}

          response.status in [404, 410] ->
            discover_current(source, http)

          true ->
            :unreachable
        end

      _ ->
        :unreachable
    end
  end

  defp discover_current(source, http) do
    with discovery_url when is_binary(discovery_url) <- source["discovery_page_url"],
         true <- sat_url?(discovery_url),
         {:ok, page, _final_url} <- request_following_redirects(http, :get, discovery_url),
         true <- successful?(page.status),
         links <- discovery_links(page.body, discovery_url, source),
         [current_url | _] <- links,
         {:ok, head, final_url} <- request_following_redirects(http, :head, current_url),
         true <- successful?(head.status) do
      {:ok, final_url, head}
    else
      _ -> :unreachable
    end
  end

  defp discovery_links(body, discovery_url, source) when is_binary(body) do
    match = normalize_text(source["discovery_match"] || "")
    expected_extension = String.downcase(source["expected_extension"] || "")

    Regex.scan(@anchor_regex, body)
    |> Enum.flat_map(fn [_anchor, double_quoted, single_quoted, text] ->
      href = first_present(double_quoted, single_quoted)
      visible_text = Regex.replace(~r/<[^>]*>/u, text, " ")
      searchable = normalize_text(visible_text <> " " <> href)

      candidate =
        href
        |> String.replace("&amp;", "&")
        |> then(&URI.merge(discovery_url, &1))
        |> prefer_https()
        |> URI.to_string()

      if String.contains?(searchable, match) and sat_url?(candidate) and
           extension_matches?(candidate, expected_extension, searchable) do
        [candidate]
      else
        []
      end
    end)
  end

  defp discovery_links(_body, _discovery_url, _source), do: []

  defp current_metadata(url, response) do
    %{
      "url" => url,
      "last_modified" => response_header(response, "last-modified"),
      "etag" => response_header(response, "etag")
    }
  end

  defp current_sha256(source, url, metadata, http) do
    download? =
      is_nil(source["sha256"]) or source["sha256"] == "" or url != source["url"] or
        metadata["last_modified"] != source["last_modified"] or
        metadata["etag"] != source["etag"] or
        not has_validator?(metadata)

    if download? do
      with {:ok, response, _final_url} <- request_following_redirects(http, :get, url),
           true <- successful?(response.status),
           body when is_binary(body) <- response.body do
        {:ok, :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)}
      else
        _ -> :error
      end
    else
      {:ok, source["sha256"]}
    end
  end

  defp request_following_redirects(http, method, url, redirects \\ 0)

  defp request_following_redirects(_http, _method, _url, redirects)
       when redirects > @max_redirects,
       do: :error

  defp request_following_redirects(http, method, url, redirects) do
    case call_http(http, method, url) do
      {:ok, %{status: status} = response} when status in @redirect_statuses ->
        case response_header(response, "location") do
          location when is_binary(location) and location != "" ->
            next_url = url |> URI.merge(location) |> URI.to_string()

            if sat_url?(next_url) do
              request_following_redirects(http, method, next_url, redirects + 1)
            else
              :error
            end

          _ ->
            {:ok, response, url}
        end

      {:ok, response} ->
        {:ok, response, url}

      _ ->
        :error
    end
  end

  defp call_http(http, method, url) when is_function(http, 2), do: http.(method, url)
  defp call_http(http, method, url), do: http.request(method, url)

  defp response_header(response, name) do
    headers = Map.get(response, :headers, %{})

    case Enum.find(headers, fn {key, _value} -> String.downcase(to_string(key)) == name end) do
      {_key, value} when is_list(value) -> List.first(value)
      {_key, value} -> value
      nil -> nil
    end
  end

  defp successful?(status), do: is_integer(status) and status in 200..299

  defp has_validator?(metadata) do
    present?(metadata["last_modified"]) or present?(metadata["etag"])
  end

  defp present?(value), do: is_binary(value) and value != ""

  defp renamed_redirect?(old_url, new_url, extension)
       when is_binary(extension) and extension != "" do
    old_name = old_url |> URI.parse() |> Map.get(:path, "") |> Path.basename()
    new_name = new_url |> URI.parse() |> Map.get(:path, "") |> Path.basename()

    old_name != new_name and extension_matches?(old_url, extension) and
      extension_matches?(new_url, extension)
  end

  defp renamed_redirect?(_old_url, _new_url, _extension), do: false

  defp extension_matches?(_url, ""), do: true

  defp extension_matches?(url, extension), do: extension_matches?(url, extension, "")

  defp extension_matches?(url, extension, searchable) do
    path_matches? =
      url
      |> URI.parse()
      |> Map.get(:path, "")
      |> String.downcase()
      |> String.ends_with?(extension)

    text_matches? =
      searchable
      |> String.downcase()
      |> String.contains?(String.trim_leading(extension, "."))

    path_matches? or text_matches?
  end

  defp prefer_https(%URI{scheme: "http", host: host} = uri) do
    if sat_host?(host), do: %{uri | scheme: "https"}, else: uri
  end

  defp prefer_https(uri), do: uri

  defp sat_url?(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) ->
        sat_host?(host)

      _ ->
        false
    end
  end

  defp sat_host?(host), do: host == "sat.gob.mx" or String.ends_with?(host, ".sat.gob.mx")

  defp normalize_text(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
  end

  defp first_present(first, second) do
    Enum.find([first, second], &present?/1) || ""
  end

  defp write_manifest(path, sources) do
    json = Jason.encode!(sources, pretty: true) <> "\n"
    File.write!(path, json)
  end

  defp default_manifest_path do
    case :code.priv_dir(:sat_mexico) do
      {:error, _reason} -> Path.expand("../../../priv/sources.json", __DIR__)
      priv_dir -> Path.join(List.to_string(priv_dir), "sources.json")
    end
  end
end
