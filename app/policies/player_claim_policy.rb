# frozen_string_literal: true

class PlayerClaimPolicy < ApplicationPolicy
  def create?
    !user.nil? && !user.claimed_player? && !user.pending_claim?
  end
end
