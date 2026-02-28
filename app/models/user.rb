class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  belongs_to :player, optional: true

  validates :player_id, uniqueness: true, allow_nil: true

  def admin?
    admin
  end

  def claimed_player?
    player_id.present?
  end
end
