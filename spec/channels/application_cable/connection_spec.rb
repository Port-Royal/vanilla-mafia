require "rails_helper"

RSpec.describe ApplicationCable::Connection do
  before do
    allow_any_instance_of(described_class).to receive(:env).and_return("warden" => warden)
  end

  context "when a user is signed in" do
    let_it_be(:user) { create(:user) }
    let(:warden) { instance_double(Warden::Proxy, user: user) }

    it "identifies the connection with the Warden user" do
      connect "/cable"

      expect(connection.current_user).to eq(user)
    end
  end

  context "when no user is signed in" do
    let(:warden) { instance_double(Warden::Proxy, user: nil) }

    it "permits an anonymous connection with a nil current_user" do
      connect "/cable"

      expect(connection.current_user).to be_nil
    end
  end
end
