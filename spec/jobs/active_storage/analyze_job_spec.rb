require "rails_helper"

RSpec.describe ActiveStorage::AnalyzeJob do
  describe "missing-file handling" do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("not really a png"),
        filename: "missing.png",
        content_type: "image/png"
      )
    end

    before { ActiveStorage::Blob.service.delete(blob.key) }

    it "discards ActiveStorage::FileNotFoundError instead of raising" do
      expect { described_class.perform_now(blob) }.not_to raise_error
    end

    it "registers a rescue handler for ActiveStorage::FileNotFoundError" do
      handler_classes = described_class.rescue_handlers.map(&:first)
      expect(handler_classes).to include("ActiveStorage::FileNotFoundError")
    end

    it "logs a structured warning when discarding" do
      allow(Rails.logger).to receive(:warn)
      allow_any_instance_of(ActiveStorage::Blob).to receive(:analyze)
        .and_raise(ActiveStorage::FileNotFoundError)

      described_class.perform_now(blob)

      expect(Rails.logger).to have_received(:warn) do |payload|
        parsed = JSON.parse(payload)
        expect(parsed["event"]).to eq("active_storage.analyze_job.file_missing")
        expect(parsed["blob_id"]).to eq(blob.id)
      end
    end
  end
end
