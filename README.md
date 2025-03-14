# Youvid [![Build Status](https://github.com/patrykwozinski/youvid/workflows/CI/badge.svg)](https://github.com/patrykwozinski/youvid/actions) [![Hex pm](https://img.shields.io/hexpm/v/youvid.svg?style=flat)](https://hex.pm/packages/youvid)

A tool to retrieve video details from Youtube. Youvid allows you to easily fetch video metadata (title, views, likes, channel info, etc.) from YouTube videos using the official YouTube Data API.

## Installation

Add `youvid` to the list of dependencies inside `mix.exs`:

```elixir
def deps do
  [
    {:youvid, "~> 0.1.0"}
  ]
end
```

This package requires Elixir 1.15 or later and has the following dependencies:
- poison ~> 6.0 (JSON parsing)
- httpoison ~> 2.2 (HTTP client)
- typed_struct ~> 0.3 (Type definitions)
- nimble_options ~> 1.0 (Option validation)

## YouTube API Key Setup

Youvid uses the official YouTube Data API to fetch video details. You'll need to obtain an API key from the Google Cloud Console by following these steps:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the "YouTube Data API v3" for your project
4. Create an API key in the "Credentials" section
5. Set up the API key in one of the following ways:

### Environment Variable (recommended)

```bash
export YOUTUBE_API_KEY=your_api_key_here
```

### Application Configuration

```elixir
# In config/config.exs
config :youvid, 
  youtube_api_key: "your_api_key_here"
```

**Note**: Be careful not to commit your API key to version control. Consider using environment variables or a secrets management solution in production.

## Usage

### Get Video Details

**Youvid.get_video_details(video_id)**

Retrieves detailed information about a YouTube video.

```elixir
Youvid.get_video_details("lxYFOM3UJzo")

{:ok,
 %Youvid.VideoDetails{
   id: "lxYFOM3UJzo",
   title: "Elixir: The Documentary",
   description: "This documentary explores the origins of Elixir...",
   channel_id: "UCzBc...",
   channel_title: "Honeypot",
   published_at: "2020-11-18",
   duration: "1614",
   view_count: 250000,
   like_count: 15000,
   comment_count: 500,
   thumbnail_url: "https://i.ytimg.com/vi/lxYFOM3UJzo/hqdefault.jpg",
   tags: ["elixir", "programming", "erlang", "documentary"]
 }}
```

### Error Handling

All functions return either:
- `{:ok, result}` for successful operations
- `{:error, reason}` when something goes wrong (typically `:not_found`)

### Bang Functions

If you don't need to pattern match `{:ok, data}` and `{:error, reason}`, there is also a [trailing bang](https://hexdocs.pm/elixir/naming-conventions.html#trailing-bang-foo) version that raises an exception on error:

```elixir
# Returns the video details directly or raises an exception
video_details = Youvid.get_video_details!("lxYFOM3UJzo")
```

## Caching

Youvid includes a flexible caching mechanism to improve performance and reduce API calls to YouTube. 
The cache system supports multiple backend options:

- **Memory**: In-memory cache using ETS tables (default, fast but not persistent)
- **Disk**: Persistent local storage using DETS (survives application restarts)
- **S3**: Cloud storage using AWS S3 (survives restarts and shareable across instances)
- **Cachex**: Distributed caching using Cachex (supports horizontal scaling across multiple nodes)

### Using Caching

If using Youvid as an application (included in your supervision tree), caching is automatically enabled. Otherwise, you need to manually start the cache:

```elixir
# Start cache
Youvid.start()
```

### Important Note for Disk Cache

When using the disk cache backend, you must ensure the cache directory exists before starting the application:

```bash
# Create the cache directory structure if it doesn't exist
mkdir -p priv/youvid_cache
```

For production deployments, this directory should be:
1. Created as part of your deployment process
2. Have proper file permissions for the user running the application
3. Be part of your release, but excluded from version control (add to .gitignore)

### Cache Configuration

You can configure cache behavior in your config:

```elixir
# In config/config.exs
config :youvid, 
  # General cache settings
  cache_ttl: 86_400_000,                    # TTL (time-to-live) - 1 day in milliseconds (default)
  cache_cleanup_interval: 3_600_000,        # Cleanup interval - every hour (default)
  
  # Configure which backend to use for the video details cache
  cache_backends: %{
    # Memory backend (default)
    video_details: %{
      backend: Youvid.Cache.MemoryBackend,
      backend_options: [
        table_name: :video_details_cache,
        max_size: 1000                       # Max entries in memory
      ]
    }
  }
  
  # You can also use disk backend for persistence
  cache_backends: %{
    video_details: %{
      backend: Youvid.Cache.DiskBackend,
      backend_options: [
        table_name: :video_details_cache, 
        cache_dir: "priv/youvid_cache",      # Directory for cache files
        max_size: 10000                      # Max entries on disk
      ]
    }
  }
```

