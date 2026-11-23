require "rails_helper"

RSpec.describe StatsHelper do
  describe "#stats_share" do
    it { expect(helper.stats_share(1, 3)).to eq(33) }
    it { expect(helper.stats_share(2, 3)).to eq(67) }
    it { expect(helper.stats_share(3, 3)).to eq(100) }
  end

  describe "#stats_result_bar_class" do
    it { expect(helper.stats_result_bar_class(:peace_victory)).to eq("bg-gold-soft") }
    it { expect(helper.stats_result_bar_class(:mafia_victory)).to eq("bg-alert-soft") }
    it { expect(helper.stats_result_bar_class(:draw)).to eq("bg-line") }
    it { expect { helper.stats_result_bar_class(:in_progress) }.to raise_error(KeyError) }
  end
end
