class AutosaveGameProtocolService
  Result = Data.define(:success, :errors)

  GAME_FIELDS = %w[game_number played_on name result judge competition_id].freeze
  PARTICIPATION_FIELDS = %w[player_name role_code plus minus best_move first_shoot notes].freeze

  def self.call(game:, scope:, field:, value:, seat: nil)
    new(game, scope, field, value, seat).call
  end

  def initialize(game, scope, field, value, seat)
    @game = game
    @scope = scope
    @field = field
    @value = value
    @seat = seat&.to_i
  end

  def call
    case @scope
    when "game"
      update_game_field
    when "participation"
      update_participation_field
    else
      Result.new(success: false, errors: [ "Unknown scope: #{@scope}" ])
    end
  end

  private

  def update_game_field
    return Result.new(success: false, errors: [ "Field not allowed: #{@field}" ]) unless GAME_FIELDS.include?(@field)

    @game.assign_attributes(@field => @value)
    if @game.save
      Result.new(success: true, errors: [])
    else
      Result.new(success: false, errors: @game.errors.full_messages)
    end
  end

  def update_participation_field
    return Result.new(success: false, errors: [ "Field not allowed: #{@field}" ]) unless PARTICIPATION_FIELDS.include?(@field)
    return Result.new(success: false, errors: [ "Invalid seat" ]) unless @seat.in?(1..10)

    if @field == "player_name"
      update_player_name
    else
      update_existing_participation
    end
  end

  def update_player_name
    name = @value.to_s.strip

    if name.blank?
      remove_participation
    else
      upsert_participation(name)
    end
  end

  def remove_participation
    participation = @game.game_participations.find_by(seat: @seat)
    participation&.destroy!
    Result.new(success: true, errors: [])
  end

  def upsert_participation(player_name)
    player = Player.find_or_create_by!(name: player_name)
    participation = @game.game_participations.find_or_initialize_by(seat: @seat)
    participation.player = player
    if participation.save
      Result.new(success: true, errors: [])
    else
      Result.new(success: false, errors: participation.errors.full_messages)
    end
  end

  def update_existing_participation
    participation = @game.game_participations.find_by(seat: @seat)
    return Result.new(success: false, errors: [ "No participation at seat #{@seat}" ]) unless participation

    participation.assign_attributes(@field => @value)
    if participation.save
      Result.new(success: true, errors: [])
    else
      Result.new(success: false, errors: participation.errors.full_messages)
    end
  end
end
