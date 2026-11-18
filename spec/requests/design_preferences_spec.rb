require "rails_helper"

RSpec.describe DesignPreferencesController, type: :request do
  describe "PATCH /design_preference" do
    shared_examples "a design choice" do
      context "when choosing the new design" do
        before { patch design_preference_path, params: { design: "new" } }

        it { expect(response).to redirect_to(root_path) }
        it { expect(cookies[:design]).to eq("new") }
      end

      context "when choosing the old design" do
        before { patch design_preference_path, params: { design: "old" } }

        it { expect(response).to redirect_to(root_path) }
        it { expect(cookies[:design]).to eq("old") }
      end

      context "with an unknown design" do
        before { patch design_preference_path, params: { design: "beta" } }

        it { expect(response).to redirect_to(root_path) }
        it { expect(cookies[:design]).to be_nil }
      end

      context "without a design param" do
        before { patch design_preference_path }

        it { expect(response).to redirect_to(root_path) }
        it { expect(cookies[:design]).to be_nil }
      end
    end

    context "when guest" do
      it_behaves_like "a design choice"
    end

    context "when signed-in user" do
      let_it_be(:user) { create(:user, locale: "ru") }

      before { sign_in user }

      it_behaves_like "a design choice"

      context "when choosing a design" do
        it "does not change the user record" do
          expect { patch design_preference_path, params: { design: "new" } }
            .not_to(change { user.reload.attributes })
        end
      end
    end

    context "when the cookie is set" do
      let(:set_cookie) { response.headers["Set-Cookie"] }

      before do
        freeze_time
        patch design_preference_path, params: { design: "new" }
      end

      after { unfreeze_time }

      it "expires in one year" do
        expect(set_cookie).to include("expires=#{1.year.from_now.httpdate}")
      end
    end

    context "with a referer on the site" do
      before do
        patch design_preference_path, params: { design: "new" }, headers: { "HTTP_REFERER" => hall_path }
      end

      it { expect(response).to redirect_to(hall_path) }
    end

    context "with an unknown design and a referer on the site" do
      before do
        patch design_preference_path, params: { design: "beta" }, headers: { "HTTP_REFERER" => hall_path }
      end

      it { expect(response).to redirect_to(hall_path) }
    end

    context "with a foreign referer" do
      before do
        patch design_preference_path, params: { design: "new" },
                                      headers: { "HTTP_REFERER" => "https://evil.example/x" }
      end

      it { expect(response).to redirect_to(root_path) }
    end

    context "with an unknown design and a foreign referer" do
      before do
        patch design_preference_path, params: { design: "beta" },
                                      headers: { "HTTP_REFERER" => "https://evil.example/x" }
      end

      it { expect(response).to redirect_to(root_path) }
    end
  end
end
