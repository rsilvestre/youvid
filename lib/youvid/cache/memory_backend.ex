defmodule Youvid.Cache.MemoryBackend do
  @moduledoc """
  In-memory cache backend implementation using ETS tables.

  This backend stores cache entries in memory using ETS tables.
  It is fast but not persistent across application restarts.

  ## Configuration

  The MemoryBackend supports the following options:

  * `:table_name` - The name of the ETS table to use (defaults to `:youvid_cache`)
  * `:max_size` - Maximum number of entries in the cache (defaults to 1000)
  """

  @behaviour Youvid.Cache.Backend

  @default_max_size 1000

  @options_schema [
    table_name: [
      type: :atom,
      default: :youvid_cache,
      doc: "The name of the ETS table to use for cache storage"
    ],
    max_size: [
      type: {:custom, __MODULE__, :validate_positive_integer, []},
      default: @default_max_size,
      doc: "Maximum number of entries in the cache"
    ]
  ]

  # Custom validator for positive integers
  def validate_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}
  def validate_positive_integer(value), do: {:error, "expected a positive integer, got: #{inspect(value)}"}

  # Backend Implementation

  @impl true
  def init(options) do
    case NimbleOptions.validate(options, @options_schema) do
      {:ok, validated_options} ->
        table_name = validated_options[:table_name]
        max_size = validated_options[:max_size]
        table_options = [:set, :public, :named_table]

        case :ets.info(table_name) do
          :undefined ->
            :ets.new(table_name, table_options)
            {:ok, %{table: table_name, max_size: max_size}}

          _ ->
            # Table already exists
            {:ok, %{table: table_name, max_size: max_size}}
        end

      {:error, %NimbleOptions.ValidationError{} = error} ->
        {:error, Exception.message(error)}
    end
  end

  @impl true
  def put(key, value, ttl, state) do
    # Check if we're at max size and delete oldest item if needed
    current_size = :ets.info(state.table, :size)

    if current_size >= state.max_size do
      delete_oldest(state.table)
    end

    expiry = System.system_time(:millisecond) + ttl
    :ets.insert(state.table, {key, value, expiry})
    :ok
  end

  @impl true
  def get(key, state) do
    case :ets.lookup(state.table, key) do
      [{^key, value, expiry}] ->
        if System.system_time(:millisecond) < expiry do
          value
        else
          # Delete expired entry
          :ets.delete(state.table, key)
          nil
        end

      [] ->
        nil
    end
  end

  @impl true
  def delete(key, state) do
    :ets.delete(state.table, key)
    :ok
  end

  @impl true
  def clear(state) do
    :ets.delete_all_objects(state.table)
    :ok
  end

  @impl true
  def cleanup(state) do
    now = System.system_time(:millisecond)

    # Delete all expired entries
    :ets.select_delete(state.table, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])

    :ok
  end

  # Helper functions

  defp delete_oldest(table) do
    now = System.system_time(:millisecond)
    {key, _expiry} = find_oldest_entry(table, now)
    if key, do: :ets.delete(table, key), else: :ok
  end

  defp find_oldest_entry(table, now) do
    :ets.foldl(
      fn {key, _value, expiry}, {oldest_key, oldest_expiry} ->
        if expiry < oldest_expiry do
          {key, expiry}
        else
          {oldest_key, oldest_expiry}
        end
      end,
      # Default far in the future
      {nil, now + 86_400_000 * 2},
      table
    )
  end
end
