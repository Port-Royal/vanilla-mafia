require "rails_helper"

RSpec.describe "Admin Competitions CRUD" do
  let_it_be(:admin) { create(:user, :admin) }

  before { sign_in_as_admin(admin) }

  describe "create" do
    it "creates a new competition with slug and position" do
      visit "/avo/resources/competitions/new"
      fill_in "Name", with: "Сезон 7"
      select "season", from: "Kind"
      fill_in "Slug", with: "season-7"
      fill_in "Position", with: "7"
      click_on "Сохранить"

      expect(Competition.find_by(name: "Сезон 7")).to have_attributes(
        slug: "season-7",
        position: 7
      )
    end
  end

  describe "edit" do
    let!(:competition) { create(:competition, :season, name: "Сезон 6", slug: "season-6", position: 6) }

    it "updates slug and position" do
      visit "/avo/resources/competitions/#{competition.slug}/edit"
      fill_in "Slug", with: "season-6-updated"
      fill_in "Position", with: "10"
      click_on "Сохранить"

      expect(competition.reload).to have_attributes(
        slug: "season-6-updated",
        position: 10
      )
    end
  end
end
