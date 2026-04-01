require_relative "../telegram/export_parser"
require_relative "../telegram/migration_generator"

namespace :telegram do
  desc "Parse Telegram Desktop export and generate a data migration with News drafts"
  task :generate_import_migration, [ :export_path, :from_id, :user_id ] => :environment do |_t, args|
    export_path = args[:export_path]
    from_id = args[:from_id]
    user_id = args[:user_id]

    if export_path.blank? || from_id.blank? || user_id.blank?
      abort <<~USAGE
        Usage: rake telegram:generate_import_migration[/path/to/export,user123456,42]

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

    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    migration_path = Rails.root.join("db", "migrate", "#{timestamp}_import_telegram_news_drafts.rb")

    migration_content = Telegram::MigrationGenerator.new(messages, user.id).call
    File.write(migration_path, migration_content)

    puts "Generated migration: #{migration_path}"
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
