defmodule Youvid.Types do
  @moduledoc false

  alias Youvid.Video
  alias Youvid.VideoDetails

  defmacro __using__(_opts) do
    quote do
      @type video :: Video.t()
      @type video_id :: String.t()

      @type video_details_found :: {:ok, VideoDetails.t()}
      @type error :: {:error, :not_found}
    end
  end
end
