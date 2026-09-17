# frozen_string_literal: true

# A breakdown is created through the judge editor, which also builds its ten seats and the zero round,
# so Avo offers everything except creation.
class GameBreakdownPolicy < ApplicationPolicy
  def create?
    false
  end
end
