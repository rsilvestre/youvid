defmodule Youvid.CacheTest do
  use ExUnit.Case
  alias Youvid.{Cache, VideoDetails}

  setup do
    # Start cache for testing or use existing
    case Process.whereis(Cache) do
      nil ->
        # Choose backend based on available dependencies (MemoryBackend or CachexBackend)
        backend =
          if Code.ensure_loaded?(Cachex) do
            Youvid.Cache.CachexBackend
          else
            Youvid.Cache.MemoryBackend
          end

        opts = [
          backends: %{
            video_details: %{
              backend: backend,
              backend_options: [table_name: :test_video_details]
            }
          }
        ]

        {:ok, _pid} = Cache.start_link(opts)

      _pid ->
        :ok
    end

    # Clear cache before each test
    Cache.clear()

    # Pass the backend type used to tests
    backend_type =
      if Code.ensure_loaded?(Cachex) do
        :cachex
      else
        :memory
      end
    {:ok, %{backend_type: backend_type}}
  end

  test "caches and retrieves video details" do
    video_id = "test_video_id"

    video_details = %VideoDetails{
      id: video_id,
      title: "Test Video",
      description: "This is a test description",
      channel_id: "UC123456789",
      channel_title: "Test Channel",
      published_at: "2023-01-01",
      duration: "600",
      view_count: 10000,
      like_count: 1000,
      comment_count: 100,
      thumbnail_url: "https://example.com/thumb.jpg",
      tags: ["test", "video"]
    }

    # Cache the video details
    Cache.put_video_details(video_id, {:ok, video_details})

    # Retrieve from cache
    case Cache.get_video_details(video_id) do
      {:ok, cached_details} ->
        assert cached_details == video_details

      other ->
        flunk("Expected {:ok, details}, got: #{inspect(other)}")
    end
  end

  test "returns {:miss, nil} for non-existent items" do
    assert Cache.get_video_details("non_existent_id") == {:miss, nil}
  end

  test "clear removes all cached items" do
    video_id = "test_video_id"

    video_details = %VideoDetails{
      id: video_id,
      title: "Test Video",
      description: "This is a test description",
      channel_id: "UC123456789",
      channel_title: "Test Channel",
      published_at: "2023-01-01",
      duration: "600",
      view_count: 10000,
      like_count: 1000,
      comment_count: 100,
      thumbnail_url: "https://example.com/thumb.jpg",
      tags: ["test", "video"]
    }

    Cache.put_video_details(video_id, {:ok, video_details})

    # Verify cache has the item
    case Cache.get_video_details(video_id) do
      {:ok, cached_details} ->
        assert cached_details == video_details

      other ->
        flunk("Expected {:ok, details}, got: #{inspect(other)}")
    end

    # Clear cache
    Cache.clear()

    # Verify item is gone
    assert Cache.get_video_details(video_id) == {:miss, nil}
  end

  @tag :cachex
  test "runs with Cachex backend if available", %{backend_type: backend_type} do
    # Skip if Cachex is not available
    if backend_type != :cachex do
      # Just return early from the test if Cachex isn't available
      IO.puts("Skipping Cachex test - Cachex not available")
      assert true
    else
      # This test verifies that the code can run using the Cachex backend
      # by storing and retrieving a value
      video_id = "cachex_test_video"

      video_details = %VideoDetails{
        id: video_id,
        title: "Test Video",
        description: "This is a test description",
        channel_id: "UC123456789",
        channel_title: "Test Channel",
        published_at: "2023-01-01",
        duration: "600",
        view_count: 10000,
        like_count: 1000,
        comment_count: 100,
        thumbnail_url: "https://example.com/thumb.jpg",
        tags: ["test", "video"]
      }

      # Cache the video details
      Cache.put_video_details(video_id, {:ok, video_details})

      # Retrieve from cache
      case Cache.get_video_details(video_id) do
        {:ok, cached_details} ->
          assert cached_details == video_details

        other ->
          flunk("Expected {:ok, details}, got: #{inspect(other)}")
      end
    end
  end
end
