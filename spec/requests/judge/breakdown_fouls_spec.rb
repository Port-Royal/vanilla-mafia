require "rails_helper"

RSpec.describe "Judge::Breakdowns fouls" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:breakdown) { create(:game_breakdown, author: admin) }
  let(:zero_round) { breakdown.phases.find_by!(position: 0) }
  let(:host_speech) { speech(zero_round, 1) }
  let(:seat) { breakdown.seats.find_by!(number: 3) }
  let(:seat_fouls) { %(id="#{ActionView::RecordIdentifier.dom_id(seat)}_fouls") }
  let(:foul_label) { I18n.t("game_breakdowns.editor.fouls", count: 2) }
  let(:second_foul_summary) { "#{I18n.t('game_breakdowns.move_kinds.foul')} · #{I18n.t('game_breakdowns.editor.foul_number', number: 2)}" }

  before do
    sign_in admin
    create_list(:breakdown_move, 2, :foul, breakdown_speech: host_speech, actor_seat: 3)
  end

  describe "GET /judge/breakdowns/:id/edit" do
    before { get edit_judge_breakdown_path(breakdown) }

    it "shows the seat's foul count in the seats panel" do
      expect(response.body).to include(seat_fouls).and include(foul_label)
    end

    it "numbers the foul in the move summary" do
      expect(response.body).to include(second_foul_summary)
    end
  end

  describe "GET /judge/breakdowns/:id" do
    before { get judge_breakdown_path(breakdown) }

    it "shows the seat's foul count" do
      expect(response.body).to include(foul_label)
    end

    it "numbers the foul in the move summary" do
      expect(response.body).to include(second_foul_summary)
    end
  end

  describe "POST /judge/breakdowns/:breakdown_id/moves" do
    before do
      post judge_breakdown_moves_path(breakdown),
           params: { speech_id: host_speech.id, breakdown_move: { kind: "foul", actor_seat: 3, text: "жест" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "stores a foul for the chosen player with the comment" do
      expect(host_speech.moves.reload.last).to have_attributes(kind: "foul", actor_seat: 3, text: "жест")
    end

    it "streams the refreshed foul count" do
      expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(seat)}_fouls"))
        .and include(I18n.t("game_breakdowns.editor.fouls", count: 3))
    end
  end
end
