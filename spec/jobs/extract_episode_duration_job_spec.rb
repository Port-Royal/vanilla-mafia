require "rails_helper"

RSpec.describe ExtractEpisodeDurationJob, type: :job do
  let(:episode) { create(:episode) }

  it "calls extract_duration_from_audio on the episode" do
    allow(episode).to receive(:extract_duration_from_audio)

    described_class.perform_now(episode)

    expect(episode).to have_received(:extract_duration_from_audio)
  end
end
