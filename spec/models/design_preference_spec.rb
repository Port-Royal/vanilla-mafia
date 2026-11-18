require "rails_helper"

RSpec.describe DesignPreference do
  describe "constants" do
    it { expect(described_class::TOGGLE_KEY).to eq("public_redesign") }
    it { expect(described_class::COOKIE).to eq(:design) }
    it { expect(described_class::CHOICES).to eq(%w[new old]) }
    it { expect(described_class::CHOICES).to be_frozen }
  end

  describe ".mode" do
    context "when the toggle was never set" do
      it { expect(described_class.mode).to eq(:off) }
    end

    context "when the toggle is disabled" do
      let_it_be(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: false, value: "everyone") }

      it { expect(described_class.mode).to eq(:off) }
    end

    context "when enabled with value everyone" do
      let_it_be(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: true, value: "everyone") }

      it { expect(described_class.mode).to eq(:everyone) }
    end

    context "when enabled with value opt_in" do
      let_it_be(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: true, value: "opt_in") }

      it { expect(described_class.mode).to eq(:opt_in) }
    end

    context "when enabled with an unknown value" do
      let_it_be(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: true, value: "sometimes") }

      it { expect(described_class.mode).to eq(:opt_in) }
    end

    context "when enabled with a blank value" do
      let_it_be(:toggle) { create(:feature_toggle, key: "public_redesign", enabled: true, value: "") }

      it { expect(described_class.mode).to eq(:opt_in) }
    end

    context "when another toggle is enabled with value everyone" do
      let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true, value: "everyone") }

      it { expect(described_class.mode).to eq(:off) }
    end
  end

  # Full matrix: mode × choice → [new_design?, offer?, switch_to_new?, switch_to_old?]
  {
    [ :off, nil ] => [ false, false, false, false ],
    [ :off, "new" ] => [ false, false, false, false ],
    [ :off, "old" ] => [ false, false, false, false ],
    [ :opt_in, nil ] => [ false, true, false, false ],
    [ :opt_in, "beta" ] => [ false, true, false, false ],
    [ :opt_in, "" ] => [ false, true, false, false ],
    [ :opt_in, "new" ] => [ true, false, false, true ],
    [ :opt_in, "old" ] => [ false, false, true, false ],
    [ :everyone, nil ] => [ true, false, false, false ],
    [ :everyone, "new" ] => [ true, false, false, false ],
    [ :everyone, "old" ] => [ true, false, false, false ]
  }.each do |(mode, choice), (new_design, offer, to_new, to_old)|
    context "when mode is #{mode} and the cookie is #{choice.inspect}" do
      subject(:preference) { described_class.new(mode: mode, choice: choice) }

      it { expect(preference.new_design?).to be(new_design) }
      it { expect(preference.offer?).to be(offer) }
      it { expect(preference.switch_to_new?).to be(to_new) }
      it { expect(preference.switch_to_old?).to be(to_old) }
    end
  end
end
