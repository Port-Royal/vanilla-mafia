require "rails_helper"

RSpec.describe "Judge::Breakdowns mafia acquaintance" do
  let_it_be(:admin) { create(:user, :admin) }

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:roles_mode) { "open" }
  let(:breakdown) { create(:game_breakdown, author: admin, roles_mode: roles_mode, mafia_acquaintance: acquaintance) }
  let(:acquaintance) { "Стреляем 3, 7, 1" }
  let(:zero_round) { breakdown.phases.find_by!(position: 0) }
  let(:label) { GameBreakdown.human_attribute_name(:mafia_acquaintance) }
  let(:field) { 'name="game_breakdown[mafia_acquaintance]"' }

  before { sign_in admin }

  describe "GET /judge/breakdowns/:id/edit" do
    before { get edit_judge_breakdown_path(breakdown) }

    context "when roles are open" do
      let(:positions) do
        [ I18n.t("game_breakdowns.editor.seats_panel"), field, %(id="#{ActionView::RecordIdentifier.dom_id(zero_round)}") ]
          .map { |marker| response.body.index(marker) }
      end

      it "offers the field with the stored text" do
        expect(response.body).to include(field).and include(acquaintance)
      end

      it "places the block after the seats and before the zero round" do
        expect(positions).to eq(positions.compact.sort)
      end
    end

    context "when roles are closed" do
      let(:roles_mode) { "closed" }

      it "hides the field" do
        expect(response.body).not_to include(field)
      end
    end
  end

  describe "PATCH /judge/breakdowns/:id" do
    let(:acquaintance) { nil }

    it "stores the text" do
      patch judge_breakdown_path(breakdown), params: { game_breakdown: { mafia_acquaintance: "Первым стреляем 5" } }
      expect(breakdown.reload.mafia_acquaintance).to eq("Первым стреляем 5")
    end

    it "streams the block so a roles mode change shows or hides it" do
      patch judge_breakdown_path(breakdown),
            params: { game_breakdown: { roles_mode: "closed" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include('target="breakdown_mafia_acquaintance"')
    end

    context "when only the text changes in a stream request" do
      before do
        patch judge_breakdown_path(breakdown),
              params: { game_breakdown: { mafia_acquaintance: "Первым стреляем 5" } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "answers with no content so the field being typed in is not re-rendered" do
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe "GET /judge/breakdowns/:id" do
    before { get judge_breakdown_path(breakdown) }

    context "when roles are open and the text is filled in" do
      it "shows the text" do
        expect(response.body).to include(label).and include(acquaintance)
      end

      it "places it before the zero round" do
        expect(response.body.index(acquaintance)).to be < response.body.index(I18n.t("game_breakdowns.timeline.zero_round"))
      end
    end

    context "when the text is blank" do
      let(:acquaintance) { "" }

      it "hides the block" do
        expect(response.body).not_to include(label)
      end
    end

    context "when roles are closed" do
      let(:roles_mode) { "closed" }

      it "hides the block" do
        expect(response.body).not_to include(acquaintance)
      end
    end
  end
end
