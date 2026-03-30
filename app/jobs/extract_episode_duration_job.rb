class ExtractEpisodeDurationJob < ApplicationJob
  queue_as :default

  def perform(episode)
    episode.extract_duration_from_audio
  end
end
