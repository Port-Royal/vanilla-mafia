require "rails_helper"
require_relative "../../../lib/telegram/migration_generator"
require_relative "../../../lib/telegram/export_parser"

RSpec.describe Telegram::MigrationGenerator do
  let(:author_id) { 42 }

  describe "#call" do
    context "with a single plain text message" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-06-15T10:00:00",
            plain_text: "A very important announcement about the upcoming event",
            html_content: "A very important announcement about the upcoming event",
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "generates a valid migration class" do
        expect(output).to include("class ImportTelegramNewsDrafts < ActiveRecord::Migration[8.1]")
      end

      it "sets the author_id" do
        expect(output).to include("author_id = 42")
      end

      it "includes the message title" do
        expect(output).to include("A very important announcement about the upcoming event")
      end

      it "includes the message date" do
        expect(output).to include("2023-06-15T10:00:00")
      end

      it "creates News records as drafts" do
        expect(output).to include("status: :draft")
      end

      it "sets content via update" do
        expect(output).to include("news.update!(content: entry[:content])")
      end
    end

    context "with a message containing a photo placeholder" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-07-01T12:00:00",
            plain_text: "Message with photo",
            html_content: "[PHOTO: photos/photo_1.jpg]\n\nMessage with photo",
            photo: "photos/photo_1.jpg"
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "preserves photo placeholder in content" do
        expect(output).to include("[PHOTO: photos/photo_1.jpg]")
      end
    end

    context "with a message containing double quotes" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-08-01T12:00:00",
            plain_text: 'He said "hello" to everyone',
            html_content: 'He said &quot;hello&quot; to everyone',
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "escapes double quotes in title" do
        expect(output).to include('He said \"hello\" to everyone')
      end
    end

    context "with a long title" do
      let(:long_text) { "A" * 300 }
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-09-01T12:00:00",
            plain_text: long_text,
            html_content: long_text,
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "truncates title to 255 characters" do
        title_match = output.match(/title: "(.*?[^\\])"/)
        expect(title_match[1].length).to be <= 255
      end
    end

    context "with multiple messages" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-01-01T10:00:00",
            plain_text: "First message",
            html_content: "First message",
            photo: nil
          ),
          Telegram::ExportParser::Message.new(
            date: "2023-02-01T10:00:00",
            plain_text: "Second message",
            html_content: "Second message",
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "includes all messages in the migration" do
        expect(output).to include("First message")
        expect(output).to include("Second message")
      end
    end

    context "with a message containing backslashes in content" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-10-01T12:00:00",
            plain_text: 'Path is C:\\Users\\test',
            html_content: 'Path is C:\\Users\\test',
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "escapes backslashes in content" do
        expect(output).to include('C:\\\\Users\\\\test')
      end
    end

    context "with a message containing multiple double quotes in content" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-11-01T12:00:00",
            plain_text: 'She said "hi" and "bye"',
            html_content: 'She said "hi" and "bye"',
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "escapes all double quotes in content" do
        content_line = output.lines.find { |l| l.strip.start_with?("content:") }

        expect(content_line).to include('\"hi\"')
        expect(content_line).to include('\"bye\"')
      end
    end

    context "with date format in output" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-12-25T18:30:00",
            plain_text: "Holiday message",
            html_content: "Holiday message",
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "outputs only the date string, not the full message object" do
        date_line = output.lines.find { |l| l.include?("date:") }

        expect(date_line).to include("2023-12-25T18:30:00")
        expect(date_line).not_to include("Holiday message")
      end
    end

    context "with multiple entries formatting" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-01-01T10:00:00",
            plain_text: "First",
            html_content: "First",
            photo: nil
          ),
          Telegram::ExportParser::Message.new(
            date: "2023-02-01T10:00:00",
            plain_text: "Second",
            html_content: "Second",
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "separates entries with newlines" do
        first_entry_end = output.index("},")
        second_entry_start = output.index("{", first_entry_end)

        between = output[first_entry_end + 2...second_entry_start]
        expect(between).to include("\n")
      end
    end

    context "with down migration" do
      let(:messages) do
        [
          Telegram::ExportParser::Message.new(
            date: "2023-01-01T10:00:00",
            plain_text: "test",
            html_content: "test",
            photo: nil
          )
        ]
      end

      let(:output) { described_class.new(messages, author_id).call }

      it "includes a down migration" do
        expect(output).to include("def down")
        expect(output).to include("destroy_all")
      end
    end
  end
end
