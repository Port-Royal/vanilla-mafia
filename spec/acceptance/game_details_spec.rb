require "rails_helper"

RSpec.describe "Game details" do
  let!(:role) { create(:role, code: "peace", name: "Мирный") }
  let!(:game) do
    create(:game, season: 5, series: 1, game_number: 1,
           played_on: Date.new(2025, 1, 10), name: "Финал")
  end
  let!(:player1) { create(:player, name: "Алексей") }
  let!(:player2) { create(:player, name: "Борис") }
  let!(:rating1) do
    create(:rating, game: game, player: player1, role_code: "peace",
           plus: 3.0, minus: 0.5, best_move: 0.5, win: true)
  end
  let!(:rating2) do
    create(:rating, game: game, player: player2, role_code: "peace",
           plus: 1.0, minus: 1.5, best_move: nil, win: false)
  end

  before { visit game_path(game) }

  it "displays game header with full name" do
    expect(page).to have_content(game.full_name)
  end

  it "displays player names in the rating table" do
    expect(page).to have_content("Алексей")
    expect(page).to have_content("Борис")
  end

  it "displays role names" do
    expect(page).to have_content("Мирный")
  end

  it "displays rating values" do
    expect(page).to have_content("3.0")
    expect(page).to have_content("0.5")
  end

  it "displays rating table headers" do
    expect(page).to have_content("Роль")
    expect(page).to have_content("Плюс")
    expect(page).to have_content("Минус")
    expect(page).to have_content("Лучший ход")
    expect(page).to have_content("Итого")
  end
end
