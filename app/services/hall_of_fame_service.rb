class HallOfFameService
  Result = Data.define(:player_awards, :staff_awards)

  def self.call
    new.call
  end

  def call
    Result.new(
      player_awards: grouped_awards(Award.for_players),
      staff_awards: grouped_awards(Award.for_staff)
    )
  end

  private

  def grouped_awards(scope)
    PlayerAward.includes(:player, :award).where(award: scope).ordered.load.group_by(&:player)
  end
end
