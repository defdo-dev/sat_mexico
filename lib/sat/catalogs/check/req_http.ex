defmodule SAT.Catalogs.Check.ReqHTTP do
  @moduledoc false

  def request(method, url) do
    case Req.request(
           method: method,
           url: url,
           redirect: false,
           retry: false,
           decode_body: false,
           http_errors: :return
         ) do
      {:ok, response} ->
        {:ok, %{status: response.status, headers: response.headers, body: response.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
