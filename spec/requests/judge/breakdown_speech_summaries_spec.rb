require "rails_helper"

RSpec.describe "Judge::Breakdowns speech summaries" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }

  let(:breakdown) { create(:game_breakdown, author: admin) }
  let(:zero_round) { breakdown.phases.find_by!(position: 0) }
  let(:regular) { speech(zero_round, 1) }
  let(:field) { %(name="breakdown_speech[summary]") }
  let(:summary_marker) { "data-speech-summary" }

  before { sign_in admin }

  describe "PATCH /judge/breakdowns/:breakdown_id/speeches/:id" do
    let(:params) { { breakdown_speech: { summary: "Мирный, просит голосовать за 5", speaker_seat: 9 } } }

    context "when sent from the autosave form" do
      before { patch judge_breakdown_speech_path(breakdown, regular), params: params, headers: { "Accept" => "text/vnd.turbo-stream.html" } }

      it "stores the gist of the speech" do
        expect(regular.reload.summary).to eq("Мирный, просит голосовать за 5")
      end

      it "changes nothing but the summary" do
        expect(regular.reload.speaker_seat).to eq(1)
      end

      it "answers without content so the textarea keeps the focus" do
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when sent without JavaScript" do
      before { patch judge_breakdown_speech_path(breakdown, regular), params: params }

      it "goes back to the editor" do
        expect(response).to redirect_to(edit_judge_breakdown_path(breakdown))
      end
    end

    context "when the speech belongs to another breakdown" do
      let(:other) { speech(create(:game_breakdown, author: admin).phases.find_by!(position: 0), 2) }

      before { patch judge_breakdown_speech_path(breakdown, other), params: params }

      it "is not found" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /judge/breakdowns/:id/edit" do
    before do
      regular.update!(summary: "Подозревает 7")
      get edit_judge_breakdown_path(breakdown)
    end

    it "offers the summary field inside the speech block with the stored text" do
      block = response.body[%r{<div id="#{ActionView::RecordIdentifier.dom_id(regular)}".*?Подозревает 7}m]
      expect(block).to include(field)
    end

    it "gives the field an id unique to the speech" do
      expect(response.body).to include(%(id="#{ActionView::RecordIdentifier.dom_id(regular)}_breakdown_speech_summary"))
    end
  end

  describe "GET /judge/breakdowns/:id" do
    let(:round) { vote(zero_round, "revote") }

    before do
      regular.update!(summary: "Подозревает 7")
      speech(zero_round, 4, kind: "justification", round: round).update!(summary: "Я мирный")
      speech(zero_round, 5)
      get judge_breakdown_path(breakdown)
    end

    it "shows a regular speech's summary" do
      expect(response.body).to include("Подозревает 7")
    end

    it "shows a justification speech's summary" do
      expect(response.body).to include("Я мирный")
    end

    it "leaves no trace for an empty summary" do
      expect(response.body.scan(summary_marker).size).to eq(2)
    end
  end
end
