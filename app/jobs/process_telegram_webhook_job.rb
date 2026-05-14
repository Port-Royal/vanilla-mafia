class ProcessTelegramWebhookJob < ApplicationJob
  queue_as :default

  MAX_TITLE_LENGTH = 255
  MIN_TEXT_LENGTH = 500

  THREAD_TOGGLE = "telegram_thread_window".freeze
  THREAD_SECONDS_SETTING = "telegram_thread_window_seconds".freeze
  THREAD_STRATEGY_SETTING = "telegram_thread_window_strategy".freeze
  DEFAULT_THREAD_SECONDS = 900
  DEFAULT_THREAD_STRATEGY = "sliding".freeze

  def perform(payload)
    parsed = Telegram::MessageParser.call(payload)
    return if parsed.nil?

    author = TelegramAuthor.find_by_telegram_user_id(parsed.from_id)
    return if author.nil?

    news_author = author.ensure_user!
    if news_author.nil?
      log_no_linked_user(author, parsed)
      return
    end

    open_thread = find_open_thread(news_author)
    if open_thread.present?
      append_to_thread(open_thread, parsed)
      return
    end

    return if parsed.raw_text_length < MIN_TEXT_LENGTH
    return if below_score_threshold?(parsed)

    create_new_draft(news_author, parsed)
  end

  private

  def thread_window_enabled?
    FeatureToggle.enabled?(THREAD_TOGGLE)
  end

  def thread_window_seconds
    FeatureToggle.value_for(THREAD_SECONDS_SETTING, default: DEFAULT_THREAD_SECONDS).to_i
  end

  def thread_window_strategy
    FeatureToggle.value_for(THREAD_STRATEGY_SETTING, default: DEFAULT_THREAD_STRATEGY)
  end

  def find_open_thread(news_author)
    return nil unless thread_window_enabled?

    cutoff = Time.current - thread_window_seconds
    column = thread_window_strategy == "fixed" ? :telegram_thread_started_at : :telegram_thread_last_message_at

    News.where(author: news_author, status: :draft)
        .where("#{column} > ?", cutoff)
        .order(telegram_thread_last_message_at: :desc)
        .first
  end

  def append_to_thread(news, parsed)
    parts = [ news.content.body.to_html ]
    parts << embedded_photo_html(news, parsed.photo_file_id) if parsed.photo_file_id.present?
    parts << parsed.html_content if parsed.text.present?

    news.update!(
      content: parts.join,
      telegram_thread_last_message_at: Time.current
    )

    AutolinkPlayersInNewsService.call(news)
  end

  def create_new_draft(news_author, parsed)
    news = News.new(
      title: parsed.text.truncate(MAX_TITLE_LENGTH),
      content: parsed.html_content,
      author: news_author,
      status: :draft
    )

    if thread_window_enabled?
      now = Time.current
      news.telegram_thread_started_at = now
      news.telegram_thread_last_message_at = now
    end

    news.save!

    if parsed.photo_file_id.present?
      if thread_window_enabled?
        news.update!(content: news.content.body.to_html + embedded_photo_html(news, parsed.photo_file_id))
      else
        attach_photo_to_gallery(news, parsed.photo_file_id)
      end
    end

    AutolinkPlayersInNewsService.call(news)
    NotifyEditorsAboutDraftService.call(news)
  end

  def embedded_photo_html(_news, file_id)
    result = Telegram::DownloadFileService.call(file_id)
    return "" unless result.success?

    blob = ActiveStorage::Blob.create_and_upload!(
      io: result.io,
      filename: result.filename,
      content_type: result.content_type
    )
    ActionText::Attachment.from_attachable(blob).to_html
  end

  def attach_photo_to_gallery(news, file_id)
    result = Telegram::DownloadFileService.call(file_id)
    return unless result.success?

    news.photos.attach(
      io: result.io,
      filename: result.filename,
      content_type: result.content_type
    )
  end

  def log_no_linked_user(author, parsed)
    Rails.logger.warn(
      { event: "telegram_webhook.no_linked_user", from_id: parsed.from_id, telegram_author_id: author.id }.to_json
    )
  end

  SCORE_THRESHOLD_SETTING = "news_score_threshold"
  DEFAULT_SCORE_THRESHOLD = 10

  def below_score_threshold?(parsed)
    return false unless FeatureToggle.enabled?(SCORE_THRESHOLD_SETTING)

    threshold = FeatureToggle.value_for(SCORE_THRESHOLD_SETTING, default: DEFAULT_SCORE_THRESHOLD).to_i
    score = Telegram::NewsScorer.call(parsed)
    decision = score < threshold ? :rejected : :accepted
    payload = { event: "telegram_webhook.#{decision}", score: score, threshold: threshold, from_id: parsed.from_id }.to_json
    if decision == :rejected
      Rails.logger.debug(payload)
      true
    else
      Rails.logger.info(payload)
      false
    end
  end
end
