require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#featured_competitions' do
    let_it_be(:featured) { create(:competition, :season, :featured, name: "Season A", position: 2) }
    let_it_be(:also_featured) { create(:competition, :season, :featured, name: "Season B", position: 1) }
    let_it_be(:not_featured) { create(:competition, :season, name: "Hidden") }

    it 'returns featured competitions in position order' do
      expect(helper.featured_competitions).to eq([ also_featured, featured ])
    end

    it 'excludes non-featured competitions' do
      expect(helper.featured_competitions).not_to include(not_featured)
    end
  end
end
