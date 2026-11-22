class ErrorsController < ActionController::Base
  layout "application"

  def show
    allowed_codes = %w[404 422 500]
    requested_code = request.path_parameters[:code].to_s
    @code = allowed_codes.include?(requested_code) ? requested_code : "500"

    return render "errors/redesign/show", status: @code if helpers.new_design?

    render status: @code
  end
end
