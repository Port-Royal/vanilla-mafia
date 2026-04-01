# frozen_string_literal: true

class NewsPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    visible? || managed?
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

  def visible?
    record.published? && record.published_at.present? && record.published_at <= Time.current
  end

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
      scope.visible
    end
  end
end
