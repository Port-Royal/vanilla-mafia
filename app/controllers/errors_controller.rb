class ErrorsController < ActionController::Base
  layout "application"

  def show
    render status: params[:code]
  end
end
