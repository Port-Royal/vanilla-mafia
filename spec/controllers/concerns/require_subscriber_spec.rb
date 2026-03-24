require "rails_helper"

RSpec.describe RequireSubscriber do
  let(:controller_class) do
    Class.new(ApplicationController) do
      include RequireSubscriber

      def index
        head :ok
      end
    end
  end

  let(:controller) { controller_class.new }

  describe "#require_subscriber_grant" do
    before do
      allow(controller).to receive(:head)
    end

    context "when user has subscriber grant" do
      let(:user) { create(:user, :subscriber) }

      before { allow(controller).to receive(:current_user).and_return(user) }

      it "does not block access" do
        controller.send(:require_subscriber_grant)
        expect(controller).not_to have_received(:head)
      end
    end

    context "when user has admin grant" do
      let(:user) { create(:user, :admin) }

      before { allow(controller).to receive(:current_user).and_return(user) }

      it "does not block access" do
        controller.send(:require_subscriber_grant)
        expect(controller).not_to have_received(:head)
      end
    end

    context "when user has no subscriber or admin grant" do
      let(:user) { create(:user) }

      before { allow(controller).to receive(:current_user).and_return(user) }

      it "returns not found" do
        controller.send(:require_subscriber_grant)
        expect(controller).to have_received(:head).with(:not_found)
      end
    end
  end
end
