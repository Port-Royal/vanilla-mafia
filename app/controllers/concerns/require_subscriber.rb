module RequireSubscriber
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :require_subscriber_grant
  end

  private

  def require_subscriber_grant
    head :not_found unless current_user.subscriber? || current_user.admin?
  end
end
