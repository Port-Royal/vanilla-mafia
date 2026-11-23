class HallOfFameService
  Result = Data.define(:player_entries, :staff_entries)

  # A player's card on the hall of fame page: every award record of theirs, newest competition first.
  Entry = Data.define(:player, :player_awards) do
    def awards_count
      player_awards.size
    end

    # One badge per award, in the awards' position order (unplaced awards last, then by id).
    def badges
      player_awards.group_by(&:award)
        .sort_by { |award, _| [ award.position ? 0 : 1, award.position, award.id ] }
        .map { |award, wins| AwardBadge.new(award:, competitions: wins.filter_map(&:competition)) }
    end
  end

  def self.call
    new.call
  end

  def call
    Result.new(
      player_entries: entries(grouped_awards(Award.for_players)),
      staff_entries: entries(grouped_awards(Award.for_staff))
    )
  end

  private

  def grouped_awards(scope)
    PlayerAward
      .includes(:competition, player: { photo_attachment: :blob }, award: { icon_attachment: :blob })
      .where(award: scope)
      .left_joins(:competition)
      .order(Arel.sql("competitions.started_on DESC NULLS LAST"), :id)
      .load
      .group_by(&:player)
  end

  # Most award records first; ties keep the order of each player's latest award.
  def entries(grouped)
    grouped.each_with_index
      .sort_by { |(_, awards), index| [ -awards.size, index ] }
      .map { |(player, awards), _| Entry.new(player:, player_awards: awards) }
  end
end
