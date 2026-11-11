# frozen_string_literal: true

class FamilyPolicy < ApplicationPolicy
  def update?
    user&.super_admin?
  end

  def destroy?
    user&.super_admin?
  end
end
