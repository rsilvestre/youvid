defmodule Youvid.VideoDetails.Fetch do
  @moduledoc false

  use Youvid.Types

  alias Youvid.HttpClient
  alias Youvid.VideoDetails

  @youtube_api_base_url "https://content-youtube.googleapis.com/youtube/v3/videos"
  @api_parts "contentDetails,id,liveStreamingDetails,localizations,player,recordingDetails,snippet,statistics,status,topicDetails"

  @spec video_details(video) :: video_details_found | error
  def video_details(video) do
    video.id
    |> build_api_url()
    |> fetch_from_api()
    |> parse_response()
  end

  defp build_api_url(video_id) do
    api_key = get_api_key()
    "#{@youtube_api_base_url}?id=#{video_id}&part=#{@api_parts}&key=#{api_key}"
  end

  defp get_api_key do
    System.get_env("YOUTUBE_API_KEY") || 
      Application.get_env(:youvid, :youtube_api_key) ||
      raise "YouTube API key not found. Please set the YOUTUBE_API_KEY environment variable or configure it in your application config."
  end

  defp fetch_from_api(url) do
    HttpClient.get(url)
  end

  defp parse_response({:ok, json_body}) do
    case Poison.decode(json_body) do
      {:ok, %{"items" => [item | _]}} ->
        {:ok, VideoDetails.new(process_api_item(item))}
        
      {:ok, %{"items" => []}} ->
        {:error, :not_found}
        
      {:ok, %{"error" => %{"message" => message}}} ->
        {:error, message}
        
      {:error, _} ->
        {:error, :parse_error}
        
      _ ->
        {:error, :unknown_error}
    end
  end

  defp parse_response({:error, reason}), do: {:error, reason}

  # Process the API response to extract the fields we need
  defp process_api_item(item) do
    snippet = Map.get(item, "snippet", %{})
    statistics = Map.get(item, "statistics", %{})
    content_details = Map.get(item, "contentDetails", %{})
    
    %{
      "videoId" => item["id"],
      "title" => snippet["title"] || "",
      "shortDescription" => snippet["description"] || "",
      "channelId" => snippet["channelId"] || "",
      "author" => snippet["channelTitle"] || "",
      "publishDate" => snippet["publishedAt"] || "",
      "lengthSeconds" => duration_to_seconds(content_details["duration"] || "PT0S"),
      "viewCount" => statistics["viewCount"] || "0",
      "likes" => statistics["likeCount"] || "0",
      "commentCount" => statistics["commentCount"] || "0",
      "thumbnail" => get_thumbnails(snippet),
      "keywords" => snippet["tags"] || []
    }
  end

  # Convert ISO 8601 duration format (PT1H23M45S) to seconds
  defp duration_to_seconds(duration) do
    # Extract hours, minutes, seconds from the format
    hours = extract_duration_part(duration, "H")
    minutes = extract_duration_part(duration, "M")
    seconds = extract_duration_part(duration, "S")
    
    # Convert to total seconds
    (hours * 3600 + minutes * 60 + seconds) |> to_string()
  end

  defp extract_duration_part(duration, part) do
    case Regex.run(~r/(\d+)#{part}/, duration) do
      [_, value] -> String.to_integer(value)
      _ -> 0
    end
  end

  defp get_thumbnails(%{"thumbnails" => thumbnails}) when is_map(thumbnails) do
    # Extract the highest quality available
    # Order of preference: maxres, high, medium, standard, default
    thumbnail_url = 
      cond do
        Map.has_key?(thumbnails, "maxres") -> thumbnails["maxres"]["url"]
        Map.has_key?(thumbnails, "high") -> thumbnails["high"]["url"]
        Map.has_key?(thumbnails, "medium") -> thumbnails["medium"]["url"]
        Map.has_key?(thumbnails, "standard") -> thumbnails["standard"]["url"]
        Map.has_key?(thumbnails, "default") -> thumbnails["default"]["url"]
        true -> ""
      end
      
    %{"thumbnails" => [%{"url" => thumbnail_url}]}
  end
  
  defp get_thumbnails(_), do: %{"thumbnails" => [%{"url" => ""}]}
end
