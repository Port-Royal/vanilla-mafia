require "rails_helper"

# The protocol editor suggests players for each seat through player_select_controller.js.
# #982 showed these suggestions can break in the browser while every request spec stays green.
RSpec.describe "Protocol editor player suggestions" do
  let_it_be(:judge) { create(:user, :judge) }
  let_it_be(:players) { %w[Акула Барсук Волк].map { |name| create(:player, name: name) } }

  let(:seat_one) { find_field("participations[1][player_name]") }
  let(:seat_one_picker) { seat_one.find(:xpath, "..") }
  let(:seat_one_menu) { seat_one_picker.find("[data-player-select-target='menu']", visible: :all) }

  before do
    sign_in judge
    visit new_judge_protocol_path
  end

  context "when a seat's player field gets focus" do
    before { seat_one.click }

    it "suggests every player" do
      expect(seat_one_menu).to have_css("[data-player-select-target='option']", count: 3)
    end

    it "shows the suggestions" do
      expect(seat_one_menu).to have_button("Барсук")
    end
  end

  context "when the judge types part of a name" do
    before { seat_one.fill_in(with: "ба") }

    it "keeps only the matching players" do
      expect(seat_one_menu).to have_button("Барсук").and have_no_button("Акула")
    end
  end

  context "when the judge picks a suggestion" do
    before do
      seat_one.click
      seat_one_menu.click_button("Волк")
    end

    it "fills the seat with the player" do
      expect(page).to have_field("participations[1][player_name]", with: "Волк")
    end

    it "closes the suggestions" do
      expect(seat_one_picker).to have_no_css("[data-player-select-target='menu']", visible: true)
    end
  end

  context "when the judge picks with the keyboard" do
    before do
      seat_one.click
      seat_one.send_keys(:arrow_down, :arrow_down, :enter)
    end

    it "fills the seat with the highlighted player" do
      expect(page).to have_field("participations[1][player_name]", with: "Барсук")
    end
  end

  context "when a player already sits at another seat" do
    before do
      find_field("participations[2][player_name]").fill_in(with: "Акула")
      seat_one.click
    end

    it "does not suggest them again" do
      expect(seat_one_menu).to have_button("Барсук").and have_no_button("Акула")
    end
  end
end
