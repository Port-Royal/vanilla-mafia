# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Actions::ResetPassword do
  subject(:action) { described_class.new }

  describe "#handle" do
    let_it_be(:user) { create(:user) }

    it "sends reset password instructions to the user" do
      expect(user).to receive(:send_reset_password_instructions)

      action.handle(records: [ user ])
    end

    it "sets a success message" do
      allow(user).to receive(:send_reset_password_instructions)

      action.handle(records: [ user ])

      messages = action.response[:messages]
      expect(messages).to include(hash_including(type: :success, body: "Password reset email sent"))
    end

    it "handles multiple records" do
      user2 = create(:user)

      allow(user).to receive(:send_reset_password_instructions)
      allow(user2).to receive(:send_reset_password_instructions)

      action.handle(records: [ user, user2 ])

      expect(user).to have_received(:send_reset_password_instructions)
      expect(user2).to have_received(:send_reset_password_instructions)
    end
  end
end
