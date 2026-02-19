class HallOfFameService
  Result = Data.define(:player_awards, :staff_awards)

  def self.call
    new.call
  end

  def call
    Result.new(
      player_awards: PlayerAward.includes(:player, :award).where(award: Award.for_players).ordered.load,
      staff_awards: PlayerAward.includes(:player, :award).where(award: Award.for_staff).ordered.load
    )
  end
end
