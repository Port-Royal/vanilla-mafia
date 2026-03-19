require "rails_helper"

RSpec.describe Telegram::DownloadFileService do
  let(:bot_token) { "123456:ABC-DEF" }

  around do |example|
    original_token = Rails.application.config.x.telegram.bot_token
    Rails.application.config.x.telegram.bot_token = bot_token
    example.run
  ensure
    Rails.application.config.x.telegram.bot_token = original_token
  end

  describe ".call" do
    context "when file is downloaded successfully" do
      let(:get_file_body) { { "ok" => true, "result" => { "file_id" => "abc123", "file_path" => "photos/file_0.jpg" } }.to_json }
      let(:get_file_response) { instance_double(Net::HTTPOK, body: get_file_body) }
      let(:file_binary) { "fake image content" }
      let(:download_response) { instance_double(Net::HTTPOK, body: file_binary, code: "200", content_type: "image/jpeg") }

      before do
        allow(Net::HTTP).to receive(:get_response).and_return(get_file_response, download_response)
      end

      it "returns a successful result" do
        result = described_class.call("abc123")
        expect(result).to be_success
      end

      it "returns the file content as an IO object" do
        result = described_class.call("abc123")
        expect(result.io.read).to eq(file_binary)
      end

      it "returns the filename from the file path" do
        result = described_class.call("abc123")
        expect(result.filename).to eq("file_0.jpg")
      end

      it "returns the content type from response" do
        result = described_class.call("abc123")
        expect(result.content_type).to eq("image/jpeg")
      end

      it "calls getFile with the correct URL" do
        described_class.call("abc123")
        expect(Net::HTTP).to have_received(:get_response)
          .with(URI("https://api.telegram.org/bot#{bot_token}/getFile?file_id=abc123"))
      end

      it "downloads from the correct file URL" do
        described_class.call("abc123")
        expect(Net::HTTP).to have_received(:get_response)
          .with(URI("https://api.telegram.org/file/bot#{bot_token}/photos/file_0.jpg"))
      end
    end

    context "when bot_token is missing" do
      let(:bot_token) { nil }

      it "returns a failure result with success? equal to false" do
        result = described_class.call("abc123")
        expect(result.success?).to be false
      end

      it "includes an error description" do
        result = described_class.call("abc123")
        expect(result.description).to eq("Missing required config: bot_token")
      end
    end

    context "when getFile API returns an error" do
      let(:get_file_body) { { "ok" => false, "description" => "Bad Request: invalid file_id" }.to_json }
      let(:get_file_response) { instance_double(Net::HTTPOK, body: get_file_body) }

      before do
        allow(Net::HTTP).to receive(:get_response).and_return(get_file_response)
      end

      it "returns a failure result" do
        result = described_class.call("bad_id")
        expect(result).not_to be_success
      end

      it "includes the API error description" do
        result = described_class.call("bad_id")
        expect(result.description).to eq("Bad Request: invalid file_id")
      end
    end

    context "when a network error occurs" do
      before do
        allow(Net::HTTP).to receive(:get_response).and_raise(Net::OpenTimeout.new("execution expired"))
      end

      it "returns a failure result" do
        result = described_class.call("abc123")
        expect(result).not_to be_success
      end

      it "includes the error class and message separated by colon" do
        result = described_class.call("abc123")
        expect(result.description).to eq("Net::OpenTimeout: execution expired")
      end
    end

    context "when a network error occurs during file download" do
      let(:get_file_body) { { "ok" => true, "result" => { "file_id" => "abc123", "file_path" => "photos/file_0.jpg" } }.to_json }
      let(:get_file_response) { instance_double(Net::HTTPOK, body: get_file_body) }

      before do
        call_count = 0
        allow(Net::HTTP).to receive(:get_response) do
          call_count += 1
          if call_count == 1
            get_file_response
          else
            raise SocketError, "getaddrinfo: Name or service not known"
          end
        end
      end

      it "returns a failure result" do
        result = described_class.call("abc123")
        expect(result).not_to be_success
      end

      it "includes the error class and message separated by colon" do
        result = described_class.call("abc123")
        expect(result.description).to eq("SocketError: getaddrinfo: Name or service not known")
      end
    end

    context "when file download returns a non-200 status" do
      let(:get_file_body) { { "ok" => true, "result" => { "file_id" => "abc123", "file_path" => "photos/file_0.jpg" } }.to_json }
      let(:get_file_response) { instance_double(Net::HTTPOK, body: get_file_body) }
      let(:download_response) { instance_double(Net::HTTPNotFound, body: "Not Found", code: "404", content_type: "text/plain") }

      before do
        allow(Net::HTTP).to receive(:get_response).and_return(get_file_response, download_response)
      end

      it "returns a failure result" do
        result = described_class.call("abc123")
        expect(result).not_to be_success
      end

      it "includes the HTTP status in description" do
        result = described_class.call("abc123")
        expect(result.description).to eq("Download failed with HTTP 404")
      end
    end
  end
end
