class Announcement < ApplicationRecord
  validates :version, presence: true
  validates :message, presence: true
end
