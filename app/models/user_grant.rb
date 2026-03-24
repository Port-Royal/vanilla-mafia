class UserGrant < ApplicationRecord
  belongs_to :user
  belongs_to :grant

  validates :grant_id, uniqueness: { scope: :user_id }
end
