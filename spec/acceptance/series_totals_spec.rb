require "rails_helper"

RSpec.describe "Series totals" do
  let!(:game1) { create(:game, season: 5, series: 1, game_number: 1) }
  let!(:game2) { create(:game, season: 5, series: 1, game_number: 2) }
  let!(:player1) { create(:player, name: "Алексей") }
  let!(:player2) { create(:player, name: "Борис") }

  before do
    create(:rating, game: game1, player: player1, plus: 3.0, minus: 0.5)
    create(:rating, game: game1, player: player2, plus: 1.0, minus: 1.5)
    create(:rating, game: game2, player: player1, plus: 2.0, minus: 1.0)
    create(:rating, game: game2, player: player2, plus: 5.0, minus: 0.0)

    visit season_series_path(season_number: 5, number: 1)
  end

  it "displays player names" do
    expect(page).to have_content("Алексей")
    expect(page).to have_content("Борис")
  end

  it "displays game columns" do
    expect(page).to have_content("Игра 1")
    expect(page).to have_content("Игра 2")
  end

  it "displays a total column" do
    expect(page).to have_content("Итого")
  end

  it "sorts players by total descending" do
    expect(page.text).to match(/Борис.*Алексей/m)
  end
end
