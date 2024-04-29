defmodule SAT.FileManager do
  @moduledoc false

  @type path :: String.t()
  @type document :: String.t()
  @type reason :: atom

  @spec read(path()) :: document() | {:error, reason}
  def read(path) do
    with {:ok, document} <- File.read(path) do
      # remove UTF-8's BOM
      String.replace(document, "\uFEFF", "")
    else
      error ->
        error
    end
  end
end
