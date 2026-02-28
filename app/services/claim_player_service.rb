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
    return Result.new(success: false, claim: nil, error: :claim_already_exists) if claim_exists?

    if approve_immediately?
      approve_claim
    else
      create_pending_claim
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    Result.new(success: false, claim: nil, error: :claim_already_exists)
  end

  private

  def claim_exists?
    PlayerClaim.exists?(user: @user, player: @player)
  end

  def approve_immediately?
    !PlayerClaim.require_approval? || @user.admin?
  end

  def approve_claim
    ActiveRecord::Base.transaction do
      @user.lock!
      @player.lock!
      claim = PlayerClaim.create!(user: @user, player: @player, status: "approved")
      @user.update!(player: @player)
      Result.new(success: true, claim: claim, error: nil)
    end
  end

  def create_pending_claim
    ActiveRecord::Base.transaction do
      @user.lock!
      @player.lock!
      claim = PlayerClaim.create!(user: @user, player: @player, status: "pending")
      Result.new(success: true, claim: claim, error: nil)
    end
  end
end
