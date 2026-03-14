class TelegramAuthor < ApplicationRecord
  belongs_to :user, optional: true

  validates :telegram_user_id, presence: true, uniqueness: true, numericality: { only_integer: true }

  def self.whitelisted?(telegram_user_id)
    exists?(telegram_user_id: telegram_user_id)
  end

  def self.find_by_telegram_user_id(telegram_user_id)
    find_by(telegram_user_id: telegram_user_id)
  end
end
