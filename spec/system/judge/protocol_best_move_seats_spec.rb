require "rails_helper"

RSpec.describe "Protocol best move seats autosave" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:game) { create(:game) }
  let_it_be(:participation) do
    create(:game_participation, game: game, player: create(:player, name: "Кузнецов"), seat: 1, best_move_seats: [ 5 ])
  end

  let(:seat_selects) { all("select[name='participations[1][best_move_seats][]']") }
  let(:stored_seats) do
    page.document.synchronize do
      seats = participation.reload.best_move_seats
      raise Capybara::ExpectationNotMet, "seats not saved yet: #{seats.inspect}" unless seats == expected_seats

      seats
    end
  end

  before do
    sign_in admin
    visit edit_judge_protocol_path(game)
    click_button I18n.t("game_protocols.autosave.toggle_off")
    choices.each_with_index { |seat, index| seat_selects[index].find("option[value='#{seat}']").select_option }
  end

  context "when seats are picked" do
    let(:choices) { [ "3", "", "7" ] }
    let(:expected_seats) { [ 3, 7 ] }

    it "saves every named seat" do
      expect(stored_seats).to eq([ 3, 7 ])
    end
  end

  context "when the only seat is cleared" do
    let(:choices) { [ "" ] }
    let(:expected_seats) { nil }

    it "clears the stored seats" do
      expect(stored_seats).to be_nil
    end
  end
end
