class Grant < ApplicationRecord
  CODES = %w[user judge editor admin].freeze

  has_many :user_grants, dependent: :destroy
  has_many :users, through: :user_grants

  validates :code, presence: true, inclusion: { in: CODES }, uniqueness: true
end
