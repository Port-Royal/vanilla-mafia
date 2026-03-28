class Judge::ProtocolsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_protocol_access!
  before_action :set_game, only: [ :edit, :update, :autosave ]

  def index
    @in_progress_games = Game.in_progress.includes(:competition).ordered
  end

  def new
    @game = Game.new(played_on: Date.current)
    @game.judge = current_user.player.name if current_user.claimed_player?
    @participations = 10.times.map { |i| GameParticipation.new(seat: i + 1, role_code: "peace") }
    load_form_data
  end

  def create
    @game = Game.new
    result = SaveGameProtocolService.call(
      game: @game,
      game_params: game_params,
      participations_params: participations_params
    )

    if result.success
      redirect_to after_save_path(@game), notice: t("game_protocols.create.success")
    else
      @participations = build_participations_from_params
      load_form_data
      flash.now[:error] = result.errors.join(", ")
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @participations = load_participations
    load_form_data
  end

  def autosave
    result = AutosaveGameProtocolService.call(
      game: @game,
      scope: params[:scope],
      field: params[:field],
      value: params[:value],
      seat: params[:seat]
    )

    if result.success
      broadcast_protocol_update

      render json: { success: true }
    else
      render json: { success: false, errors: result.errors }, status: :unprocessable_content
    end
  end

  def update
    result = SaveGameProtocolService.call(
      game: @game,
      game_params: game_params,
      participations_params: participations_params
    )

    if result.success
      redirect_to after_save_path(@game), notice: t("game_protocols.update.success")
    else
      @participations = build_participations_from_params
      load_form_data
      flash.now[:error] = result.errors.join(", ")
      render :edit, status: :unprocessable_content
    end
  end

  private

  def broadcast_protocol_update
    payload = { scope: params[:scope], field: params[:field], value: params[:value] }
    payload[:seat] = params[:seat].to_i if params[:seat].present?
    GameProtocolChannel.broadcast_to(@game, payload)
  end

  def after_save_path(game)
    game.in_progress? ? edit_judge_protocol_path(game) : game_path(game)
  end

  def require_protocol_access!
    head :not_found unless current_user.can_manage_protocols?
  end

  def set_game
    @game = Game.find(params[:id])
  end

  def load_form_data
    @competitions = Competition.where.not(kind: :season).ordered
    @roles = Role.all
    @players = Player.order(:name)
  end

  def game_params
    params.require(:game).permit(:game_number, :played_on, :name, :result, :judge, :competition_id)
  end

  def participations_params
    permitted_keys = (1..10).map { |i| [ i.to_s, [ :player_name, :role_code, :plus, :minus, :best_move, :first_shoot, :notes ] ] }
    params.require(:participations).permit(permitted_keys.to_h)
  end

  def load_participations
    all = @game.game_participations.includes(:player, :role).order(:seat, :id)
    seated = all.select(&:seat).index_by(&:seat)

    unseated = all.reject(&:seat)
    free_seats = (1..10).to_a - seated.keys
    unseated.each_with_index do |gp, idx|
      break unless free_seats[idx]

      gp.seat = free_seats[idx]
      seated[gp.seat] = gp
    end

    (1..10).map { |seat| seated[seat] || GameParticipation.new(seat: seat) }
  end

  def build_participations_from_params
    pp = participations_params
    10.times.map do |i|
      seat = i + 1
      attrs = pp[seat.to_s] || {}
      gp = GameParticipation.new(seat: seat)

      player_name = attrs[:player_name].presence
      if player_name
        gp.player = Player.find_by(name: player_name) || Player.new(name: player_name)
      end

      gp.role_code = attrs[:role_code].presence
      gp.plus = attrs[:plus].presence
      gp.minus = attrs[:minus].presence
      gp.best_move = attrs[:best_move].presence
      gp.first_shoot = attrs[:first_shoot] == "1"
      gp.notes = attrs[:notes].presence
      gp
    end
  end
end
