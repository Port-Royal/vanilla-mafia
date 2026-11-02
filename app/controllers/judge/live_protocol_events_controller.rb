class Judge::LiveProtocolEventsController < Judge::LiveProtocolBaseController
  EVENT_FIELDS = [ :client_id, :action_id, :kind, :phase, :day_number, :actor_seat, :text, { target_seats: [], metadata: {} } ].freeze
  REJECTED = [ ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ActiveRecord::InvalidForeignKey,
               SyncProtocolEventService::RevertForbidden ].freeze

  rescue_from(*REJECTED) { |error| render json: { errors: [ error.message ] }, status: :unprocessable_content }

  # A retry after a lost response must succeed even when the batch finished the game,
  # so the game state only matters when something is actually new.
  def create
    events = new_events
    return head :conflict if events.any? && !@game.in_progress?

    @game.with_lock { events.each { |attrs| save_event(attrs) } }

    render json: { saved: event_params.pluck(:client_id).uniq }
  end

  def destroy
    events = @game.game_protocol_events.where(action_id: params[:action_id]).order(:position).to_a
    return head :no_content if events.empty?
    return head :conflict unless @game.in_progress?
    return render json: { errors: [ "action cannot be deleted" ] }, status: :unprocessable_content unless GameProtocolEvent.removable_group?(events)

    @game.with_lock do
      events.reverse_each do |event|
        SyncProtocolEventService.revert(event)
        event.destroy!
      end
    end

    head :no_content
  end

  private

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