All cache backend options are validated using NimbleOptions, providing:

1. Strong type checking and validation of configuration values
2. Comprehensive error messages for misconfiguration
3. Self-documented options with defaults

For example, if you provide an invalid value like a negative max_size:

```elixir
backend_options: [max_size: -100]  # Invalid negative value
```

You'll receive a helpful error message:
```
"expected a positive integer, got: -100"
```

#### Using S3 Backend

To use the S3 backend, you must add the following optional dependencies to your mix.exs:

```elixir
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.4"},
{:sweet_xml, "~> 0.7"},
{:configparser_ex, "~> 4.0", optional: true}
```

Then configure the backend:

```elixir
config :youvid, 
  cache_backends: %{
    transcript_lists: %{
      backend: Youvid.Cache.S3Backend,
      backend_options: [
        bucket: "youvid-cache",              # S3 bucket name
        prefix: "transcripts",               # Prefix for objects
        region: "us-east-1"                  # AWS region
      ]
    },
    video_details: %{
      backend: Youvid.Cache.S3Backend,
      backend_options: [
        bucket: "youvid-cache",              # S3 bucket name
        prefix: "video-details",             # Prefix for objects
        region: "us-east-1"                  # AWS region
      ]
    }
  }
```

#### Using Cachex Backend for Distributed Caching

For applications with horizontal scaling, the Cachex backend provides distributed caching across multiple nodes. To use it, add the following optional dependency to your mix.exs:

```elixir
{:cachex, "~> 3.6"}
```

Then configure the backend:

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

To use distributed caching, you need to connect your Elixir nodes in a cluster. For example:

```elixir
# On node1@example.com
Node.connect(:"node2@example.com")

# On node2@example.com
Node.connect(:"node1@example.com") 
```

