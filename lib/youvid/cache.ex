defmodule Youvid.Cache do
  @moduledoc """
  Provides caching functionality for video data to reduce API calls to YouTube.

  This module uses YouCache internally while maintaining the original API.
  """

  use YouCache,
    registries: [:video_details]

  use Youvid.Types

  alias Youvid.VideoDetails

  # Default TTL of 1 day in milliseconds
  @default_ttl 86_400_000

  # Public API

  @doc """
  Gets video details from cache or returns nil if not found.
  """
  @spec get_video_details(video_id) :: {:ok, VideoDetails.t()} | {:miss, nil} | {:error, term()}
  def get_video_details(video_id) do
    get(:video_details, video_id)
  end

  @doc """
  Caches video details for a video ID.
  """
  @spec put_video_details(video_id, {:ok, VideoDetails.t()}) :: {:ok, VideoDetails.t()}
  def put_video_details(video_id, {:ok, video_details} = data) do
    ttl = get_ttl()
    # Store just the details, not the full {:ok, details} tuple to match test expectations
    put(:video_details, video_id, video_details, ttl)
    data
  end

  # Helper function to maintain original behavior
  defp get_ttl do
    Application.get_env(:youvid, :cache_ttl, @default_ttl)
  end
end