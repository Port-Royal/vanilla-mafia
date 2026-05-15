module Telegram
  class ForceImportService
    MAX_TITLE_LENGTH = 255
    PHOTO_ONLY_TITLE = "[медиа]".freeze
    DEFAULT_MAX_RANGE = 50

    def self.call(parsed_link:, operator_chat_id:, operator_user:)
      new(parsed_link: parsed_link, operator_chat_id: operator_chat_id, operator_user: operator_user).call
    end

    def initialize(parsed_link:, operator_chat_id:, operator_user:)
      @parsed_link = parsed_link
      @operator_chat_id = operator_chat_id
      @operator_user = operator_user
    end

    def call
      forwarded = fetch_messages
      return dm_no_messages if forwarded.empty?

      first = forwarded.first
      sender_id = original_sender_id(first)
      same_sender = forwarded.select { |m| original_sender_id(m) == sender_id }

      author = resolve_author(sender_id)
      news = build_draft(same_sender, author)
      news.save!

      AutolinkPlayersInNewsService.call(news)
      NotifyEditorsAboutDraftService.call(news)

      dm_success(news, imported: same_sender.size, total: forwarded.size)
    end

    private

    def fetch_messages
      ids = (@parsed_link.message_id..@parsed_link.message_id + @parsed_link.count).to_a
      ids.filter_map { |id| forward_one(id) }
    end

    def forward_one(message_id)
      result = Telegram::ForwardMessageService.call(
        from_chat_id: @parsed_link.source_chat,
        message_id: message_id,
        to_chat_id: @operator_chat_id
      )
      return result.message if result.success

      nil
    end

    def original_sender_id(forwarded_msg)
      origin = forwarded_msg["forward_origin"]
      return origin["sender_user"]["id"] if origin.is_a?(Hash) && origin["sender_user"].is_a?(Hash)

      forwarded_msg.dig("forward_from", "id")
    end

    def original_date(forwarded_msg)
      origin = forwarded_msg["forward_origin"]
      return Time.at(origin["date"]) if origin.is_a?(Hash) && origin["date"].present?

      Time.at(forwarded_msg["forward_date"]) if forwarded_msg["forward_date"]
    end

    def resolve_author(sender_id)
      author = TelegramAuthor.find_by_telegram_user_id(sender_id)
      user = author&.ensure_user!
      return user if user.present?

      @operator_user
    end

    def build_draft(messages, author)
      first = messages.first
      first_text = first["text"].presence || first["caption"].presence
      title = first_text.present? ? first_text.truncate(MAX_TITLE_LENGTH) : PHOTO_ONLY_TITLE
      first_date = original_date(first) || Time.current

      News.new(
        title: title,
        content: first_text.to_s,
        author: author,
        status: :draft,
        created_at: first_date,
        telegram_thread_started_at: first_date,
        telegram_thread_last_message_at: original_date(messages.last) || first_date
      )
    end

    def dm_success(news, imported:, total:)
      Telegram::BotDmService.call(
        chat_id: @operator_chat_id,
        text: I18n.t("telegram.force_import.success", id: news.id, imported: imported, total: total, skipped: total - imported)
      )
    end

    def dm_no_messages
      Telegram::BotDmService.call(
        chat_id: @operator_chat_id,
        text: I18n.t("telegram.force_import.no_messages")
      )
    end
  end
end
