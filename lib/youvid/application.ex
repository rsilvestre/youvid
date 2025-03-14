defmodule Youvid.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Ensure cache directories exist
    ensure_cache_directories()

    # Initialize cache configuration with the configured backends
    cache_config = Application.get_env(:youvid, :cache, [])

    children = [
      # Pass the app_name to allow YouCache to read configuration from :youvid app
      {Youvid.Cache, [app_name: :youvid] ++ cache_config}
    ]

    opts = [strategy: :one_for_one, name: Youvid.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Ensure all cache directories exist at application startup
  defp ensure_cache_directories do
    # Get cache backend configs
    cache_backends = Application.get_env(:youvid, :cache_backends, %{})

    # Extract unique cache directory paths
    cache_dirs =
      cache_backends
      |> Map.values()
      |> Enum.map(fn config ->
        backend_opts = config[:backend_options] || []
        Keyword.get(backend_opts, :cache_dir)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # Create each directory
    Enum.each(cache_dirs, fn dir ->
      # Create directory and log the result
      case File.mkdir_p(dir) do
        :ok ->
          IO.puts("Cache directory created: #{dir}")
        {:error, reason} ->
          IO.warn("Failed to create cache directory #{dir}: #{inspect(reason)}")
      end
    end)
  end
end
