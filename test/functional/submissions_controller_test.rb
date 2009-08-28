require File.dirname(__FILE__) + '/authenticated_controller_test'
require 'fastercsv'

class SubmissionsControllerTest < AuthenticatedControllerTest

  fixtures  :users, :assignments, :rubric_criteria, :marks, :submission_rules
  set_fixture_class :rubric_criteria => RubricCriterion

  def setup
    @controller = SubmissionsController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    
    # login before testing
    @admin = users(:olm_admin_1)
    @grader = users(:ta1)
    @request.session['uid'] = @admin.id
    @student = users(:student1)
    # stub assignment
    @new_assignment = {  
      'name'          => '', 
      'message'       => '', 
      'group_min'     => '',
      'group_max'     => '',
      'due_date(1i)'  => '',
      'due_date(2i)'  => '',
      'due_date(2i)'  => '',
      'due_date(2i)'  => '',
    }
    setup_group_fixture_repos
    
  end
  
  def teardown
    destroy_repos
  end
  
  def test_students_can_use_file_manager
    get_as(@student, :file_manager, {:id => Assignment.first.id})
    assert_response :success
  end
  
  def test_students_can_populate_file_manager
    get_as(@student, :populate_file_manager, {:id => Assignment.first.id})
    assert_response :success
  end
  
  def test_students_can_add_files
    file_1 = fixture_file_upload('files/Shapes.java', 'text/java')
    file_2 = fixture_file_upload('files/TestShapes.java', 'text/java')
    assignment = Assignment.first
    assert @student.has_accepted_grouping_for?(assignment.id)
    post_as(@student, :update_files, {:id => assignment.id, :new_files => [file_1, file_2]})
    assert_redirected_to :action => 'file_manager'
    # Check to see if the file was added
    grouping = @student.accepted_grouping_for(assignment.id)
    revision = grouping.group.repo.get_latest_revision
    files = revision.files_at_path(assignment.repository_folder)
    assert_not_nil files['Shapes.java']
    assert_not_nil files['TestShapes.java']
  end
  
  def test_students_can_replace_files
    assignment = Assignment.first
    assert @student.has_accepted_grouping_for?(assignment.id)
    grouping = @student.accepted_grouping_for(assignment.id)
     
    repo = grouping.group.repo
    txn = repo.get_transaction('markus')
    txn.add(File.join(assignment.repository_folder,'Shapes.java'), 'Content of Shapes.java')
    txn.add(File.join(assignment.repository_folder, 'TestShapes.java'), 'Content of TestShapes.java')
    repo.commit(txn)
    
    revision = repo.get_latest_revision
    old_files = revision.files_at_path(assignment.repository_folder)
    old_file_1 = old_files['Shapes.java']
    old_file_2 = old_files['TestShapes.java']

    file_1 = fixture_file_upload('files/Shapes.java', 'text/java')
    file_2 = fixture_file_upload('files/TestShapes.java', 'text/java')

    post_as(@student, :update_files, {:id => assignment.id, :replace_files => {'Shapes.java' => file_1, 'TestShapes.java' => file_2}, :file_revisions => {'Shapes.java' => old_file_1.from_revision, 'TestShapes.java' => old_file_2.from_revision}})

    assert_redirected_to :action => 'file_manager'
    # Check to see if the file was added
    grouping = @student.accepted_grouping_for(assignment.id)
    revision = grouping.group.repo.get_latest_revision
    files = revision.files_at_path(assignment.repository_folder)
    assert_not_nil files['Shapes.java']
    assert_not_nil files['TestShapes.java']
    
    # Test to make sure that the contents were successfully updated
    file_1.rewind
    file_2.rewind
    file_1_new_contents = repo.download_as_string(files['Shapes.java'])
    file_2_new_contents = repo.download_as_string(files['TestShapes.java'])
    
    assert_equal file_1.read, file_1_new_contents
    assert_equal file_2.read, file_2_new_contents
    
  end 
  
  def test_students_can_delete_files
    assignment = Assignment.first
    assert @student.has_accepted_grouping_for?(assignment.id)
    grouping = @student.accepted_grouping_for(assignment.id)
     
    repo = grouping.group.repo
    txn = repo.get_transaction('markus')
    txn.add(File.join(assignment.repository_folder,'Shapes.java'), 'Content of Shapes.java')
    txn.add(File.join(assignment.repository_folder, 'TestShapes.java'), 'Content of TestShapes.java')
    repo.commit(txn)
    revision = repo.get_latest_revision
    old_files = revision.files_at_path(assignment.repository_folder)
    old_file_1 = old_files['Shapes.java']
    old_file_2 = old_files['TestShapes.java']
    
    post_as(@student, :update_files, {:id => assignment.id, :delete_files => {'Shapes.java' => true}, :file_revisions => {'Shapes.java' => old_file_1.from_revision, 'TestShapes.java' => old_file_2.from_revision}})

    repo = grouping.group.repo
    revision = repo.get_latest_revision
    files = revision.files_at_path(assignment.repository_folder)
    assert_not_nil files['TestShapes.java']
    assert_nil files['Shapes.java']
  end
  
  def test_student_cant_add_file_that_exists
    assignment = Assignment.first
    assert @student.has_accepted_grouping_for?(assignment.id)
    grouping = @student.accepted_grouping_for(assignment.id)
     
    repo = grouping.group.repo
    txn = repo.get_transaction('markus')
    txn.add(File.join(assignment.repository_folder,'Shapes.java'), 'Content of Shapes.java')
    txn.add(File.join(assignment.repository_folder, 'TestShapes.java'), 'Content of TestShapes.java')
    repo.commit(txn)
    original_revision = repo.get_latest_revision
  
    file_1 = fixture_file_upload('files/Shapes.java', 'text/java')
    file_2 = fixture_file_upload('files/TestShapes.java', 'text/java')
    assignment = Assignment.first
    assert @student.has_accepted_grouping_for?(assignment.id)
    post_as(@student, :update_files, {:id => assignment.id, :new_files => [file_1, file_2]})
    assert_redirected_to :action => 'file_manager'
    # Check to see if the file was added
    grouping = @student.accepted_grouping_for(assignment.id)
    revision = grouping.group.repo.get_latest_revision
    files = revision.files_at_path(assignment.repository_folder)
    assert_not_nil files['Shapes.java']
    assert_not_nil files['TestShapes.java']
    assert_not_nil flash[:update_conflicts]
  end
  
  def test_student_cant_replace_file_if_out_of_sync
    assert false
  end
  
  def test_student_cant_replace_file_with_diff_name_file
    assert false
  end

  def test_students_cant_use_repo_browser
    get_as(@student, :repo_browser, {:id => Grouping.last.id})
    assert_response :missing
  end
  
  def test_graders_can_use_repo_browser
    get_as(@grader, :repo_browser, {:id => Grouping.last.id})
    assert_response :success
  end
  
  def test_instructors_can_use_repo_browser
    get_as(@admin, :repo_browser, {:id => Grouping.last.id})
    assert_response :success
  end
 
  # TODO:  TEST REPO BROWSER HERE
  
  def test_students_cant_populate_repo_browser
    get_as(@student, :populate_repo_browser, {:id => Grouping.first.id})
    assert_response :missing
  end
  
  def test_graders_can_populate_repo_browser
    get_as(@grader, :populate_repo_browser, {:id => Grouping.first.id})
    assert_response :success
  end
  
  def test_instructors_can_populate_repo_browser
    get_as(@admin, :populate_repo_browser, {:id => Grouping.first.id})
    assert_response :success
  end
  
  # TODO: TEST POPULATE REPO BROWSER HERE
 
  def test_get_svn_export_commands
    assert false
  end
  
  def test_get_detailed_csv_report
    assert false
  end
  
  def test_get_simple_csv_report
    assert false
  end
  
  def test_can_release_completed_results
    assert false
  end
  
  def test_can_release_multiple_results
    assert false
  end
  
  def test_cant_release_non_completed_results
    assert false
  end
  
  def test_cant_release_non_existent_results
    assert false
  end
  
  def test_can_unrelease_any_results
    assert false
  end
  
  def test_can_download_file_from_root
    assert false
  end
  
  def test_can_download_file_from_subdirectory
    assert false
  end
  
  def test_can_download_file_from_previous_revision
    assert false
  end
  

    
end
