defmodule Youvid.Cache.CachexBackendTest do
  use ExUnit.Case, async: false

  alias Youvid.Cache.CachexBackend

  # Tests for the Cachex backend implementation
  @moduletag :cachex

  # Since testing Cachex properly would require a more complex setup with mocks,
  # we'll test the implementation directly with simple helpers that don't depend
  # on the actual Cachex implementation details

  # Create a test state that simulates what we would use with Cachex
  setup do
    state = %{cache: :mock_test_cache}
    {:ok, %{state: state}}
  end

  test "put formats video details correctly", %{state: state} do
    video_id = "test_video_id"
    video_details = %Youvid.VideoDetails{
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
    ttl = 10_000

    # Mock Cachex.put for this test
    :meck.new(Cachex, [:passthrough])

    :meck.expect(Cachex, :put, fn cache_name, key, value, opts ->
      assert cache_name == state.cache
      assert key == video_id
      assert value == video_details
      assert Keyword.get(opts, :ttl) == ttl
      {:ok, true}
    end)

    # Run the function
    result = CachexBackend.put(video_id, video_details, ttl, state)

    # Verify the result
    assert result == {:ok, state}

    # Clean up
    :meck.unload(Cachex)
  end

  test "get handles video details correctly", %{state: state} do
    video_id = "test_video_id"
    video_details = %Youvid.VideoDetails{
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

    # Test successful get
    :meck.new(Cachex, [:passthrough])

    :meck.expect(Cachex, :get, fn cache_name, key ->
      assert cache_name == state.cache
      assert key == video_id
      {:ok, video_details}
    end)

    result = CachexBackend.get(video_id, state)
    assert result == video_details
    assert result.title == "Test Video"
    assert result.view_count == 10000

    # Test nil result
    :meck.expect(Cachex, :get, fn _cache_name, _key -> {:ok, nil} end)
    result = CachexBackend.get(video_id, state)
    assert result == nil

    # Test error result
    :meck.expect(Cachex, :get, fn _cache_name, _key -> {:error, :some_error} end)
    result = CachexBackend.get(video_id, state)
    assert result == nil

    # Clean up
    :meck.unload(Cachex)
  end

  test "delete works correctly", %{state: state} do
    test_key = "test_key"

    # Mock Cachex.del
    :meck.new(Cachex, [:passthrough])

    :meck.expect(Cachex, :del, fn cache_name, key ->
      assert cache_name == state.cache
      assert key == test_key
      {:ok, 1}
    end)

    # Test the delete function
    result = CachexBackend.delete(test_key, state)
    assert result == :ok

    # Test error handling
    :meck.expect(Cachex, :del, fn _cache_name, _key -> {:error, :some_error} end)
    result = CachexBackend.delete(test_key, state)
    assert result == {:error, :some_error}

    # Clean up
    :meck.unload(Cachex)
  end

  test "clear works correctly", %{state: state} do
    # Mock Cachex.clear
    :meck.new(Cachex, [:passthrough])

    :meck.expect(Cachex, :clear, fn cache_name ->
      assert cache_name == state.cache
      {:ok, :cleared}
    end)

    # Test the clear function
    result = CachexBackend.clear(state)
    assert result == :ok

    # Test error handling
    :meck.expect(Cachex, :clear, fn _cache_name -> {:error, :some_error} end)
    result = CachexBackend.clear(state)
    assert result == {:error, :some_error}

    # Clean up
    :meck.unload(Cachex)
  end

  test "cleanup is a no-op", %{state: state} do
    result = CachexBackend.cleanup(state)
    assert result == :ok
  end

  # Init function testing is challenging due to mocking issues
  # For production use, we'll need to ensure the code is well-tested manually
end
