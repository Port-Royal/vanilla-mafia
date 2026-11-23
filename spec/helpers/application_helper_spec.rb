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

    it 'memoizes the relation' do
      expect(helper.featured_competitions).to equal(helper.featured_competitions)
    end
  end

  describe '#page_title' do
    context 'without page parts' do
      it { expect(helper.page_title).to eq("Vanilla Mafia") }
    end

    context 'with one part' do
      it { expect(helper.page_title("News")).to eq("News — Vanilla Mafia") }
    end

    context 'with several parts' do
      it { expect(helper.page_title("Game 7", "Series 2")).to eq("Game 7 — Series 2 — Vanilla Mafia") }
    end

    context 'with markup in a part' do
      it { expect(helper.page_title("<b>&")).to eq("&lt;b&gt;&amp; — Vanilla Mafia") }
      it { expect(helper.page_title("<b>&")).to be_html_safe }
    end

    context 'with an html-safe part' do
      it { expect(helper.page_title("<b>".html_safe)).to eq("<b> — Vanilla Mafia") }
    end
  end

  describe '#competition_title_parts' do
    let_it_be(:season) { create(:competition, :season, name: "Season 5") }
    let_it_be(:series) { create(:competition, :series, name: "Series 2", parent: season) }
    let_it_be(:round) { create(:competition, :round, name: "Round 1", parent: series) }

    context 'with a root competition' do
      it { expect(helper.competition_title_parts(season)).to eq([ "Season 5" ]) }
    end

    context 'with a nested competition' do
      it { expect(helper.competition_title_parts(round)).to eq([ "Round 1", "Series 2", "Season 5" ]) }
    end
  end
end
