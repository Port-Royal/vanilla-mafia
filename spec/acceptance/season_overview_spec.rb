require "rails_helper"

RSpec.describe "Season overview" do
  let_it_be(:game1) { create(:game, season: 5, series: 1, game_number: 1, played_on: Date.new(2025, 1, 10)) }
  let_it_be(:game2) { create(:game, season: 5, series: 1, game_number: 2, played_on: Date.new(2025, 1, 17)) }
  let_it_be(:game3) { create(:game, season: 5, series: 2, game_number: 1, played_on: Date.new(2025, 2, 7)) }

  let_it_be(:player1) { create(:player, name: "Алексей") }
  let_it_be(:player2) { create(:player, name: "Борис") }

  before do
    create(:rating, game: game1, player: player1, plus: 3.0, minus: 0.5, win: true)
    create(:rating, game: game1, player: player2, plus: 1.0, minus: 1.5, win: false)
    create(:rating, game: game2, player: player1, plus: 2.0, minus: 1.0, win: true)
    create(:rating, game: game3, player: player2, plus: 4.0, minus: 0.0, win: true)

    visit season_path(number: 5)
  end

  it "links to individual games" do
    expect(page).to have_link(href: game_path(game1))
    expect(page).to have_link(href: game_path(game2))
    expect(page).to have_link(href: game_path(game3))
  end

  it "links to series pages" do
    expect(page).to have_link(href: season_series_path(season_number: 5, number: 1))
    expect(page).to have_link(href: season_series_path(season_number: 5, number: 2))
  end

  it "displays player rankings table headers" do
    expect(page).to have_content("Место")
    expect(page).to have_content("Игрок")
    expect(page).to have_content("Рейтинг")
    expect(page).to have_content("Игры")
    expect(page).to have_content("Процент побед")
  end

  it "links player names to their profiles" do
    expect(page).to have_link("Алексей", href: player_path(player1))
    expect(page).to have_link("Борис", href: player_path(player2))
  end

  it "displays player statistics" do
    within("table#players-table") do
      expect(page).to have_content("Алексей")
      expect(page).to have_content("Борис")
    end
  end
end
