class Role < ApplicationRecord
  self.primary_key = :code

  has_many :game_participations, foreign_key: :role_code, primary_key: :code

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
