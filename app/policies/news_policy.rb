# frozen_string_literal: true

class NewsPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.published? || user.can_manage_news?
  end

  def create?
    user.can_manage_news?
  end

  def update?
    user.can_manage_news?
  end

  def destroy?
    user.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.can_manage_news?
        scope.all
      else
        scope.where(status: :published)
      end
    end
  end
end
