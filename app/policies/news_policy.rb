# frozen_string_literal: true

class NewsPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.published? || managed?
  end

  def create?
    managed?
  end

  def update?
    managed?
  end

  def destroy?
    user.present? && user.admin?
  end

  private

  def managed?
    user.present? && user.can_manage_news?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return default_scope unless user.present?
      return scope.all if user.can_manage_news?

      default_scope
    end

    private

    def default_scope
      scope.where(status: :published)
    end
  end
end
