import Config

# Configure for production environment

# YouTube API Key - Get from environment variable in production
# Either set this in your deployment environment or through a secrets management system
if youtube_api_key = System.get_env("YOUTUBE_API_KEY") do
  config :youvid, youtube_api_key: youtube_api_key
else
  # Optional: Warn if API key is not set in production
  IO.warn("WARNING: YOUTUBE_API_KEY environment variable not set. YouTube API requests will fail.")
end

# Configure cache backends for production
config :youvid,
  # General cache settings
  cache_ttl: 86_400_000,                    # TTL (time-to-live) - 1 day in milliseconds (default)
  cache_cleanup_interval: 3_600_000,        # Cleanup interval - every hour (default)

  # Configure disk cache for production
  cache_backends: %{
    video_details: %{
      backend: Youvid.Cache.DiskBackend,
      backend_options: [
        table_name: :video_details_cache,
        # Use absolute path in production
        cache_dir: "/app/priv/youvid_cache",
        max_size: 10000
      ]
    }
  }

# Allow overriding cache directory via environment variable
if cache_dir = System.get_env("CACHE_DIR") do
  config :youvid,
    cache_backends: %{
      video_details: %{
        backend: Youvid.Cache.DiskBackend,
        backend_options: [
          table_name: :video_details_cache,
          cache_dir: cache_dir,
          max_size: String.to_integer(System.get_env("CACHE_MAX_SIZE", "10000"))
        ]
      }
    }
end

# For distributed deployments with Cachex
if System.get_env("USE_DISTRIBUTED_CACHE") == "true" do
  config :youvid,
    cache_backends: %{
      video_details: %{
        backend: Youvid.Cache.CachexBackend,
        backend_options: [
          table_name: :video_details_cache,
          distributed: true
        ]
      }
    }
end

# Additional runtime configuration options
if System.get_env("API_REQUEST_TIMEOUT") do
  config :youvid, api_request_timeout: String.to_integer(System.get_env("API_REQUEST_TIMEOUT"))
end

# Set API rate limiting options (to prevent quota exhaustion)
if System.get_env("ENABLE_API_RATE_LIMIT") == "true" do
  config :youvid,
    enable_api_rate_limit: true,
    api_max_requests_per_day: String.to_integer(System.get_env("API_MAX_REQUESTS_PER_DAY", "1000"))
end
