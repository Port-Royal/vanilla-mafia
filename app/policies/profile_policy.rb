# frozen_string_literal: true

class ProfilePolicy < ApplicationPolicy
  def update?
    user.player_id == record.id
  end
end
