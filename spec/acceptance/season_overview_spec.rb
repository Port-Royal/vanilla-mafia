require "rails_helper"

RSpec.describe "Season overview" do
  let_it_be(:season) { create(:competition, :season, name: "Сезон 5", slug: "season-5", legacy_season: 5) }
  let_it_be(:series1) { create(:competition, :series, name: "Серия 1", slug: "season-5-series-1", parent: season, position: 1, legacy_season: 5, legacy_series: 1) }
  let_it_be(:series2) { create(:competition, :series, name: "Серия 2", slug: "season-5-series-2", parent: season, position: 2, legacy_season: 5, legacy_series: 2) }
  let_it_be(:game1) { create(:game, competition: series1, season: 5, series: 1, game_number: 1, played_on: Date.new(2025, 1, 10)) }
  let_it_be(:game2) { create(:game, competition: series1, season: 5, series: 1, game_number: 2, played_on: Date.new(2025, 1, 17)) }
  let_it_be(:game3) { create(:game, competition: series2, season: 5, series: 2, game_number: 1, played_on: Date.new(2025, 2, 7)) }

  let_it_be(:player1) { create(:player, name: "Алексей") }
  let_it_be(:player2) { create(:player, name: "Борис") }

  before do
    create(:game_participation, game: game1, player: player1, plus: 3.0, minus: 0.5, win: true)
    create(:game_participation, game: game1, player: player2, plus: 1.0, minus: 1.5, win: false)
    create(:game_participation, game: game2, player: player1, plus: 2.0, minus: 1.0, win: true)
    create(:game_participation, game: game3, player: player2, plus: 4.0, minus: 0.0, win: true)

    visit season_path(number: 5)
  end

  it "links to individual games" do
    expect(page).to have_link(href: game_path(game1))
    expect(page).to have_link(href: game_path(game2))
    expect(page).to have_link(href: game_path(game3))
  end

  it "links to child competition pages" do
    expect(page).to have_link(href: competition_path(slug: series1.slug))
    expect(page).to have_link(href: competition_path(slug: series2.slug))
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
