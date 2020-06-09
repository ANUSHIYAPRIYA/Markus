class AutomatedTestPolicy < ApplicationPolicy
  default_rule :manage?
  alias_rule :student_interface?, :get_test_runs_students?, :execute_test_run?, to: :student_access?

  def student_access?
    user.student?
  end

  def manage?
    user.admin? || (user.ta? && allowed_to?(:manage_assignments?, with: GraderPermissionPolicy))
  end
end