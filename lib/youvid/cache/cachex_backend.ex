defmodule Youvid.Cache.CachexBackend do
  @moduledoc """
  Cachex-based backend implementation for distributed caching.

  This backend uses Cachex for caching, which provides distributed caching capabilities
  when used with Erlang's distributed node system. This allows multiple application
  instances to share a cache across a cluster.

  To use this backend, you must have the following dependencies installed:
  - cachex

  ## Configuration

  To configure this backend, add the following to your config:

  ```elixir
  config :youvid,
    cache_backends: %{
      transcript_lists: %{
        backend: Youvid.Cache.CachexBackend,
        backend_options: [
          table_name: :transcript_lists_cache,  # Cache name
          distributed: true,                    # Enable distributed mode
          default_ttl: :timer.hours(24),        # TTL for cache entries
          cleanup_interval: :timer.minutes(10), # How often to clean expired entries
          cachex_options: []                    # Additional Cachex options
        ]
      }
    }
  ```

  ## Distributed Operation

  For distributed operation, all nodes must be connected in an Erlang cluster.
  You should use a library like [libcluster](https://github.com/bitwalker/libcluster)
  for reliable node discovery and connection in production environments.

  Example of manual node connection:

  ```elixir
  # On node1@example.com
  Node.connect(:"node2@example.com")

  # On node2@example.com
  Node.connect(:"node1@example.com")
  ```

  ## Caveats

  - All nodes must have proper names (not anonymous)
  - All nodes must share the same Erlang cookie for security
  - There may be a short delay before cache updates propagate to all nodes
  """

  @behaviour Youvid.Cache.Backend

  @options_schema [
    table_name: [
      type: :atom,
      default: :youvid_cache,
      doc: "Cache table name used by Cachex"
    ],
    distributed: [
      type: :boolean,
      default: false,
      doc: "Enable distributed caching across Erlang nodes"
    ],
    default_ttl: [
      type: {:or, [:integer, {:in, [:infinity]}]},
      default: :timer.hours(24),
      doc: "Default time-to-live for cache entries in milliseconds"
    ],
    cleanup_interval: [
      type: :integer,
      default: :timer.minutes(10),
      doc: "Interval in milliseconds for cleaning expired entries"
    ],
    cachex_options: [
      type: :keyword_list,
      default: [],
      doc: "Additional options passed directly to Cachex.start_link/2"
    ]
  ]

  # Backend Implementation

  @impl true
  def init(options) do
    case NimbleOptions.validate(options, @options_schema) do
      {:ok, validated_options} ->
        with {:ok, _} <- ensure_dependencies_loaded(),
             cache_config <- build_cache_config(validated_options),
             {:ok, _} <- start_cachex(cache_config) do
          {:ok, %{cache: cache_config.cache_name}}
        else
          {:error, reason} -> {:error, reason}
        end

      {:error, %NimbleOptions.ValidationError{} = error} ->
        {:error, Exception.message(error)}
    end
  end

  # Extract configuration from options
  defp build_cache_config(options) do
    cache_name = options[:table_name]
    distributed = options[:distributed]
    default_ttl = options[:default_ttl]
    cleanup_interval = options[:cleanup_interval]
    additional_opts = options[:cachex_options]

    nodes = if(distributed and Node.alive?(), do: Node.list(), else: [])

    cache_options = [
      expiration: [
        default: default_ttl,
        interval: cleanup_interval
      ],
      nodes: nodes,
      distributed: distributed
    ] ++ additional_opts

    %{
      cache_name: cache_name,
      cache_options: cache_options
    }
  end

  # Start Cachex instance with the given configuration
  defp start_cachex(config) do
    case Cachex.start_link(config.cache_name, config.cache_options) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, reason} = error ->
        # If it's because the cache is already started, that's okay
        if already_started?(reason) do
          {:ok, :already_started}
        else
          error
        end
    end
  end

  # Check if the error indicates that the cache is already started
  defp already_started?(reason) do
    is_tuple(reason) and tuple_size(reason) > 0 and elem(reason, 0) == :already_started
  end

  @impl true
  def put(key, value, ttl, state) do
    case Cachex.put(state.cache, key, value, ttl: ttl) do
      {:ok, true} -> {:ok, state}
      {:ok, false} -> {:error, :put_failed}
      error -> error
    end
  end

  @impl true
  def get(key, state) do
    case Cachex.get(state.cache, key) do
      {:ok, nil} -> nil
      {:ok, value} -> value
      _error -> nil
    end
  end

  @impl true
  def delete(key, state) do
    case Cachex.del(state.cache, key) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @impl true
  def clear(state) do
    case Cachex.clear(state.cache) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @impl true
  def cleanup(_state) do
    # Cachex automatically handles expiration based on the interval set during initialization
    # This is a no-op for compatibility with the backend behavior
    :ok
  end

  # Helper functions

  defp ensure_dependencies_loaded do
    module = Cachex

    case Code.ensure_loaded(module) do
      {:module, _} -> {:ok, nil}
      {:error, _} -> {:error, {:missing_dependency, :cachex}}
    end
  end
end