In a production environment, you would typically use a library like [libcluster](https://github.com/bitwalker/libcluster) to handle node discovery and connection automatically.

#### AWS Credentials for S3 Backend

When using the S3 backend, you need to provide AWS credentials in one of the following ways:

1. **Environment variables**:
   ```
   AWS_ACCESS_KEY_ID=your_key
   AWS_SECRET_ACCESS_KEY=your_secret
   ```

2. **AWS credentials file** at `~/.aws/credentials`:
   ```
   [default]
   aws_access_key_id = your_key
   aws_secret_access_key = your_secret
   ```

3. **Application config**:
   ```elixir
   # In config/config.exs
   config :ex_aws,
     access_key_id: "your_key",
     secret_access_key: "your_secret",
     region: "your-region"
   ```

ExAws automatically checks these locations in order. See the [ExAws documentation](https://github.com/ex-aws/ex_aws) for more configuration options.

### Cache Operations

```elixir
# Check if cache is enabled
Youvid.use_cache?()

# Clear cache
Youvid.clear_cache()
```

When caching is enabled, video details are stored with a TTL (time-to-live). The cache is automatically cleaned up periodically to prevent storage issues.

## Data Structure

### Youvid.VideoDetails

The video details structure containing:
- `id`: YouTube video ID
- `title`: Video title
- `description`: Video description
- `channel_id`: ID of the channel that uploaded the video
- `channel_title`: Name of the channel that uploaded the video
- `published_at`: Publication date of the video (ISO 8601 format)
- `duration`: Duration of the video in seconds
- `view_count`: Number of views
- `like_count`: Number of likes
- `comment_count`: Number of comments
- `thumbnail_url`: URL to the video thumbnail
- `tags`: List of tags/keywords associated with the video
- `privacy_status`: Privacy setting of the video (public, unlisted, or private)
- `definition`: Video quality (hd or sd)
- `category_id`: YouTube category ID for the video

**Helper Functions:**
- `format_duration/1`: Formats seconds as "HH:MM:SS" or "MM:SS"
- `format_view_count/1`: Formats view count with K/M/B suffixes
- `format_date/1`: Formats ISO date as human-readable text

## Examples

### Fetching and Displaying Video Details

```elixir
# Get video details and display information using formatting helpers
defmodule VideoProcessor do
  def print_video_summary(video_id) do
    case Youvid.get_video_details(video_id) do
      {:ok, details} ->
        """
        Title: #{details.title}
        Channel: #{details.channel_title}
        Published: #{Youvid.VideoDetails.format_date(details)}
        Duration: #{Youvid.VideoDetails.format_duration(details)}
        Views: #{Youvid.VideoDetails.format_view_count(details)}
        Likes: #{details.like_count}
        Privacy: #{details.privacy_status}
        Definition: #{details.definition}
        Category ID: #{details.category_id}
        """
      
      {:error, reason} -> 
        "Error: #{reason}"
    end
  end
end

# Usage:
summary = VideoProcessor.print_video_summary("lxYFOM3UJzo")
IO.puts(summary)
```

### Creating Video Cards for a Website

```elixir
defmodule VideoCardGenerator do
  def generate_html(video_id) do
    case Youvid.get_video_details(video_id) do
      {:ok, details} ->
        """
        <div class="video-card">
          <div class="thumbnail">
            <img src="#{details.thumbnail_url}" alt="#{details.title}">
            <span class="duration">#{format_duration(details.duration)}</span>
          </div>
          <div class="video-info">
            <h3 class="title">#{details.title}</h3>
            <div class="channel">#{details.channel_title}</div>
            <div class="stats">
              <span class="views">#{format_count(details.view_count)} views</span>
              <span class="published">#{format_date(details.published_at)}</span>
            </div>
          </div>
        </div>
        """
      
      {:error, reason} -> 
        "<div class='error'>Failed to load video: #{reason}</div>"
    end
  end
  
  defp format_count(count) when count >= 1_000_000 do
    "#{Float.round(count / 1_000_000, 1)}M"
  end
  
  defp format_count(count) when count >= 1_000 do
    "#{Float.round(count / 1_000, 1)}K"
  end
  
  defp format_count(count), do: to_string(count)
  
  defp format_duration(seconds) do
    seconds = String.to_integer(seconds)
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)
    
    if hours > 0 do
      "#{hours}:#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    else
      "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    end
  end
  
  defp format_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> Calendar.strftime(date, "%b %d, %Y")
      _ -> date_string
    end
  end
end

# Usage:
html = VideoCardGenerator.generate_html("lxYFOM3UJzo")
```

## Requirements

- Elixir ~> 1.15

## Troubleshooting

### Common Issues

1. **API Key Not Found**
   ```
   ** (RuntimeError) YouTube API key not found. Please set the YOUTUBE_API_KEY environment variable or configure it in your application config.
   ```
   This happens when:
   - You haven't set the YouTube API key as described in the setup section
   - The environment variable is not accessible to the application
   
2. **Video Details Not Found**
   ```
   {:error, :not_found}
   ```
   This can happen when:
   - The video ID is incorrect
   - The video doesn't exist or has been deleted
   - The video is private or unlisted
   
3. **Network Errors**
   If you're experiencing network issues, ensure you have a working internet connection. The library depends on HTTPoison for making requests to YouTube.
   
4. **API Quota Exceeded**
   ```
   {:error, "The request cannot be completed because you have exceeded your quota."}
   ```
   The YouTube Data API has a daily quota limit. If you exceed this limit, you'll need to:
   - Wait until your quota resets (usually 24 hours)
   - Apply for a quota increase from Google
   - Enable caching in your application to reduce API calls

### Limitations

- This library cannot access private or unlisted videos that require authentication
- YouTube API quotas apply (free tier allows for a limited number of requests per day)
- Some information might not be available through the API due to privacy settings
- API responses might change over time as YouTube updates their service

### Distributed Caching Considerations

When using the CachexBackend for horizontal scaling:

1. **Node Connectivity**: Ensure all nodes can communicate with each other through proper network configuration
2. **Node Discovery**: Use a library like [libcluster](https://github.com/bitwalker/libcluster) for reliable node discovery and connection
3. **Cache Consistency**: Be aware that there can be a short delay before cache updates propagate to all nodes
4. **Node Naming**: Nodes must have proper names (not anonymous) - use `--name node1@ip` or `--sname node1` when starting your application
5. **Cookie Configuration**: All nodes must share the same Erlang cookie for security

## Production Deployment

When deploying Youvid in a production environment, you need to take additional steps to ensure the cache system works correctly:

### Using Releases

Using Elixir releases is recommended for production deployments:

```bash
# Generate a release
MIX_ENV=prod mix release

# Run the release
_build/prod/rel/youvid/bin/youvid start
```

### Directory Structure

For disk caching to work in production with releases:

1. Create the `priv/youvid_cache` directory before starting the application:

```bash
# Create required directories in your production environment
mkdir -p /app/priv/youvid_cache
chmod 755 /app/priv/youvid_cache
```

2. Update your release configuration in `mix.exs` to include the `priv` directory:

```elixir
def project do
  [
    # ...
    releases: [
      youvid: [
        include_erts: true,
        include_executables_for: [:unix],
        applications: [
          youvid: :permanent
        ],
        # Copy priv directory to the release
        steps: [:assemble, :tar]
      ]
    ],
    # ...
  ]
end
```

### Runtime Configuration

Create a `config/releases.exs` file for runtime configuration:

```elixir
import Config

# Configure cache backends for production
config :youvid,
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

# For containerized deployments, you might want to use environment variables
if System.get_env("CACHE_DIR") do
  config :youvid,
    cache_backends: %{
      video_details: %{
        backend: Youvid.Cache.DiskBackend,
        backend_options: [
          table_name: :video_details_cache,
          cache_dir: System.get_env("CACHE_DIR", "/app/priv/youvid_cache"),
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
```

### Docker Deployment

If using Docker, ensure your Dockerfile includes steps to create the cache directory:

```dockerfile
FROM elixir:1.14-alpine AS build

# Build application...

FROM alpine:3.18 AS app

# Copy release from build stage...

# Create cache directory and set permissions
RUN mkdir -p /app/priv/youvid_cache && \
    chmod 755 /app/priv/youvid_cache

# Set working directory and run the release
WORKDIR /app
CMD ["bin/youvid", "start"]
```

### Kubernetes Deployment

When deploying to Kubernetes, use a persistent volume for the cache directory:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: youvid-cache-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: youvid
spec:
  replicas: 1
  selector:
    matchLabels:
      app: youvid
  template:
    metadata:
      labels:
        app: youvid
    spec:
      containers:
      - name: youvid
        image: your-registry/youvid:latest
        env:
        - name: CACHE_DIR
          value: "/app/priv/youvid_cache"
        volumeMounts:
        - name: cache-volume
          mountPath: /app/priv/youvid_cache
      volumes:
      - name: cache-volume
        persistentVolumeClaim:
          claimName: youvid-cache-pvc
```

## Future Improvements

Below is a list of potential improvements for the project:

### Cache System
- [ ] Implement proper supervision tree for cache components
- [ ] Add circuit breaker pattern for external backends
- [ ] Integrate Telemetry for cache metrics (hits, misses, performance)
- [ ] Enhance distributed cache consistency guarantees
- [ ] Implement exponential backoff for S3 operations

### Testing
- [ ] Add integration tests for distributed caching with multiple nodes
- [ ] Implement property-based testing using StreamData
- [ ] Create comprehensive tests for S3 backend
- [ ] Use ExVCR to mock HTTP requests for YouTube API
- [ ] Add mocks for YouTube HTML responses to enable reliable testing

### Error Handling
- [ ] Replace generic error atoms with structured error types
- [ ] Implement cascading fallback strategies
- [ ] Add structured logging with context for debugging
- [ ] Introduce configurable timeouts for HTTP client
- [ ] Add fallback strategies for when the HTML structure changes

### Video Details Features
- [x] Add video details extraction using YouTube Data API
- [ ] Add more detailed video statistics
- [ ] Expose video privacy status (public, unlisted, private)
- [ ] Expose video category and genre information
- [ ] Provide thumbnail options in multiple resolutions
- [ ] Support for retrieving related/recommended videos
- [ ] Add comprehensive channel information extraction
- [ ] Implement playlist details extraction
- [ ] Add date formatting helpers for published_at field
- [ ] Add duration formatting helpers (HH:MM:SS)
- [ ] Expose video chapters/segments if available
- [ ] Add support for retrieving comments (top comments)
- [ ] Add detailed parsing for livestream metadata
- [ ] Support for videos with multiple audio tracks or captions
- [ ] Add video availability checking and status monitoring

### API Resilience
- [x] Use official YouTube Data API instead of HTML scraping
- [ ] Implement exponential backoff for rate limits
- [ ] Add API quota management and monitoring
- [ ] Support authenticated YouTube API access
- [ ] Add fallback mechanisms for API failures
- [ ] Support for API key rotation
- [ ] Implement API response caching strategies
- [ ] Add detailed API error handling and reporting

### Performance
- [ ] Use streams for processing large responses
- [ ] Optimize cache serialization with more efficient protocols
- [ ] Implement connection pooling for HTTP requests
- [ ] Add lazy loading for heavy data fields
- [ ] Implement selective field retrieval to reduce parsing overhead

### Modern Practices
- [x] Use NimbleOptions for option validation
- [ ] Reorganize modules around domain concepts
- [ ] Add LiveBook examples for interactive documentation
- [ ] Implement runtime configuration validation
- [ ] Add telemetry instrumentation for monitoring

## License

Youvid is released under the MIT License. See the LICENSE file for details.

