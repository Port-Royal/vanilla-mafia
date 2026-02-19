require "rails_helper"

RSpec.describe "Hall of Fame" do
  let_it_be(:player) { create(:player, name: "Алексей") }
  let_it_be(:organizer) { create(:player, name: "Ведущий") }
  let_it_be(:award) { create(:award, title: "Лучший игрок", staff: false) }
  let_it_be(:staff_award) { create(:award, title: "Лучший ведущий", staff: true) }

  before do
    create(:player_award, player: player, award: award, season: 5)
    create(:player_award, player: organizer, award: staff_award, season: 5)

    visit hall_path
  end

  it "displays the hall of fame title" do
    expect(page).to have_content("Зал Славы")
  end

  it "displays awarded players with their awards" do
    expect(page).to have_content("Алексей")
    expect(page).to have_content("Лучший игрок")
  end

  it "displays staff/organizer section separately" do
    expect(page).to have_content("Организаторы")
    expect(page).to have_content("Ведущий")
    expect(page).to have_content("Лучший ведущий")
  end
end
