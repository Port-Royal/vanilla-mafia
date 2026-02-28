class ClaimPlayerService
  Result = Data.define(:success, :claim, :error)

  def self.call(user:, player:)
    new(user, player).call
  end

  def initialize(user, player)
    @user = user
    @player = player
  end

  def call
    return Result.new(success: false, claim: nil, error: :already_has_player) if @user.claimed_player?
    return Result.new(success: false, claim: nil, error: :player_already_claimed) if @player.claimed?

    if approve_immediately?
      approve_claim
    else
      create_pending_claim
    end
  end

  private

  def approve_immediately?
    !PlayerClaim.require_approval? || @user.admin?
  end

  def approve_claim
    ActiveRecord::Base.transaction do
      claim = PlayerClaim.create!(user: @user, player: @player, status: "approved")
      @user.update!(player: @player)
      Result.new(success: true, claim: claim, error: nil)
    end
  end

  def create_pending_claim
    claim = PlayerClaim.create!(user: @user, player: @player, status: "pending")
    Result.new(success: true, claim: claim, error: nil)
  end
end
