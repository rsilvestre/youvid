defmodule Youvid.Cache do
  @moduledoc """
  Provides caching functionality for video data to reduce API calls to YouTube.

  This module provides a flexible cache system with pluggable backends:

  - Memory: Fast in-memory cache using ETS (default)
  - Disk: Persistent cache using DETS for local storage
  - S3: Cloud storage cache using AWS S3
  - Cachex: Distributed cache using Cachex for horizontal scaling across nodes

  The backend can be configured in your application config.
  """

  use GenServer
  use Youvid.Types

  alias Youvid.{Cache, VideoDetails}

  # Cache registry names
  @video_details_cache :video_details

  # Default TTL of 1 day in milliseconds
  @default_ttl 86_400_000

  # Public API

  @doc """
  Starts the cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Clears all cached data.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # GenServer callbacks

  @doc """
  Gets video details from cache or returns nil if not found.
  """
  @spec get_video_details(video_id) :: {:ok, VideoDetails.t()} | {:miss, nil} | {:error, term()}
  def get_video_details(video_id) do
    GenServer.call(__MODULE__, {:get, @video_details_cache, video_id})
  end

  @doc """
  Caches video details for a video ID.
  """
  @spec put_video_details(video_id, {:ok, VideoDetails.t()}) :: {:ok, VideoDetails.t()}
  def put_video_details(video_id, {:ok, _video_details} = data) do
    ttl = get_ttl()
    GenServer.call(__MODULE__, {:put, @video_details_cache, video_id, data, ttl})
    data
  end

  @impl true
  def init(opts) do
    # Initialize backends based on configuration
    #transcript_lists_backend = init_backend(@transcript_lists_cache, opts)
    #transcript_contents_backend = init_backend(@transcript_contents_cache, opts)
    video_details_backend = init_backend(@video_details_cache, opts)

    # Schedule cleanup
    schedule_cleanup()

    {:ok,
     %{
       backends: %{
         #@transcript_lists_cache => transcript_lists_backend,
         #@transcript_contents_cache => transcript_contents_backend,
         @video_details_cache => video_details_backend
       }
     }}
  end

  @impl true
  def handle_call({:get, cache_name, key}, _from, state) do
    {backend_module, backend_state} = Map.get(state.backends, cache_name)
    result = backend_module.get(key, backend_state)
    formatted_result = Youvid.Cache.Response.format(result)
    {:reply, formatted_result, state}
  end

  @impl true
  def handle_call({:put, cache_name, key, value, ttl}, _from, state) do
    {backend_module, backend_state} = Map.get(state.backends, cache_name)

    case backend_module.put(key, value, ttl, backend_state) do
      :ok ->
        {:reply, :ok, state}

      {:ok, new_backend_state} ->
        new_backends = Map.put(state.backends, cache_name, {backend_module, new_backend_state})
        {:reply, :ok, %{state | backends: new_backends}}

      error ->
        formatted_error = Youvid.Cache.Response.format(error)
        {:reply, formatted_error, state}
    end
  end

  @impl true
  def handle_call(:clear, _from, state) do
    Enum.each(state.backends, fn {_name, {backend_module, backend_state}} ->
      backend_module.clear(backend_state)
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    new_backends =
      Enum.map(state.backends, fn {name, {backend_module, backend_state}} ->
        backend_module.cleanup(backend_state)
        {name, {backend_module, backend_state}}
      end)
      |> Map.new()

    schedule_cleanup()
    {:noreply, %{state | backends: new_backends}}
  end

  # Helper functions

  defp init_backend(cache_name, _opts) do
    config = get_backend_config(cache_name)
    backend_module = config[:backend]
    backend_opts = config[:backend_options] || []

    case backend_module.init(backend_opts) do
      {:ok, backend_state} ->
        {backend_module, backend_state}

      error ->
        # Fall back to memory backend on error
        IO.warn(
          "Failed to initialize #{inspect(backend_module)}: #{inspect(error)}. Falling back to memory backend."
        )

        fallback_module = Cache.MemoryBackend
        {:ok, fallback_state} = fallback_module.init(table_name: cache_name)
        {fallback_module, fallback_state}
    end
  end

  defp get_backend_config(cache_name) do
    # Get backend config from application config
    config = Application.get_env(:youvid, :cache_backends, %{})

    # Get specific config for this cache or use default
    cache_config = Map.get(config, cache_name, %{})

    # Set defaults if not configured
    Map.merge(
      %{
        backend: Cache.MemoryBackend,
        backend_options: [table_name: cache_name]
      },
      cache_config
    )
  end

  defp get_ttl do
    Application.get_env(:youvid, :cache_ttl, @default_ttl)
  end

  defp schedule_cleanup do
    # Run cleanup every hour by default, or use configured value
    interval = Application.get_env(:youvid, :cache_cleanup_interval, 3_600_000)
    Process.send_after(self(), :cleanup, interval)
  end
end
