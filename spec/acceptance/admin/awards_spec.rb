require "rails_helper"

RSpec.describe "Admin Awards CRUD" do
  let_it_be(:admin) { create(:user, admin: true) }

  before { sign_in_as_admin(admin) }

  describe "index" do
    let_it_be(:award) { create(:award, title: "Лучший стратег") }

    it "displays awards" do
      visit "/avo/resources/awards"

      expect(page).to have_content("Лучший стратег")
    end
  end

  describe "show" do
    let_it_be(:award) { create(:award, title: "Лучший стратег", description: "За стратегическое мышление", staff: true, position: 3) }

    it "displays award details" do
      visit "/avo/resources/awards/#{award.id}"

      expect(page).to have_content("Лучший стратег")
      expect(page).to have_content("За стратегическое мышление")
    end
  end

  describe "create" do
    it "creates a new award" do
      visit "/avo/resources/awards/new"
      fill_in "Title", with: "Новая награда"
      fill_in "Description", with: "Описание награды"
      check "Staff"
      fill_in "Position", with: "2"
      click_on "Сохранить"

      expect(Award.find_by(title: "Новая награда")).to have_attributes(
        description: "Описание награды", staff: true, position: 2
      )
    end
  end

  describe "edit" do
    let!(:award) { create(:award, title: "Старая награда") }

    it "updates the award" do
      visit "/avo/resources/awards/#{award.id}/edit"
      fill_in "Title", with: "Обновлённая награда"
      click_on "Сохранить"

      expect(award.reload.title).to eq("Обновлённая награда")
    end
  end

  describe "destroy" do
    let!(:award) { create(:award, title: "Удалить награду") }

    it "deletes the award" do
      visit "/avo/resources/awards/#{award.id}"
      page.driver.browser.process(:delete, "/avo/resources/awards/#{award.id}")

      expect(Award.find_by(title: "Удалить награду")).to be_nil
    end
  end
end
