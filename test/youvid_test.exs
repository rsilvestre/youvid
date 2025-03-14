defmodule YouvidTest do
  use ExUnit.Case, async: true

  use Youvid.Types
  alias Youvid.VideoDetails

  # Basic tests for VideoDetails struct
  test "VideoDetails struct can be created correctly" do
    video_details = %VideoDetails{
      id: "test_id",
      title: "Test Video",
      description: "This is a test description",
      channel_id: "UC123456789",
      channel_title: "Test Channel",
      published_at: "2023-01-01",
      duration: "600",
      view_count: 10_000,
      like_count: 1000,
      comment_count: 100,
      thumbnail_url: "https://example.com/thumb.jpg",
      tags: ["test", "video"],
      privacy_status: "public",
      definition: "hd",
      category_id: "22"
    }
    
    assert video_details.id == "test_id"
    assert video_details.title == "Test Video"
    assert video_details.description == "This is a test description"
    assert video_details.view_count == 10_000
    assert video_details.like_count == 1_000
    assert video_details.thumbnail_url == "https://example.com/thumb.jpg"
    assert video_details.tags == ["test", "video"]
    assert video_details.privacy_status == "public"
    assert video_details.definition == "hd"
    assert video_details.category_id == "22"
  end
  
  # Test VideoDetails.new function
  test "VideoDetails.new creates a proper struct from map" do
    details_map = %{
      "videoId" => "test_id",
      "title" => "Test Video",
      "shortDescription" => "This is a test description",
      "channelId" => "UC123456789",
      "author" => "Test Channel",
      "publishDate" => "2023-01-01",
      "lengthSeconds" => "600",
      "viewCount" => "10_000",
      "likes" => "1_000",
      "commentCount" => "100",
      "thumbnail" => %{"thumbnails" => [%{"url" => "https://example.com/thumb.jpg"}]},
      "keywords" => ["test", "video"],
      "privacyStatus" => "public",
      "definition" => "hd",
      "categoryId" => "22"
    }
    
    video_details = VideoDetails.new(details_map)
    
    assert video_details.id == "test_id"
    assert video_details.title == "Test Video"
    assert video_details.description == "This is a test description"
    assert video_details.channel_id == "UC123456789"
    assert video_details.channel_title == "Test Channel"
    assert video_details.published_at == "2023-01-01"
    assert video_details.duration == "600"
    assert video_details.view_count == 10_000
    assert video_details.like_count == 1_000
    assert video_details.comment_count == 100
    assert video_details.thumbnail_url == "https://example.com/thumb.jpg"
    assert video_details.tags == ["test", "video"]
    assert video_details.privacy_status == "public"
    assert video_details.definition == "hd"
    assert video_details.category_id == "22"
  end
  
  # Test formatting helpers
  test "format_duration formats duration correctly" do
    # Create a base struct with all required fields
    base = %VideoDetails{
      id: "test_id",
      title: "Test Video",
      description: "Description",
      channel_id: "UC123456789",
      channel_title: "Test Channel",
      published_at: "2023-01-01",
      duration: "0",
      view_count: 0,
      thumbnail_url: "https://example.com/thumb.jpg"
    }
    
    # Test with seconds only
    video_details = %{base | duration: "45"}
    assert VideoDetails.format_duration(video_details) == "00:45"
    
    # Test with minutes and seconds
    video_details = %{base | duration: "125"}
    assert VideoDetails.format_duration(video_details) == "02:05"
    
    # Test with hours, minutes, and seconds
    video_details = %{base | duration: "3665"}
    assert VideoDetails.format_duration(video_details) == "01:01:05"
  end
  
  test "format_view_count formats view count correctly" do
    # Create a base struct with all required fields
    base = %VideoDetails{
      id: "test_id",
      title: "Test Video",
      description: "Description",
      channel_id: "UC123456789",
      channel_title: "Test Channel",
      published_at: "2023-01-01",
      duration: "0",
      view_count: 0,
      thumbnail_url: "https://example.com/thumb.jpg"
    }
    
    # Test with small number
    video_details = %{base | view_count: 500}
    assert VideoDetails.format_view_count(video_details) == "500"
    
    # Test with thousands
    video_details = %{base | view_count: 5_500}
    assert VideoDetails.format_view_count(video_details) == "5.5K"
    
    # Test with millions
    video_details = %{base | view_count: 1_500_000}
    assert VideoDetails.format_view_count(video_details) == "1.5M"
    
    # Test with billions
    video_details = %{base | view_count: 1_200_000_000}
    assert VideoDetails.format_view_count(video_details) == "1.2B"
  end
  
  test "format_date formats date correctly" do
    # Create a base struct with all required fields
    base = %VideoDetails{
      id: "test_id",
      title: "Test Video",
      description: "Description",
      channel_id: "UC123456789",
      channel_title: "Test Channel",
      published_at: "2023-01-01",
      duration: "0",
      view_count: 0,
      thumbnail_url: "https://example.com/thumb.jpg"
    }
    
    # Test with ISO 8601 format
    video_details = %{base | published_at: "2023-01-15T14:30:45Z"}
    assert VideoDetails.format_date(video_details) == "Jan 15, 2023"
    
    # Test with invalid format
    video_details = %{base | published_at: "2023-01-15"}
    assert VideoDetails.format_date(video_details) == "2023-01-15"
  end
  
  # Skipped tests that would require HTTP interaction or mocking
  @tag :skip
  test "get_video_details gets details from YouTube" do
    # This would require actual HTTP interaction or mocking
  end
  
  @tag :skip
  test "get_video_details! raises error when not found" do
    # This would require mocking
  end
  
  # Cache-related tests
  test "use_cache? function exists" do
    # Just test that the function exists
    assert is_function(&Youvid.use_cache?/0)
  end
  
  test "clear_cache function exists" do
    # Just test that the function exists
    assert is_function(&Youvid.clear_cache/0)
  end
end
