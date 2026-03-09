# frozen_string_literal: true

class NewsPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.published? || user&.can_manage_news?
  end

  def create?
    user&.can_manage_news?
  end

  def update?
    user&.can_manage_news?
  end

  def destroy?
    user&.admin?
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
