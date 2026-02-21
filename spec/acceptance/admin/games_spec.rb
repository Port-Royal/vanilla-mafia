require "rails_helper"

RSpec.describe "Admin Games CRUD" do
  let_it_be(:admin) { create(:user, admin: true) }

  before { sign_in_as_admin(admin) }

  describe "index" do
    let_it_be(:game) { create(:game, season: 3, series: 2, game_number: 1, name: "Финальная") }

    it "displays games" do
      visit "/avo/resources/games"

      expect(page).to have_content("Финальная")
    end
  end

  describe "show" do
    let_it_be(:game) do
      create(:game, season: 3, series: 2, game_number: 1,
             played_on: Date.new(2025, 6, 15), name: "Финальная", result: "Мафия")
    end

    it "displays game details" do
      visit "/avo/resources/games/#{game.id}"

      expect(page).to have_content("Финальная")
      expect(page).to have_content("Мафия")
    end
  end

  describe "create" do
    it "creates a new game" do
      visit "/avo/resources/games/new"
      fill_in "Season", with: "7"
      fill_in "Series", with: "1"
      fill_in "Game number", with: "1"
      fill_in "Name", with: "Тестовая игра"
      fill_in "Result", with: "Город"
      click_on "Сохранить"

      expect(Game.find_by(name: "Тестовая игра")).to have_attributes(
        season: 7, series: 1, game_number: 1, result: "Город"
      )
    end
  end

  describe "edit" do
    let!(:game) { create(:game, season: 1, series: 1, game_number: 1, name: "Старое") }

    it "updates the game" do
      visit "/avo/resources/games/#{game.id}/edit"
      fill_in "Name", with: "Новое"
      click_on "Сохранить"

      expect(game.reload.name).to eq("Новое")
    end
  end

  describe "destroy" do
    let!(:game) { create(:game, season: 1, series: 1, game_number: 99, name: "Удалить") }

    it "deletes the game" do
      visit "/avo/resources/games/#{game.id}"
      page.driver.browser.process(:delete, "/avo/resources/games/#{game.id}")

      expect(Game.find_by(name: "Удалить")).to be_nil
    end
  end
end
