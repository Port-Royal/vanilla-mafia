class SaveGameProtocolService
  Result = Data.define(:success, :game, :errors)

  def self.call(game:, game_params:, participations_params:)
    new(game, game_params, participations_params).call
  end

  def initialize(game, game_params, participations_params)
    @game = game
    @game_params = game_params
    @participations_params = participations_params
  end

  def call
    ActiveRecord::Base.transaction do
      @game.assign_attributes(@game_params)
      @game.save!
      save_participations!
      Result.new(success: true, game: @game, errors: [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success: false, game: @game, errors: [ e.message ])
  end

  private

  def save_participations!
    assign_seats_to_legacy_participations!

    @participations_params.each do |seat_str, attrs|
      seat = seat_str.to_i
      player_name = attrs[:player_name].to_s.strip
      next if player_name.blank?

      player = Player.find_or_create_by!(name: player_name)
      participation = @game.game_participations.find_or_initialize_by(seat: seat)
      participation.player = player
      participation.role_code = attrs[:role_code].presence
      participation.plus = attrs[:plus].presence
      participation.minus = attrs[:minus].presence
      participation.best_move = attrs[:best_move].presence
      participation.win = attrs[:win] == "1"
      participation.first_shoot = attrs[:first_shoot] == "1"
      participation.notes = attrs[:notes].presence
      participation.save!
    end

    remove_cleared_seats!
  end

  def assign_seats_to_legacy_participations!
    unseated = @game.game_participations.where(seat: nil).order(:id)
    return if unseated.empty?

    taken = @game.game_participations.where.not(seat: nil).pluck(:seat)
    free = (1..10).to_a - taken
    unseated.each_with_index do |gp, idx|
      break unless free[idx]

      gp.update!(seat: free[idx])
    end
  end

  def remove_cleared_seats!
    filled_seats = @participations_params.select { |_, attrs| attrs[:player_name].to_s.strip.present? }.keys.map(&:to_i)
    @game.game_participations.where(seat: 1..10).where.not(seat: filled_seats).destroy_all
  end
end
