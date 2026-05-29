require "rails_helper"

RSpec.describe ActiveStorage::AnalyzeJobScrubber do
  FakeJob = Struct.new(:id, :arguments, keyword_init: true) do
    def discard
      @discarded = true
    end

    def discarded?
      @discarded == true
    end
  end

  def gid_for(blob_id)
    { "arguments" => [ { "_aj_globalid" => "gid://vanilla-mafia/ActiveStorage::Blob/#{blob_id}" } ] }
  end

  def build_blob(file_missing: false)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("payload"),
      filename: "f.png",
      content_type: "image/png"
    )
    blob.service.delete(blob.key) if file_missing
    blob
  end

  describe "blob row missing" do
    it "counts orphan and discards the job" do
      job = FakeJob.new(id: 1, arguments: gid_for(999_999))

      result = described_class.call(scope: [ job ])

      expect(result).to have_attributes(scanned: 1, orphaned: 1)
      expect(job).to be_discarded
    end

    it "logs the orphan with the correct blob_id, sq_job_id, and reason" do
      allow(Rails.logger).to receive(:warn)
      job = FakeJob.new(id: 42, arguments: gid_for(999_999))

      described_class.call(scope: [ job ])

      expect(Rails.logger).to have_received(:warn) do |payload|
        parsed = JSON.parse(payload)
        expect(parsed).to include(
          "event" => "active_storage.scrub.orphan_analyze_job",
          "sq_job_id" => 42,
          "blob_id" => 999_999,
          "reason" => "blob row missing",
          "dry_run" => false
        )
      end
    end
  end

  describe "blob present but file missing on disk" do
    it "counts orphan and discards" do
      blob = build_blob(file_missing: true)
      job = FakeJob.new(id: 2, arguments: gid_for(blob.id))

      result = described_class.call(scope: [ job ])

      expect(result.orphaned).to eq(1)
      expect(job).to be_discarded
    end

    it "logs the orphan with reason 'blob file missing'" do
      allow(Rails.logger).to receive(:warn)
      blob = build_blob(file_missing: true)
      job = FakeJob.new(id: 7, arguments: gid_for(blob.id))

      described_class.call(scope: [ job ])

      expect(Rails.logger).to have_received(:warn) do |payload|
        parsed = JSON.parse(payload)
        expect(parsed).to include("reason" => "blob file missing", "blob_id" => blob.id)
      end
    end
  end

  describe "blob and file both present" do
    it "leaves the job in place" do
      blob = build_blob
      job = FakeJob.new(id: 3, arguments: gid_for(blob.id))

      result = described_class.call(scope: [ job ])

      expect(result.orphaned).to eq(0)
      expect(job).not_to be_discarded
    end
  end

  describe "dry_run: true" do
    it "counts orphans but does not discard" do
      job = FakeJob.new(id: 4, arguments: gid_for(999_999))

      result = described_class.call(scope: [ job ], dry_run: true)

      expect(result.orphaned).to eq(1)
      expect(job).not_to be_discarded
    end

    it "marks the log payload as dry_run" do
      allow(Rails.logger).to receive(:warn)
      job = FakeJob.new(id: 5, arguments: gid_for(999_999))

      described_class.call(scope: [ job ], dry_run: true)

      expect(Rails.logger).to have_received(:warn) do |payload|
        expect(JSON.parse(payload)["dry_run"]).to be(true)
      end
    end
  end

  describe "blob_id extraction" do
    it "parses the final integer segment of the GlobalID" do
      blob = build_blob(file_missing: true)
      job = FakeJob.new(id: 8, arguments: gid_for(blob.id))
      allow(Rails.logger).to receive(:warn)

      described_class.call(scope: [ job ])

      expect(Rails.logger).to have_received(:warn) do |payload|
        expect(JSON.parse(payload)["blob_id"]).to eq(blob.id)
      end
    end
  end

  describe "unparseable globalid" do
    it "skips the job without raising" do
      job = FakeJob.new(id: 5, arguments: { "arguments" => [ { "_aj_globalid" => "not-a-gid" } ] })

      expect { described_class.call(scope: [ job ]) }.not_to raise_error
      expect(job).not_to be_discarded
    end
  end

  describe "missing arguments key" do
    it "skips the job" do
      job = FakeJob.new(id: 6, arguments: {})

      result = described_class.call(scope: [ job ])

      expect(result.scanned).to eq(1)
      expect(result.orphaned).to eq(0)
      expect(job).not_to be_discarded
    end
  end
end
