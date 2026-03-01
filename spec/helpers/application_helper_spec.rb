require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#available_seasons' do
    let_it_be(:game_s2) { create(:game, season: 2) }
    let_it_be(:game_s1) { create(:game, season: 1) }

    it 'delegates to Game.available_seasons' do
      expect(helper.available_seasons).to eq([ 1, 2 ])
    end
  end
end
