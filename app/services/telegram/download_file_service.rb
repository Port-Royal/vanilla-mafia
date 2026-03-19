require "net/http"
require "json"

module Telegram
  class DownloadFileService
    SuccessResult = Data.define(:io, :filename, :content_type) do
      def success? = true
    end

    FailureResult = Data.define(:description) do
      def success? = false
    end

    BASE_URL = "https://api.telegram.org"

    def self.call(file_id)
      new.call(file_id)
    end

    def call(file_id)
      token = bot_token
      return failure("Missing required config: bot_token") if token.blank?

      file_path = fetch_file_path(token, file_id)
      return file_path if file_path.is_a?(FailureResult)

      download_file(token, file_path)
    end

    private

    def bot_token
      Rails.application.config.x.telegram.bot_token
    end

    def fetch_file_path(token, file_id)
      uri = URI("#{BASE_URL}/bot#{token}/getFile?file_id=#{file_id}")
      response = Net::HTTP.get_response(uri)
      data = JSON.parse(response.body)

      return failure(data["description"]) unless data["ok"]

      data.dig("result", "file_path")
    rescue JSON::ParserError,
           SocketError,
           IOError,
           SystemCallError,
           Net::OpenTimeout,
           Net::ReadTimeout => e
      failure("#{e.class}: #{e.message}")
    end

    def download_file(token, file_path)
      uri = URI("#{BASE_URL}/file/bot#{token}/#{file_path}")
      response = Net::HTTP.get_response(uri)

      return failure("Download failed with HTTP #{response.code}") unless response.code == "200"

      SuccessResult.new(
        io: StringIO.new(response.body),
        filename: File.basename(file_path),
        content_type: response.content_type
      )
    rescue SocketError,
           IOError,
           SystemCallError,
           Net::OpenTimeout,
           Net::ReadTimeout => e
      failure("#{e.class}: #{e.message}")
    end

    def failure(message)
      FailureResult.new(description: message)
    end
  end
end
