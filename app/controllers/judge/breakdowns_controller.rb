class Judge::BreakdownsController < Judge::BreakdownBaseController
  GAME_OPTIONS_LIMIT = 200

  before_action :set_breakdown, only: [ :show, :edit, :update ]

  def index
    @breakdowns = GameBreakdown.includes(:author).ordered.load
    @results = @breakdowns.to_h { |breakdown| [ breakdown.id, GameBreakdown::Timeline.new(breakdown).result ] }
  end

  def new
    @breakdown = GameBreakdown.new(played_on: Date.current)
    load_form_data
  end

  def create
    @breakdown = GameBreakdown.new(breakdown_params)
    @breakdown.author = current_user

    if @breakdown.save
      redirect_to edit_judge_breakdown_path(@breakdown), notice: t("game_breakdowns.create.success")
    else
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  def show
    load_timeline
  end

  def edit
    load_editor_data
  end

  def update
    return render_invalid unless @breakdown.update(breakdown_params)

    respond_with_editor
  end

  private

  def render_invalid
    load_editor_data
    render :edit, status: :unprocessable_content
  end

  def set_breakdown
    @breakdown = GameBreakdown.find(params[:id])
  end


  def load_form_data
    @games = Game.recent.includes(competition: :parent).limit(GAME_OPTIONS_LIMIT)
  end

  def breakdown_params
    params.require(:game_breakdown)
          .permit(:title, :played_on, :source, :video_url, :judge_name, :roles_mode, :game_id, :manual_result, :conclusion)
  end
end
