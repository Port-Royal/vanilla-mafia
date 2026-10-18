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
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Result.new(success: false, game: @game, errors: [ e.message ])
  end

  private

  def save_participations!
    assign_seats_to_legacy_participations!

    @participations_params.each do |seat, attrs|
      player_name = attrs[:player_name].to_s.strip
      next if player_name.blank?

      player = Player.find_or_create_by!(name: player_name)
      participation = @game.game_participations.find_or_initialize_by(seat: seat)
      participation.player = player
      participation.role_code = attrs[:role_code]
      participation.plus = attrs[:plus]
      participation.minus = attrs[:minus]
      participation.best_move = attrs[:best_move]
      participation.first_shoot = attrs[:first_shoot] == "1"
      participation.best_move_seats = attrs[:best_move_seats]
      participation.notes = attrs[:notes].presence
      status = attrs[:status]
      participation.status = status if GameParticipation.statuses.key?(status)
      participation.save!
    end

    remove_cleared_seats!
  end

  def assign_seats_to_legacy_participations!
    taken = @game.game_participations.where.not(seat: nil).pluck(:seat)
    free = (1..10).to_a - taken
    @game.game_participations.where(seat: nil).order(:id).zip(free) do |participation, seat|
      participation.update!(seat: seat)
    end
  end

  def remove_cleared_seats!
    filled_seats = @participations_params.select { |_, attrs| attrs[:player_name].present? }.keys
    @game.game_participations.where.not(seat: nil).where.not(seat: filled_seats).destroy_all
  end
end
