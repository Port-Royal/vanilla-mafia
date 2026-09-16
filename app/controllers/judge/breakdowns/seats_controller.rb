class Judge::Breakdowns::SeatsController < Judge::BreakdownBaseController
  before_action :set_breakdown
  before_action :set_seat

  def update
    @seat.assign_attributes(seat_params)
    @seat.player = Player.find_by(name: @seat.name)
    return render_invalid unless @seat.save

    respond_with_editor
  end

  private

  def render_invalid
    load_editor_data
    render "judge/breakdowns/edit", status: :unprocessable_content
  end

  def set_breakdown
    @breakdown = GameBreakdown.find(params[:breakdown_id])
  end

  def set_seat
    @seat = @breakdown.seats.find(params[:id])
  end

  # Unknown role codes are dropped rather than passed to the foreign key.
  def seat_params
    permitted = params.require(:breakdown_seat).permit(:name, :role_code)
    permitted[:role_code] = nil unless Role.exists?(code: permitted[:role_code])
    permitted
  end
end
