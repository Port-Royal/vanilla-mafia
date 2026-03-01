class DisputePlayerService
  Result = Data.define(:success, :claim, :error)

  def self.call(user:, player:, evidence:)
    new(user, player, evidence).call
  end

  def initialize(user, player, evidence)
    @user = user
    @player = player
    @evidence = evidence
  end

  def call
    return Result.new(success: false, claim: nil, error: :evidence_blank) if @evidence.blank?
    return Result.new(success: false, claim: nil, error: :already_has_player) if @user.claimed_player?
    return Result.new(success: false, claim: nil, error: :player_not_claimed) unless @player.claimed?
    return Result.new(success: false, claim: nil, error: :already_pending) if @user.pending_dispute?
    return Result.new(success: false, claim: nil, error: :dispute_already_exists) if dispute_exists?

    create_dispute
  rescue ActiveRecord::RecordNotUnique
    Result.new(success: false, claim: nil, error: :dispute_already_exists)
  rescue ActiveRecord::RecordInvalid
    error = error_from_current_state
    Result.new(success: false, claim: nil, error: error)
  end

  private

  def dispute_exists?
    PlayerClaim.exists?(user: @user, player: @player)
  end

  def create_dispute
    claim = nil

    ActiveRecord::Base.transaction do
      @user.lock!
      @player.lock!

      return Result.new(success: false, claim: nil, error: :already_has_player) if @user.claimed_player?
      return Result.new(success: false, claim: nil, error: :player_not_claimed) unless @player.claimed?
      return Result.new(success: false, claim: nil, error: :already_pending) if @user.pending_dispute?

      claim = PlayerClaim.create!(
        user: @user,
        player: @player,
        status: "pending",
        dispute: true,
        evidence: @evidence
      )
    end

    DisputeMailer.dispute_filed(claim).deliver_later

    Result.new(success: true, claim: claim, error: nil)
  end

  def error_from_current_state
    ActiveRecord::Base.transaction do
      @user.lock!
      @player.lock!

      return :already_has_player if @user.claimed_player?
      return :player_not_claimed unless @player.claimed?
      return :dispute_already_exists if dispute_exists?

      :dispute_already_exists
    end
  end
end
