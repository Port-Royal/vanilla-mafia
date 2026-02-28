# frozen_string_literal: true

class ProfilePolicy < ApplicationPolicy
  def edit?
    user.player_id == record.id
  end

  def update?
    return false if user.nil?

    user.player_id == record.id
  end
end
