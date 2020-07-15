class AssignmentPolicy < ApplicationPolicy
  default_rule :manage?
  alias_rule :batch_runs?, :stop_test? , to: :run_and_stop_test?
  def run_tests?
    check?(:can_run_tests?) &&
    check?(:enabled?) &&
    check?(:test_groups_exist?) &&
    (!user.student? || check?(:tokens_released?))
  end

  def enabled?
    record.enable_test && (!user.student? || record.enable_student_tests)
  end

  def test_groups_exist?
    record.test_groups.exists?
  end

  def tokens_released?
    Time.current >= record.token_start_date
  end

  def before_due_date?
    !record.submission_rule.can_collect_now?
  end

  def create_group?
    check?(:collection_date_passed?) &&
      check?(:students_form_groups?) &&
      check?(:not_yet_in_group?)
  end

  def work_alone?
    details[:group_min] = record.group_min
    record.group_min == 1
  end

  def collection_date_passed?
    !record.past_collection_date?(user.section)
  end

  def students_form_groups?
    record.student_form_groups && !record.invalid_override
  end

  def not_yet_in_group?
    !user.has_accepted_grouping_for?(record.id)
  end

  def autogenerate_group_name?
    record.group_name_autogenerated
  end

  def manage?
    user.admin? || (user.ta? && allowed_to?(:manage_assignments?, with: GraderPermissionPolicy))
  end

  def can_run_tests?
    user.admin? || (user.ta? && allowed_to?(:grader_run_tests?, with: GraderPermissionPolicy)) || user.student?
  end

  def view_pr_review?
    user.admin? || user.ta?
  end

  def summary?
    user.admin? || user.ta?
  end

  def run_and_stop_test?
    user.admin? || (user.ta? && allowed_to?(:grader_run_tests?, with: GraderPermissionPolicy))
  end
end
