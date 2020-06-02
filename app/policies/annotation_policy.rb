class AnnotationPolicy < ApplicationPolicy
  def add_existing_annotation?
    user.admin? || (user.ta? && GraderPermissions.find_by(user_id: user.id).create_delete_annotations)
  end
end