class ProcessTelegramWebhookJob < ApplicationJob
  queue_as :default

  MAX_TITLE_LENGTH = 255
  MIN_TEXT_LENGTH = 500

  def perform(payload)
    parsed = Telegram::MessageParser.call(payload)
    return if parsed.nil?
    return if parsed.raw_text_length < MIN_TEXT_LENGTH

    author = TelegramAuthor.find_by_telegram_user_id(parsed.from_id)
    return if author.nil?
    return if author.user.nil?
    return if below_score_threshold?(parsed)

    news = News.create!(
      title: parsed.text.truncate(MAX_TITLE_LENGTH),
      content: parsed.html_content,
      author: author.user,
      status: :draft
    )

    attach_photo(news, parsed.photo_file_id) if parsed.photo_file_id.present?
    NotifyEditorsAboutDraftService.call(news)
  end

  private

  SCORE_THRESHOLD_SETTING = "news_score_threshold"
  DEFAULT_SCORE_THRESHOLD = 10

  def below_score_threshold?(parsed)
    return false unless FeatureToggle.enabled?(SCORE_THRESHOLD_SETTING)

    threshold = FeatureToggle.value_for(SCORE_THRESHOLD_SETTING, default: DEFAULT_SCORE_THRESHOLD).to_i
    score = Telegram::NewsScorer.call(parsed)
    score < threshold
  end

  def attach_photo(news, file_id)
    result = Telegram::DownloadFileService.call(file_id)
    return unless result.success?

    news.photos.attach(
      io: result.io,
      filename: result.filename,
      content_type: result.content_type
    )
  end
end
