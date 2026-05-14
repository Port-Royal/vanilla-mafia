class TelegramAuthor < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :player, optional: true

  validates :telegram_user_id, presence: true, uniqueness: true, numericality: { only_integer: true }

  def self.whitelisted?(telegram_user_id)
    exists?(telegram_user_id: telegram_user_id)
  end

  def self.find_by_telegram_user_id(telegram_user_id)
    find_by(telegram_user_id: telegram_user_id)
  end

  def ensure_user!
    return user if user.present?
    return nil if player.nil?

    stub = User.find_or_create_telegram_stub!(player)
    update!(user: stub)
    stub
  end
end
