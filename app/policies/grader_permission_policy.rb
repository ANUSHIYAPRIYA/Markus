# Contains policy for all the grader permissions in the grader_permissions table
class GraderPermissionPolicy < ApplicationPolicy
  def create_delete_annotations?
    user.grader_permission.create_delete_annotations
  end

  def manage_submissions?
    user.grader_permission.manage_submissions
  end

  def manage_assessments?
    user.grader_permission.manage_assessments
  end

  def grader_run_tests?
    user.grader_permission.run_tests
  end
end
