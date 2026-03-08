require "rails_helper"

RSpec.describe "Game details" do
  let_it_be(:role_peace) { create(:role, code: "peace", name: "Мирный") }
  let_it_be(:role_mafia) { create(:role, code: "mafia", name: "Мафия") }
  let_it_be(:game) do
    create(:game, season: 5, series: 1, game_number: 1,
           played_on: Date.new(2025, 1, 10), name: "Финал")
  end
  let_it_be(:player1) { create(:player, name: "Алексей") }
  let_it_be(:player2) { create(:player, name: "Борис") }
  let_it_be(:participation1) do
    create(:game_participation, game: game, player: player1, role_code: "peace",
           plus: 3.0, minus: 0.5, best_move: 0.5, win: true, seat: 1)
  end
  let_it_be(:participation2) do
    create(:game_participation, game: game, player: player2, role_code: "mafia",
           plus: 1.0, minus: 1.5, best_move: nil, win: false, seat: 5)
  end

  before { visit game_path(game) }

  it "displays game header with full name" do
    expect(page).to have_content(game.full_name)
  end

  it "displays player names as links to profiles" do
    expect(page).to have_link("Алексей", href: player_path(player1))
    expect(page).to have_link("Борис", href: player_path(player2))
  end

  it "displays role icons" do
    expect(page).to have_css("img[src*='roles/peace']")
    expect(page).to have_css("img[src*='roles/mafia']")
  end

  it "displays seat numbers" do
    within("table") do
      alexey_row = find("tr", text: "Алексей")
      expect(alexey_row).to have_content("1")

      boris_row = find("tr", text: "Борис")
      expect(boris_row).to have_content("5")
    end
  end

  it "displays participation scores" do
    expect(page).to have_content("3.0")
    expect(page).to have_content("0.5")
  end

  it "displays updated table headers" do
    expect(page).to have_content("Место")
    expect(page).to have_content("Роль")
    expect(page).to have_content("Балл")
    expect(page).to have_content("Доп. балл")
    expect(page).to have_content("Лучший ход")
    expect(page).to have_content("Итого")
  end
end
