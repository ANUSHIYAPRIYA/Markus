require File.dirname(__FILE__) + '/authenticated_controller_test'
require 'shoulda'
require 'admins_controller'

class AdminsControllerTest < AuthenticatedControllerTest

   fixtures :all

   def setup
     @admin = users(:olm_admin_1)
     setup_group_fixture_repos
   end

   def teardown
     destroy_repos
   end


  # Replace this with your real tests.
   def test_index_without_user
    get :index
    assert_redirected_to :action => "login", :controller => "main"
  end

  def test_index
    get_as(@admin, :index)
    assert_response :success
  end

  def test_create
    post_as(@admin, :create, :user => {:user_name => 'Essai01', :last_name => 'ESSAI', :first_name => 'essai'})
    assert_redirected_to :action => "index"
    a = Admin.find_by_user_name('Essai01')
    assert_not_nil a
  end

  def test_update
    admin = users(:olm_admin_2)
    post_as(@admin, :update, :user => {:id => admin.id, :last_name => 'ESSAI', :first_name => 'essai'})
    assert_response :redirect
  end


  def test_edit
    admin = users(:olm_admin_2)
    get_as(@admin, :edit, :id => admin.id)
    assert_response :success
  end

end
