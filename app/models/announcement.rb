class Announcement < ApplicationRecord
  has_many :announcement_dismissals, dependent: :destroy

  validates :version, presence: true
  validates :message, presence: true

  scope :visible_to, ->(user) {
    grant_codes = user.grants.pluck(:code)
    where(grant_code: [ nil, *grant_codes ])
  }

  scope :undismissed_by, ->(user) {
    where.not(id: AnnouncementDismissal.where(user: user).select(:announcement_id))
  }

  scope :for_user, ->(user) {
    visible_to(user).undismissed_by(user)
  }
end
