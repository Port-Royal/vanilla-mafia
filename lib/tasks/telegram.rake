require_relative "../telegram/export_parser"

namespace :telegram do
  MAX_TITLE_LENGTH = 255

  desc "Import Telegram Desktop export as News drafts"
  task :import_history, [ :export_path, :from_id, :user_id ] => :environment do |_t, args|
    export_path = args[:export_path]
    from_id = args[:from_id]
    user_id = args[:user_id]

    if export_path.blank? || from_id.blank? || user_id.blank?
      abort <<~USAGE
        Usage: rake telegram:import_history[/path/to/export,user123456,42]

        Arguments:
          export_path   - Path to the Telegram Desktop export directory (contains result.json)
          from_id       - Telegram from_id to filter by (e.g. "user123456789")
          user_id       - ID of the User who will be set as News author
      USAGE
    end

    user = User.find_by(id: user_id)
    abort "User with id '#{user_id}' not found" if user.nil?

    messages = Telegram::ExportParser.new(export_path, from_id: from_id).call

    if messages.empty?
      abort "No messages found matching criteria (from_id=#{from_id}, min length=#{Telegram::ExportParser::MIN_TEXT_LENGTH})"
    end

    puts "Found #{messages.size} messages (#{messages.count(&:photo)} with photos)"

    export_path_dir = Pathname.new(export_path)
    created = 0
    photos_attached = 0
    messages.each do |message|
      news = News.create!(
        title: message.plain_text.truncate(MAX_TITLE_LENGTH),
        author: user,
        status: :draft,
        created_at: message.date,
        updated_at: message.date
      )
      news.update!(content: message.html_content)

      if message.photo.present?
        photo_path = export_path_dir.join(message.photo)
        if photo_path.exist?
          news.photos.attach(
            io: photo_path.open,
            filename: photo_path.basename.to_s,
            content_type: Marcel::MimeType.for(photo_path)
          )
          photos_attached += 1
        else
          puts "Warning: photo not found at #{photo_path}"
        end
      end

      created += 1
    end

    puts "Created #{created} News drafts (#{photos_attached} with photos attached)"
  end

  desc "Register webhook URL with Telegram API (requires WEBHOOK_URL env var)"
  task set_webhook: :environment do
    url = ENV["WEBHOOK_URL"]
    abort "Usage: rake telegram:set_webhook WEBHOOK_URL=https://yourapp.com/webhooks/telegram" if url.blank?

    result = Telegram::RegisterWebhookService.call(url: url)

    if result.success
      puts "Webhook set successfully: #{result.description}"
    else
      abort "Failed to set webhook: #{result.description}"
    end
  end

  desc "Delete webhook registration from Telegram API"
  task delete_webhook: :environment do
    result = Telegram::RegisterWebhookService.delete

    if result.success
      puts "Webhook deleted successfully: #{result.description}"
    else
      abort "Failed to delete webhook: #{result.description}"
    end
  end
end
