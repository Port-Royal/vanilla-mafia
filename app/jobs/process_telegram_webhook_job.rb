class ProcessTelegramWebhookJob < ApplicationJob
  queue_as :default

  MAX_TITLE_LENGTH = 255

  def perform(payload)
    parsed = Telegram::MessageParser.call(payload)
    return if parsed.nil?
    return unless parsed.news?
    return if parsed.text.blank?

    author = TelegramAuthor.find_by_telegram_user_id(parsed.from_id)
    return if author.nil?
    return if author.user.nil?

    News.create!(
      title: parsed.text.truncate(MAX_TITLE_LENGTH),
      content: parsed.text,
      author: author.user,
      status: :draft
    )
  end
end
