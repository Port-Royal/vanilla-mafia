module Telegram
  class MigrationGenerator
    MAX_TITLE_LENGTH = 255

    def initialize(messages, author_id)
      @messages = messages
      @author_id = author_id
    end

    def call
      entries = @messages.map { |m| format_entry(m) }.join("\n")

      <<~RUBY
        class ImportTelegramNewsDrafts < ActiveRecord::Migration[8.1]
          def up
            author_id = #{@author_id}

            entries = [
        #{entries}
            ]

            entries.each do |entry|
              news = News.create!(
                title: entry[:title],
                author_id: author_id,
                status: :draft,
                created_at: entry[:date],
                updated_at: entry[:date]
              )
              news.update!(content: entry[:content])
            end
          end

          def down
            News.where(author_id: #{@author_id}, status: :draft)
                .where("created_at < ?", "2024-01-01")
                .destroy_all
          end
        end
      RUBY
    end

    private

    def format_entry(message)
      title = message.plain_text.truncate(MAX_TITLE_LENGTH).gsub('"', '\\"')
      content = message.html_content.gsub("\\", "\\\\\\\\").gsub('"', '\\"')
      date = message.date

      <<~ENTRY.chomp
              {
                title: "#{title}",
                content: "#{content}",
                date: "#{date}"
              },
      ENTRY
    end
  end
end
