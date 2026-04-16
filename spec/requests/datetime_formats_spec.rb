require "rails_helper"

RSpec.describe DatetimeFormatsController, type: :request do
  describe "PATCH /datetime_format" do
    context "when guest" do
      it "sets cookie and redirects for valid format" do
        patch datetime_format_path, params: { datetime_format: "iso" }

        expect(response).to redirect_to(root_path)
        expect(cookies[:datetime_format]).to eq("iso")
      end

      it "skips cookie for invalid format" do
        patch datetime_format_path, params: { datetime_format: "bogus" }

        expect(response).to redirect_to(root_path)
        expect(cookies[:datetime_format]).to be_nil
      end

      it "skips cookie for missing format" do
        patch datetime_format_path

        expect(response).to redirect_to(root_path)
        expect(cookies[:datetime_format]).to be_nil
      end
    end

    context "when signed-in user" do
      let(:user) { create(:user, datetime_format: "european_24h") }

      before { sign_in user }

      it "updates user and sets cookie for valid format" do
        patch datetime_format_path, params: { datetime_format: "us_12h" }

        expect(response).to redirect_to(root_path)
        expect(cookies[:datetime_format]).to eq("us_12h")
        expect(user.reload.datetime_format).to eq("us_12h")
      end

      it "skips both for invalid format" do
        patch datetime_format_path, params: { datetime_format: "bogus" }

        expect(response).to redirect_to(root_path)
        expect(user.reload.datetime_format).to eq("european_24h")
        expect(cookies[:datetime_format]).to be_nil
      end
    end

    context "with referer header" do
      it "redirects back to referring page" do
        patch datetime_format_path, params: { datetime_format: "iso" },
              headers: { "HTTP_REFERER" => hall_path }

        expect(response).to redirect_to(hall_path)
      end
    end
  end
end
