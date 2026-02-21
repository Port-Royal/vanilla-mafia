require "rails_helper"

RSpec.describe "Admin Players CRUD" do
  let_it_be(:admin) { create(:user, admin: true) }

  before { sign_in_as_admin(admin) }

  describe "index" do
    let_it_be(:player) { create(:player, name: "Тестовый Игрок") }

    it "displays players" do
      visit "/avo/resources/players"

      expect(page).to have_content("Тестовый Игрок")
    end
  end

  describe "show" do
    let_it_be(:player) { create(:player, name: "Тестовый Игрок", position: 1) }

    it "displays player details" do
      visit "/avo/resources/players/#{player.id}"

      expect(page).to have_content("Тестовый Игрок")
      expect(page).to have_content("1")
    end
  end

  describe "create" do
    it "creates a new player" do
      visit "/avo/resources/players/new"
      fill_in "Name", with: "Новый Игрок"
      fill_in "Position", with: "5"
      fill_in "Comment", with: "Новый комментарий"
      click_on "Сохранить"

      expect(Player.find_by(name: "Новый Игрок")).to have_attributes(position: 5, comment: "Новый комментарий")
    end
  end

  describe "edit" do
    let!(:player) { create(:player, name: "Старое Имя") }

    it "updates the player" do
      visit "/avo/resources/players/#{player.id}/edit"
      fill_in "Name", with: "Новое Имя"
      click_on "Сохранить"

      expect(player.reload.name).to eq("Новое Имя")
    end
  end

  describe "destroy" do
    let!(:player) { create(:player, name: "Удалить Меня") }

    it "deletes the player" do
      visit "/avo/resources/players/#{player.id}"
      page.driver.browser.process(:delete, "/avo/resources/players/#{player.id}")

      expect(Player.find_by(name: "Удалить Меня")).to be_nil
    end
  end
end
