require "rails_helper"

RSpec.describe "Player profile" do
  let_it_be(:player) { create(:player, name: "Алексей") }
  let_it_be(:game) do
    create(:game, season: 5, series: 1, game_number: 1,
           played_on: Date.new(2025, 1, 10))
  end
  let_it_be(:participation) { create(:game_participation, game: game, player: player, plus: 3.0, minus: 0.5, win: true) }
  let_it_be(:award) { create(:award, title: "Лучший игрок", staff: false) }
  let_it_be(:player_award) { create(:player_award, player: player, award: award, season: 5) }

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
