require "rails_helper"

RSpec.describe "Admin Ratings CRUD" do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 1, name: "Тестовая") }
  let_it_be(:player) { create(:player, name: "Тестовый Игрок") }
  let_it_be(:role) { create(:role, code: "maf", name: "Мафия") }

  before { sign_in_as_admin(admin) }

  describe "index" do
    let_it_be(:rating) { create(:rating, game: game, player: player, plus: 3.0, minus: 1.0, win: true) }

    it "displays ratings" do
      visit "/avo/resources/ratings"

      expect(page).to have_content("Тестовый Игрок")
    end
  end

  describe "show" do
    let_it_be(:rating) { create(:rating, game: game, player: player, plus: 3.0, minus: 1.0, win: true) }

    it "displays rating details" do
      visit "/avo/resources/ratings/#{rating.id}"

      expect(page).to have_content("3")
      expect(page).to have_content("1")
    end
  end

  describe "create" do
    it "creates a new rating" do
      visit "/avo/resources/ratings/new"
      select game.full_name, from: "Game"
      select player.name, from: "Player"
      fill_in "Plus", with: "4.5"
      fill_in "Minus", with: "0.5"
      check "Win"
      click_on "Сохранить"

      expect(Rating.last).to have_attributes(game_id: game.id, plus: 4.5, minus: 0.5, win: true)
    end
  end

  describe "edit" do
    let!(:rating) { create(:rating, game: game, player: player, plus: 1.0) }

    it "updates the rating" do
      visit "/avo/resources/ratings/#{rating.id}/edit"
      fill_in "Plus", with: "5.0"
      click_on "Сохранить"

      expect(rating.reload.plus).to eq(5.0)
    end
  end

  describe "destroy" do
    let!(:rating) { create(:rating, game: game, player: player) }

    it "deletes the rating" do
      visit "/avo/resources/ratings/#{rating.id}"
      page.driver.browser.process(:delete, "/avo/resources/ratings/#{rating.id}")

      expect(Rating.find_by(id: rating.id)).to be_nil
    end
  end
end
