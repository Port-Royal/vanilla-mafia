class Avo::Actions::ResetPassword < Avo::BaseAction
  self.name = "Reset Password"
  self.visible = -> { view.show? }

  def handle(records:, **_args)
    records.each(&:send_reset_password_instructions)

    succeed("Password reset email sent")
  end
end
