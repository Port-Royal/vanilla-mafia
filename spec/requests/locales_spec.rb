require "rails_helper"

RSpec.describe LocalesController, type: :request do
  describe "PATCH /locale" do
    context "when guest" do
      it "sets cookie and redirects for valid locale" do
        patch locale_path, params: { locale: "en" }

        expect(response).to redirect_to(root_path)
        expect(cookies[:locale]).to eq("en")
      end

      it "skips cookie for invalid locale" do
        patch locale_path, params: { locale: "xx" }

        expect(response).to redirect_to(root_path)
        expect(cookies[:locale]).to be_nil
      end
    end

    context "when signed-in user" do
      let(:user) { create(:user, locale: "ru") }

      before { sign_in user }

      it "updates user locale and sets cookie for valid locale" do
        patch locale_path, params: { locale: "en" }

        expect(response).to redirect_to(root_path)
        expect(cookies[:locale]).to eq("en")
        expect(user.reload.locale).to eq("en")
      end

      it "skips both for invalid locale" do
        patch locale_path, params: { locale: "xx" }

        expect(response).to redirect_to(root_path)
        expect(user.reload.locale).to eq("ru")
        expect(cookies[:locale]).to be_nil
      end
    end

    context "with referer header" do
      it "redirects back to referring page" do
        patch locale_path, params: { locale: "en" },
              headers: { "HTTP_REFERER" => hall_path }

        expect(response).to redirect_to(hall_path)
      end
    end
  end
end
