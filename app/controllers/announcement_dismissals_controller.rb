class AnnouncementDismissalsController < ApplicationController
  before_action :authenticate_user!

  def create
    announcement_ids = Array(params[:announcement_ids]).map(&:to_i)
    already_dismissed = current_user.announcement_dismissals.where(announcement_id: announcement_ids).pluck(:announcement_id)
    new_ids = announcement_ids - already_dismissed

    new_ids.each do |announcement_id|
      current_user.announcement_dismissals.create!(announcement_id: announcement_id)
    end

    head :ok
  end
end
