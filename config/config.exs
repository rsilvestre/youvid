# In config/config.exs
import Config

config :youvid,
  # YouTube API Configuration
  # Replace with your own YouTube API key or use environment variable YOUTUBE_API_KEY
  # youtube_api_key: "YOUR_YOUTUBE_API_KEY_HERE",

  # General cache settings
  cache_ttl: 86_400_000,                    # TTL (time-to-live) - 1 day in milliseconds (default)
  cache_cleanup_interval: 3_600_000,        # Cleanup interval - every hour (default)

  # Configure which backend to use for cache
  cache_backends: %{
    # Video details cache (using memory backend)
    video_details: [
      backend: YouCache.Backend.Memory,
      backend_options: [
        max_size: 1000                       # Max entries in memory
      ]
    ]
  }

# For development, you can configure your API key here for convenience
# Make sure not to commit this file with your real API key
if Mix.env() == :dev do
  # uncomment and replace with your YouTube API key for local development
  config :youvid, youtube_api_key: "AIzaSyC363N6Ec655W0SvJ-fqZ0d16vcilDJkEE"
end

# For test environment, we use a dummy API key that will be mocked in tests
if Mix.env() == :test do
  config :youvid, youtube_api_key: "TEST_API_KEY"
end
