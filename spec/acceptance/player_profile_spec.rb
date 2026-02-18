require "rails_helper"

RSpec.describe "Player profile" do
  let!(:player) { create(:player, name: "Алексей") }
  let!(:game) do
    create(:game, season: 5, series: 1, game_number: 1,
           played_on: Date.new(2025, 1, 10))
  end
  let!(:rating) { create(:rating, game: game, player: player, plus: 3.0, minus: 0.5, win: true) }
  let!(:award) { create(:award, title: "Лучший игрок", staff: false) }
  let!(:player_award) { create(:player_award, player: player, award: award, season: 5) }

  before { visit player_path(player) }

  it "displays player name" do
    expect(page).to have_content("Алексей")
  end

  it "displays per-season stats" do
    expect(page).to have_content("Сезон 5")
  end

  it "links to games in the game history" do
    expect(page).to have_link(href: game_path(game))
  end

  it "displays awards" do
    expect(page).to have_content("Лучший игрок")
  end
end
