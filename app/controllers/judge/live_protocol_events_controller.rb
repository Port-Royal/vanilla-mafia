class Judge::LiveProtocolEventsController < Judge::LiveProtocolBaseController
  EVENT_FIELDS = [ :client_id, :action_id, :kind, :phase, :day_number, :actor_seat, :text, { target_seats: [], metadata: {} } ].freeze
  REJECTED = [ ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ActiveRecord::InvalidForeignKey,
               SyncProtocolEventService::RevertForbidden ].freeze

  rescue_from(*REJECTED) { |error| render json: { errors: [ error.message ] }, status: :unprocessable_content }

  def create
    return head :conflict unless @game.with_lock { with_overlay_broadcasts { save_new_events } }

    render json: { saved: event_params.pluck(:client_id).uniq }
  end

  def destroy
    status = @game.with_lock { with_overlay_broadcasts { destroy_action } }
    return head status unless status == :unprocessable_content

    render json: { errors: [ "action cannot be deleted" ] }, status:
  end

  private

  # Decided under the lock, so an overlapping retry sees what the first request wrote. A retry after
  # a lost response must succeed even when the batch finished the game, so the game state only
  # matters when something is actually new.
  def save_new_events
    events = new_events
    return false if events.any? && !@game.in_progress?

    events.each { |attrs| save_event(attrs) }
    true
  end

  def destroy_action
    events = @game.game_protocol_events.where(action_id: params[:action_id]).order(:position).to_a
    return :no_content if events.empty?
    return :conflict unless @game.in_progress?
    return :unprocessable_content unless GameProtocolEvent.removable_group?(events)

    events.reverse_each do |event|
      SyncProtocolEventService.revert(event)
      event.destroy!
    end
    :no_content
  end

  # Viewers see who stands for the vote, the shots and, with roles public, the checks. A change
  # to any of them goes out once the write commits.
  def with_overlay_broadcasts
    before = overlay_lists
    result = yield
    overlay_lists.each do |scope, payload|
      next if payload == before[scope]

      ActiveRecord.after_all_transactions_commit { GameProtocolChannel.broadcast_to(@game, { scope: scope }.merge(payload)) }
    end
    result
  end

  def overlay_lists
    { "nominees" => { seats: @game.current_nominees }, "shots" => { shots: @game.public_shots }, "checks" => { checks: @game.public_checks },
      "fouls" => { fouls: @game.public_fouls } }
  end

  def event_params
    params.permit(events: EVENT_FIELDS).fetch(:events, [])
  end

  def new_events
    known = @game.game_protocol_events.pluck(:client_id)
    event_params.uniq { |attrs| attrs[:client_id] }.reject { |attrs| known.include?(attrs[:client_id]) }
  end

  def save_event(attrs)
    position = @game.game_protocol_events.maximum(:position).to_i + 1
    SyncProtocolEventService.apply(@game.game_protocol_events.create!(attrs.merge(position:)))
  end
end
