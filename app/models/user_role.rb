class UserRole < ApplicationRecord
  ROLES = %w[user judge editor admin].freeze

  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :role, uniqueness: { scope: :user_id }
end
