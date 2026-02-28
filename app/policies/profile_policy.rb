# frozen_string_literal: true

class ProfilePolicy < ApplicationPolicy
  def edit?
    user.player_id == record.id
  end

  def update?
    user.player_id == record.id
  end
end
