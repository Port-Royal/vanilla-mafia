class Announcement < ApplicationRecord
  has_many :announcement_dismissals, dependent: :destroy

  validates :version, presence: true
  validates :message, presence: true
end
