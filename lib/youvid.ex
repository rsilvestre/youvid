defmodule Youvid do
  @moduledoc """
  Main module with functions to retrieve video details and transcriptions.
  """

  use Youvid.Types

  alias Youvid.{Cache, Video, VideoDetails}
  alias Youvid.VideoDetails.Fetch, as: VideoDetailsFetch

  @doc """
  Starts the Youvid application with caching enabled.
  Call this function when you want to use caching for transcripts outside
  of a supervision tree.

  ## Options

  * `:backends` - A map of cache backend configurations (optional)
  * `:ttl` - Cache TTL in milliseconds (optional)

  ## Examples

      # Start with default memory backend
      Youvid.start()

      # Start with custom configuration
      Youvid.start(backends: %{
        transcript_lists: %{
          backend: Youvid.Cache.DiskBackend,
          backend_options: [cache_dir: "my_cache_dir"]
        }
      })
  """
  def start(opts \\ []) do
    # If specific backends are provided, update application env
    if backend_config = Keyword.get(opts, :backends) do
      Application.put_env(:youvid, :cache_backends, backend_config)
    end

    # If TTL is provided, update application env
    if ttl = Keyword.get(opts, :ttl) do
      Application.put_env(:youvid, :cache_ttl, ttl)
    end

    Cache.start_link(Keyword.get(opts, :cache_opts, []))
  end

  @doc """
  Gets details for a YouTube video.
  Returns a VideoDetails struct with information about the video.
  """
  @spec get_video_details(video_id) :: video_details_found | error
  def get_video_details(video_id) do
    case use_cache?() && Cache.get_video_details(video_id) do
      {:miss, nil} ->
        # Not in cache, fetch and cache it
        fetch_and_cache_video_details(video_id)

      {:ok, result} ->
        {:ok, result}

      {:error, _reason} = error ->
        error

      _other ->
        # Fallback for unexpected responses
        fetch_and_cache_video_details(video_id)
    end
  end

  defp fetch_and_cache_video_details(video_id) do
    result =
      video_id
      |> Video.new()
      |> VideoDetailsFetch.video_details()

    case result do
      {:ok, _} = ok_result ->
        if use_cache?(), do: Cache.put_video_details(video_id, ok_result)
        ok_result

      error ->
        error
    end
  end

  @doc """
  Gets details for a YouTube video.
  Like `get_video_details/1` but raises an exception on error.
  """
  @spec get_video_details!(video_id) :: VideoDetails.t()
  def get_video_details!(video_id) do
    case get_video_details(video_id) do
      {:ok, video_details} -> video_details
      {:error, reason} -> raise RuntimeError, message: to_string(reason)
    end
  end

  @doc """
  Clears all cached data including transcripts and video details.
  """
  def clear_cache do
    if use_cache?() do
      Cache.clear()
    else
      {:error, :cache_not_started}
    end
  end

  @doc """
  Checks if caching is enabled.
  """
  def use_cache? do
    case Process.whereis(Cache) do
      nil -> false
      _pid -> true
    end
  end
end
