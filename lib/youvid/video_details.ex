defmodule Youvid.VideoDetails do
  @moduledoc """
  Module representing details of a YouTube video.

  This module provides a struct and functions for working with YouTube video metadata
  retrieved from the YouTube Data API.
  """

  use Youvid.Types
  use TypedStruct

  typedstruct enforce: true do
    field :id, video_id
    field :title, String.t()
    field :description, String.t()
    field :channel_id, String.t()
    field :channel_title, String.t()
    field :published_at, String.t()
    field :duration, String.t()
    field :view_count, integer()
    field :like_count, integer(), default: 0
    field :comment_count, integer(), default: 0
    field :thumbnail_url, String.t()
    field :tags, list(String.t()), default: []
    # Additional fields from API
    field :privacy_status, String.t(), default: "unknown"
    field :definition, String.t(), default: "unknown" # hd or sd
    field :category_id, String.t(), default: ""
  end

  @doc """
  Creates a new VideoDetails struct from the parsed video details JSON.

  This function handles mapping from either the YouTube Data API response
  or a parsed video details object to a consistently structured VideoDetails struct.
  """
  def new(video_details) do
    %__MODULE__{
      id: Map.get(video_details, "videoId", ""),
      title: Map.get(video_details, "title", ""),
      description: Map.get(video_details, "shortDescription", ""),
      channel_id: Map.get(video_details, "channelId", ""),
      channel_title: Map.get(video_details, "author", ""),
      published_at: Map.get(video_details, "publishDate", ""),
      duration: Map.get(video_details, "lengthSeconds", ""),
      view_count: parse_integer(Map.get(video_details, "viewCount", "0")),
      like_count: parse_integer(Map.get(video_details, "likes", "0")),
      comment_count: parse_integer(Map.get(video_details, "commentCount", "0")),
      thumbnail_url: get_thumbnail_url(video_details),
      tags: Map.get(video_details, "keywords", []),
      privacy_status: Map.get(video_details, "privacyStatus", "unknown"),
      definition: Map.get(video_details, "definition", "unknown"),
      category_id: Map.get(video_details, "categoryId", "")
    }
  end

  @doc """
  Formats the duration as a human-readable string (HH:MM:SS).

  ## Examples

      iex> video_details = %Youvid.VideoDetails{duration: "3665"}
      iex> Youvid.VideoDetails.format_duration(video_details)
      "01:01:05"

      iex> video_details = %Youvid.VideoDetails{duration: "63"}
      iex> Youvid.VideoDetails.format_duration(video_details)
      "01:03"
  """
  def format_duration(%__MODULE__{duration: duration}) do
    seconds = String.to_integer(duration)
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    remaining_seconds = rem(seconds, 60)

    if hours > 0 do
      :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, remaining_seconds])
      |> to_string()
    else
      :io_lib.format("~2..0B:~2..0B", [minutes, remaining_seconds])
      |> to_string()
    end
  end

  @doc """
  Formats the view count as a human-readable string with K, M, or B suffixes.

  ## Examples

      iex> video_details = %Youvid.VideoDetails{view_count: 1250000}
      iex> Youvid.VideoDetails.format_view_count(video_details)
      "1.25M"

      iex> video_details = %Youvid.VideoDetails{view_count: 8500}
      iex> Youvid.VideoDetails.format_view_count(video_details)
      "8.5K"
  """
  def format_view_count(%__MODULE__{view_count: count}) when count >= 1_000_000_000 do
    "#{Float.round(count / 1_000_000_000, 1)}B"
  end

  def format_view_count(%__MODULE__{view_count: count}) when count >= 1_000_000 do
    "#{Float.round(count / 1_000_000, 1)}M"
  end

  def format_view_count(%__MODULE__{view_count: count}) when count >= 1_000 do
    "#{Float.round(count / 1_000, 1)}K"
  end

  def format_view_count(%__MODULE__{view_count: count}) do
    "#{count}"
  end

  @doc """
  Formats the publish date in a more readable format.

  ## Example

      iex> video_details = %Youvid.VideoDetails{published_at: "2023-01-15T14:30:45Z"}
      iex> Youvid.VideoDetails.format_date(video_details)
      "Jan 15, 2023"
  """
  def format_date(%__MODULE__{published_at: date_string}) do
    case DateTime.from_iso8601(date_string) do
      {:ok, date_time, _} ->
        Calendar.strftime(date_time, "%b %d, %Y")
      _ ->
        date_string
    end
  end

  # Private helper functions

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: 0

  defp get_thumbnail_url(video_details) do
    case Map.get(video_details, "thumbnail", %{}) do
      %{"thumbnails" => [%{"url" => url} | _]} -> url
      _ -> ""
    end
  end
end
