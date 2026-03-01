class DisputeMailer < ApplicationMailer
  def dispute_filed(claim)
    @player = claim.player
    current_owner = User.find_by(player_id: @player.id)
    return unless current_owner

    @disputant = claim.user

    I18n.with_locale(current_owner.locale) do
      mail(
        to: current_owner.email,
        subject: t(".subject", player_name: @player.name)
      )
    end
  end
end
