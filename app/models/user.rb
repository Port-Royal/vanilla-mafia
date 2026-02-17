class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  def admin?
    admin
  end
end
