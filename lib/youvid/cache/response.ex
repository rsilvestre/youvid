defprotocol Youvid.Cache.Response do
  @moduledoc """
  Protocol for defining consistent cache response formats.

  This protocol ensures that all cache backends return data in a consistent format,
  regardless of the underlying implementation details.
  """

  @doc """
  Formats a cache response to ensure consistent output across backends.

  Returns:
  - `{:ok, value}` - For successful cache hits
  - `{:miss, nil}` - For cache misses
  - `{:error, reason}` - For error conditions
  """
  @spec format(any()) :: {:ok, any()} | {:miss, nil} | {:error, any()}
  def format(response)
end

defimpl Youvid.Cache.Response, for: Tuple do
  def format({:ok, value}), do: {:ok, value}
  def format({:error, reason}), do: {:error, reason}
  # Handle any other tuples
  def format(tuple), do: {:ok, tuple}
end

defimpl Youvid.Cache.Response, for: Atom do
  def format(nil), do: {:miss, nil}
  def format(:ok), do: {:ok, :ok}
  def format(atom), do: {:ok, atom}
end

defimpl Youvid.Cache.Response, for: Any do
  def format(nil), do: {:miss, nil}
  def format(value), do: {:ok, value}
end
