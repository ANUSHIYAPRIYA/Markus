describe AssignmentsController do
  # copied from the controller
  DEFAULT_FIELDS = [:short_identifier, :description,
                    :due_date, :message, :group_min, :group_max,
                    :tokens_per_period, :allow_web_submits,
                    :student_form_groups, :remark_due_date,
                    :remark_message, :assign_graders_to_criteria,
                    :enable_test, :enable_student_tests, :allow_remarks,
                    :display_grader_names_to_students,
                    :display_median_to_students, :group_name_autogenerated,
                    :is_hidden, :vcs_submit, :has_peer_review].freeze

  let(:annotation_category) { FactoryBot.create(:annotation_category) }

  let(:example_form_params) do
    {
      is_group_assignment: true,
      is_hidden: 0,
      assignment: {
        assignment_properties_attributes: {
          scanned_exam: false, section_due_dates_type: 0, allow_web_submits: 0, vcs_submit: 0,
          display_median_to_students: 0, display_grader_names_to_students: 0, has_peer_review: 0,
          student_form_groups: 0, group_min: 1, group_max: 1, group_name_autogenerated: 1, allow_remarks: 0
        },
        submission_rule_attributes: {
          type: 'PenaltyDecayPeriodSubmissionRule',
          periods_attributes: { 999 => { deduction: 10.0, interval: 1.0, hours: 10.0, _destroy: 0, id: nil } }
        },
        description: 'Test',
        message: '',
        due_date: Time.now.to_s
      }
    }
  end

  context '#start_timed_assignment' do
    let(:assignment) { create :timed_assignment }
    context 'as a student' do
      let(:user) { create :student }
      context 'when a grouping exists' do
        let!(:grouping) { create :grouping_with_inviter, assignment: assignment, start_time: nil, inviter: user }
        it 'should respond with 302' do
          put_as user, :start_timed_assignment, params: { id: assignment.id }
          expect(response).to have_http_status :redirect
        end
        it 'should redirect to show' do
          put_as user, :start_timed_assignment, params: { id: assignment.id }
          expect(response).to redirect_to(action: :show)
        end
        it 'should update the start_time' do
          put_as user, :start_timed_assignment, params: { id: assignment.id }
          expect(grouping.reload.start_time).to be_within(5.seconds).of(Time.current)
        end
        context 'a validation fails' do
          it 'should flash an error message' do
            allow_any_instance_of(Grouping).to receive(:update).and_return false
            put_as user, :start_timed_assignment, params: { id: assignment.id }
            expect(flash[:error]).not_to be_nil
          end
        end
      end
      context 'when a grouping does not exist' do
        it 'should respond with 400' do
          put_as user, :start_timed_assignment, params: { id: assignment.id }
          expect(response).to have_http_status 400
        end
      end
    end
    context 'as an admin' do
      let(:user) { create :admin }
      it 'should respond with 400' do
        put_as user, :start_timed_assignment, params: { id: assignment.id }
        expect(response).to have_http_status 400
      end
    end
    context 'as an grader' do
      let(:user) { create :ta }
      it 'should respond with 400' do
        put_as user, :start_timed_assignment, params: { id: assignment.id }
        expect(response).to have_http_status 400
      end
    end
  end

  context '#upload' do
    before :each do
      # Authenticate user is not timed out, and has administrator rights.
      allow(controller).to receive(:session_expired?).and_return(false)
      allow(controller).to receive(:logged_in?).and_return(true)
      allow(controller).to receive(:current_user).and_return(build(:admin))
    end

    include_examples 'a controller supporting upload' do
      let(:params) { {} }
    end

    before :each do
      # We need to mock the rack file to return its content when
      # the '.read' method is called to simulate the behaviour of
      # the http uploaded file
      @file_good = fixture_file_upload('files/assignments/form_good.csv', 'text/csv')
      allow(@file_good).to receive(:read).and_return(
        File.read(fixture_file_upload('files/assignments/form_good.csv', 'text/csv'))
      )
      @file_good_yml = fixture_file_upload('files/assignments/form_good.yml', 'text/yaml')
      allow(@file_good_yml).to receive(:read).and_return(
        File.read(fixture_file_upload('files/assignments/form_good.yml', 'text/yaml'))
      )

      @file_invalid_column = fixture_file_upload('files/assignments/form_invalid_column.csv', 'text/csv')
      allow(@file_invalid_column).to receive(:read).and_return(
        File.read(fixture_file_upload('files/assignments/form_invalid_column.csv', 'text/csv'))
      )

      # This must line up with the second entry in the file_good
      @test_asn1 = 'ATest1'
      @test_asn2 = 'ATest2'
    end

    it 'accepts a valid file' do
      post :upload, params: { upload_file: @file_good }

      expect(response.status).to eq(302)
      test1 = Assignment.find_by(short_identifier: @test_asn1)
      expect(test1).to_not be_nil
      test2 = Assignment.find_by(short_identifier: @test_asn2)
      expect(test2).to_not be_nil
      expect(flash[:error]).to be_nil
      expect(flash[:success].map { |f| extract_text f }).to eq([I18n.t('upload_success',
                                                                       count: 2)].map { |f| extract_text f })
      expect(response).to redirect_to(action: 'index',
                                      controller: 'assignments')
    end

    it 'accepts a valid YAML file' do
      post :upload, params: { upload_file: @file_good_yml }

      expect(response.status).to eq(302)
      test1 = Assignment.find_by_short_identifier(@test_asn1)
      expect(test1).to_not be_nil
      test2 = Assignment.find_by_short_identifier(@test_asn2)
      expect(test2).to_not be_nil
      expect(flash[:error]).to be_nil
      expect(response).to redirect_to(action: 'index', controller: 'assignments')
    end

    it 'does not accept files with invalid columns' do
      post :upload, params: { upload_file: @file_invalid_column }

      expect(response.status).to eq(302)
      expect(flash[:error]).to_not be_empty
      test = Assignment.find_by_short_identifier(@test_asn2)
      expect(test).to be_nil
      expect(response).to redirect_to(action: 'index',
                                      controller: 'assignments')
    end
  end

  context 'CSV_Downloads' do
    before :each do
      # Authenticate user is not timed out, and has administrator rights.
      allow(controller).to receive(:session_expired?).and_return(false)
      allow(controller).to receive(:logged_in?).and_return(true)
      allow(controller).to receive(:current_user).and_return(build(:admin))
    end

    let(:csv_options) do
      { type: 'text/csv', filename: 'assignments.csv', disposition: 'attachment' }
    end
    let!(:assignment) { create(:assignment) }

    it 'responds with appropriate status' do
      get :download, params: { format: 'csv' }
      expect(response.status).to eq(200)
    end

    # parse header object to check for the right disposition
    it 'sets disposition as attachment' do
      get :download, params: { format: 'csv' }
      d = response.header['Content-Disposition'].split.first
      expect(d).to eq 'attachment;'
    end

    it 'expects a call to send_data' do
      # generate the expected csv string
      csv_data = []
      DEFAULT_FIELDS.map do |f|
        csv_data << assignment.send(f)
      end
      new_data = csv_data.join(',') + "\n"
      expect(@controller).to receive(:send_data).with(new_data, csv_options) {
        # to prevent a 'missing template' error
        @controller.head :ok
      }
      get :download, params: { format: 'csv' }
    end

    # parse header object to check for the right content type
    it 'returns text/csv type' do
      get :download, params: { format: 'csv' }
      expect(response.media_type).to eq 'text/csv'
    end

    # parse header object to check for the right file naming convention
    it 'filename passes naming conventions' do
      get :download, params: { format: 'csv' }
      filename = response.header['Content-Disposition'].split[1].split('"').second
      expect(filename).to eq 'assignments.csv'
    end
  end

  context 'YML_Downloads' do
    let(:yml_options) do
      { type: 'text/yml', filename: 'assignments.yml', disposition: 'attachment' }
    end
    let!(:assignment) { create(:assignment) }

    before :each do
      # Authenticate user is not timed out, and has administrator rights.
      allow(controller).to receive(:session_expired?).and_return(false)
      allow(controller).to receive(:logged_in?).and_return(true)
      allow(controller).to receive(:current_user).and_return(build(:admin))
    end

    it 'responds with appropriate status' do
      get :download, params: { format: 'yml' }
      expect(response.status).to eq(200)
    end

    # parse header object to check for the right disposition
    it 'sets disposition as attachment' do
      get :download, params: { format: 'yml' }
      d = response.header['Content-Disposition'].split.first
      expect(d).to eq 'attachment;'
    end

    it 'expects a call to send_data' do
      # generate the expected yml string
      assignments = Assignment.all
      map = {}
      map[:assignments] = assignments.map do |assignment|
        m = {}
        DEFAULT_FIELDS.each do |f|
          m[f] = assignment.send(f)
        end
        m
      end
      map = map.to_yaml
      expect(@controller).to receive(:send_data).with(map, yml_options) {
        # to prevent a 'missing template' error
        @controller.head :ok
      }
      get :download, params: { format: 'yml' }
    end

    # parse header object to check for the right content type
    it 'returns text/yml type' do
      get :download, params: { format: 'yml' }
      expect(response.media_type).to eq 'text/yml'
    end

    # parse header object to check for the right file naming convention
    it 'filename passes naming conventions' do
      get :download, params: { format: 'yml' }
      filename = response.header['Content-Disposition'].split[1].split('"').second
      expect(filename).to eq 'assignments.yml'
    end
  end

  describe '#index' do
    context 'an admin' do
      let(:user) { create(:admin) }

      context 'when there are no assessments' do
        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end

      context 'where there are some assessments' do
        before :each do
          3.times { create(:assignment_with_criteria_and_results) }
          2.times { create(:grade_entry_form_with_data) }
        end

        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end
    end

    context 'a TA' do
      let(:user) { create(:ta) }
      let!(:grader_permission) { create(:grader_permission, user_id: user.id) }

      context 'when there are no assessments' do
        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end

      context 'where there are some assessments' do
        before :each do
          3.times { create(:assignment_with_criteria_and_results) }
          2.times { create(:grade_entry_form_with_data) }
        end

        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end
    end

    context 'a student' do
      let(:user) { create(:student) }

      context 'when there are no assessments' do
        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end

      context 'where there are some assessments' do
        before :each do
          3.times do
            assignment = create(:assignment_with_criteria_and_results)
            create(:accepted_student_membership, user: user, grouping: assignment.groupings.first)
          end
          2.times { create(:grade_entry_form_with_data) }
        end

        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end

      context 'where there are some assessments, including hidden assessments' do
        before :each do
          3.times do
            assignment = create(:assignment_with_criteria_and_results)
            create(:accepted_student_membership, user: user, grouping: assignment.groupings.first)
          end
          2.times { create(:grade_entry_form_with_data) }
          Assignment.first.update(is_hidden: true)
          GradeEntryForm.first.update(is_hidden: true)
        end

        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end
    end
  end

  context '#set_boolean_graders_options' do
    let!(:assignment) { create(:assignment) }
    context 'an admin' do
      let(:user) { create :admin }
      let(:value) { !assignment.assignment_properties[attribute] }

      before :each do
        post_as user, :set_boolean_graders_options,
                params: { id: assignment.id,
                          attribute: { assignment_properties_attributes: { attribute => value } } }
        assignment.reload
      end

      shared_examples 'successful tests' do
        it 'should respond with 200' do
          expect(response.status).to eq(200)
        end
        it 'should update the attribute' do
          expect(assignment.assignment_properties[attribute]).to eq(value)
        end
      end

      context 'with a valid attribute field' do
        context 'is assign_graders_to_criteria' do
          let(:attribute) { :assign_graders_to_criteria }
          it_behaves_like 'successful tests'
        end
        context 'is anonymize_groups' do
          let(:attribute) { :anonymize_groups }
          it_behaves_like 'successful tests'
        end
        context 'is hide_unassigned_criteria' do
          let(:attribute) { :hide_unassigned_criteria }
          it_behaves_like 'successful tests'
        end
      end

      context 'with an invalid attribute field' do
        let(:attribute) { :this_is_not_a_real_attribute }
        let(:value) { true }
        it 'should respond with 400' do
          expect(response.status).to eq(400)
        end
      end
    end
  end

  describe '#show' do
    let!(:assignment) { create(:assignment) }
    let!(:user) { create(:student) }

    xcontext 'when the assignment is an individual assignment' do
      it 'responds with a success and creates a new grouping' do
        assignment.update!(group_min: 1, group_max: 1)
        post_as user, :show, params: { id: assignment.id }
        assert_response :success
        expect(user.student_memberships.size).to eq 1
        expect(user.groupings.first.assignment_id).to eq assignment.id
      end
    end

    xcontext 'when the assignment is a group assignment and the student belongs to a group' do
      it 'responds with a success' do
        assignment.update!(group_min: 1, group_max: 3)
        grouping = create(:grouping_with_inviter, assignment: assignment)
        post_as grouping.inviter, :show, params: { id: assignment.id }
        assert_response :success
      end
    end

    context 'when the assignment is a group assignment and the student does not belong to a group' do
      it 'responds with a success and does not create a grouping' do
        assignment.update!(group_min: 1, group_max: 3)
        post_as user, :show, params: { id: assignment.id }
        assert_response :success

        expect(user.groupings.size).to eq 0
      end
    end

    context 'when the assignment is hidden' do
      it 'responds with a not_found status' do
        assignment.update!(is_hidden: true)
        post_as user, :show, params: { id: assignment.id }
        assert_response :not_found
      end
    end
  end

  describe '#summary' do
    shared_examples 'An authorized user viewing assignment summary' do
      context 'requests an HTML response' do
        it 'responds with a success' do
          post_as user, :summary, params: { id: assignment.id }, format: 'html'
          assert_response :success
        end
      end

      context 'requests a JSON response' do
        before do
          post_as user, :summary, params: { id: assignment.id }, format: 'json'
        end
        it 'responds with a success' do
          assert_response :success
        end

        it 'responds with the correct keys' do
          expect(response.parsed_body.keys.to_set).to eq Set[
            'data', 'criteriaColumns', 'numAssigned', 'numMarked'
          ]
        end
      end

      context 'requests a CSV response' do
        before do
          post_as user, :summary, params: { id: assignment.id }, format: 'csv'
        end
        it 'responds with a success' do
          assert_response :success
        end
      end
    end

    describe 'When the user is admin' do
      let!(:user) { create(:admin) }
      let!(:assignment) { create(:assignment) }
      include_examples 'An authorized user viewing assignment summary'
    end

    describe 'When the user is grader' do
      let!(:user) { create(:ta) }
      let!(:assignment) { create(:assignment) }
      let!(:grader_permission) { create(:grader_permission, user_id: user.id) }
      include_examples 'An authorized user viewing assignment summary'
    end
  end

  shared_examples 'An authorized user updating the assignment' do
    let(:assignment) { create :assignment }
    let(:submission_rule) { create :penalty_decay_period_submission_rule, assignment: assignment }
    let(:params) do
      example_form_params[:id] = assignment.id
      example_form_params[:assignment][:assignment_properties_attributes][:id] = assignment.id
      example_form_params[:assignment][:short_identifier] = assignment.short_identifier
      example_form_params[:assignment][:submission_rule_attributes][:periods_attributes] = submission_rule.id
      example_form_params
    end
    it 'should update an assignment without errors' do
      patch_as user, :update, params: params
    end
    shared_examples 'update assignment_properties' do |property, before, after|
      it "should update #{property}" do
        assignment.update!(property => before)
        params[:assignment][:assignment_properties_attributes][property] = after
        patch_as user, :update, params: params
        expect(assignment.reload.assignment_properties[property]).to eq after
      end
    end
    shared_examples 'update assignment' do |property, before, after|
      it "should update #{property}" do
        assignment.update!(property => before)
        params[:assignment][property] = after
        patch_as user, :update, params: params
        expect(assignment.reload[property]).to eq after
      end
    end
    it_behaves_like 'update assignment_properties', :section_due_dates_type, false, true
    it_behaves_like 'update assignment_properties', :allow_web_submits, false, true
    it_behaves_like 'update assignment_properties', :vcs_submit, false, true
    it_behaves_like 'update assignment_properties', :display_median_to_students, false, true
    it_behaves_like 'update assignment_properties', :display_grader_names_to_students, false, true
    it_behaves_like 'update assignment_properties', :has_peer_review, false, true
    it_behaves_like 'update assignment_properties', :student_form_groups, false, true
    it_behaves_like 'update assignment_properties', :group_name_autogenerated, false, true
    it_behaves_like 'update assignment_properties', :allow_remarks, false, true
    it_behaves_like 'update assignment', :description, 'AAA', 'BBB'
    it_behaves_like 'update assignment', :message, 'AAA', 'BBB'
    it_behaves_like 'update assignment', :due_date, Time.now.to_s, (Time.now - 1.hour).to_s
    it 'should update group_min and group_max when is_group_assignment is true' do
      assignment.update!(group_min: 1, group_max: 1)
      params[:assignment][:assignment_properties_attributes][:group_min] = 2
      params[:assignment][:assignment_properties_attributes][:group_max] = 3
      params[:is_group_assignment] = true
      patch_as user, :update, params: params
      assignment.reload
      expect(assignment.assignment_properties[:group_min]).to eq 2
      expect(assignment.assignment_properties[:group_max]).to eq 3
    end
    it 'should not update group_min and group_max when is_group_assignment is false' do
      assignment.update!(group_min: 1, group_max: 1)
      params[:assignment][:assignment_properties_attributes][:group_min] = 2
      params[:assignment][:assignment_properties_attributes][:group_max] = 3
      params[:is_group_assignment] = false
      patch_as user, :update, params: params
      assignment.reload
      expect(assignment.assignment_properties[:group_min]).to eq 1
      expect(assignment.assignment_properties[:group_max]).to eq 1
    end
    it 'should update duration when this is a timed assignment' do
      assignment.update!(is_timed: true, start_time: Time.now - 10.hours, duration: 10.minutes)
      params[:assignment][:assignment_properties_attributes][:duration] = { hours: 2, minutes: 20 }
      patch_as user, :update, params: params
      expect(assignment.reload.duration).to eq(2.hours + 20.minutes)
    end
    it 'should not update duration when this is a not a timed assignment' do
      assignment.update!(is_timed: false)
      params[:assignment][:assignment_properties_attributes][:duration] = { hours: 2, minutes: 20 }
      patch_as user, :update, params: params
      expect(assignment.reload.duration).to eq nil
    end
  end

  shared_examples 'An authorized user managing assignments' do
    context '#new' do
      shared_examples 'assignment_new_success' do
        it 'responds with a success' do
          expect(response).to have_http_status :success
        end
        it 'renders the new template' do
          expect(response).to render_template(:new)
        end
      end
      context 'when the assignment is a scanned assignment' do
        before do
          get_as user, :new, params: { scanned: true }
        end
        it_behaves_like 'assignment_new_success'
        it 'assigns @assignment as a scanned assignment' do
          expect(assigns(:assignment).scanned_exam).to eq true
        end
        it 'does not assign @assignment as a timed assignment' do
          expect(assigns(:assignment).is_timed).to eq false
        end
      end
      context 'when the assignment is a timed assignment' do
        before do
          get_as user, :new, params: { timed: true }
        end
        it_behaves_like 'assignment_new_success'
        it 'assigns @assignment as a timed assignment' do
          expect(assigns(:assignment).is_timed).to eq true
        end
        it 'does not assign @assignment as a scanned assignment' do
          expect(assigns(:assignment).scanned_exam).to eq false
        end
      end
      context 'when the assignment is a regular assignment' do
        before do
          get_as user, :new, params: {}
        end
        it_behaves_like 'assignment_new_success'
        it 'does not assign @assignment as a timed assignment' do
          expect(assigns(:assignment).is_timed).to eq false
        end
        it 'does not assign @assignment as a scanned assignment' do
          expect(assigns(:assignment).scanned_exam).to eq false
        end
      end
    end
    context '#create' do
      let(:params) { example_form_params }
      it 'should create an assignment without errors' do
        post_as user, :create, params: params
      end
      it 'should respond with 200' do
        post_as user, :create, params: params
        expect(response).to have_http_status 200
      end
      shared_examples 'create assignment_properties' do |property, after|
        it "should create #{property}" do
          params[:assignment][:assignment_properties_attributes][property] = after
          post_as user, :create, params: params
          expect(assigns(:assignment).assignment_properties[property]).to eq after
        end
      end
      shared_examples 'create assignment' do |property, after|
        it "should create #{property}" do
          params[:assignment][property] = after
          post_as user, :create, params: params
          expect(assigns(:assignment)[property]).to eq after
        end
      end
      it_behaves_like 'create assignment_properties', :section_due_dates_type, true
      it_behaves_like 'create assignment_properties', :allow_web_submits, true
      it_behaves_like 'create assignment_properties', :vcs_submit, true
      it_behaves_like 'create assignment_properties', :display_median_to_students, true
      it_behaves_like 'create assignment_properties', :display_grader_names_to_students, true
      it_behaves_like 'create assignment_properties', :has_peer_review, true
      it_behaves_like 'create assignment_properties', :student_form_groups, true
      it_behaves_like 'create assignment_properties', :group_name_autogenerated, true
      it_behaves_like 'create assignment_properties', :allow_remarks, true
      it_behaves_like 'create assignment_properties', :group_min, 2
      it_behaves_like 'create assignment_properties', :group_min, 3
      it_behaves_like 'create assignment', :description, 'BBB'
      it_behaves_like 'create assignment', :message, 'BBB'
      it_behaves_like 'create assignment', :due_date, (Time.now - 1.hour).to_s
      it 'should set duration when this is a timed assignment' do
        params[:assignment][:assignment_properties_attributes][:duration] = { hours: 2, minutes: 20 }
        params[:assignment][:assignment_properties_attributes][:start_time] = Time.now - 10.hours
        params[:assignment][:assignment_properties_attributes][:is_timed] = true
        post_as user, :create, params: params
        expect(assigns(:assignment).duration).to eq(2.hours + 20.minutes)
      end
      it 'should not set duration when this is a not a timed assignment' do
        params[:assignment][:assignment_properties_attributes][:duration] = { hours: 2, minutes: 20 }
        params[:assignment][:assignment_properties_attributes][:start_time] = Time.now - 10.hours
        params[:assignment][:assignment_properties_attributes][:is_timed] = false
        post_as user, :create, params: params
        expect(assigns(:assignment).duration).to eq nil
      end
    end
    context '#edit' do
      let(:assignment) { create(:assignment) }
      before { post_as user, :edit, params: { id: assignment.id } }
      it('should respond with 200') { expect(response.status).to eq 200 }
    end
    context '#batch_runs' do
      let(:assignment) { create(:assignment_for_tests) }
      before { get_as user, :batch_runs, params: { id: assignment.id } }
      it('should respond with 200') { expect(response.status).to eq 200 }
    end
  end

  describe 'When the user is admin' do
    let!(:user) { create(:admin) }
    include_examples 'An authorized user updating the assignment'
    include_examples 'An authorized user managing assignments'
  end

  describe 'When the user is grader' do
    context 'When the grader is allowed to manage assignments' do
      let!(:user) { create(:ta) }
      before do
        create(:grader_permission, user_id: user.id, manage_assignments: true)
      end
      include_examples 'An authorized user updating the assignment'
      include_examples 'An authorized user managing assignments'
    end
  end
  
  describe 'When the grader is not allowed to manage assignments' do
    let(:grader) { create(:ta) }
    before do
      create(:grader_permission, user_id: grader.id, manage_assignments: false)
    end
    context '#new' do
      before { get_as grader, :new }
      it('should respond with 403') { expect(response.status).to eq 403 }
    end
    context '#create' do
      let(:params) { { short_identifier: 'A0', description: 'Ruby on rails', due_date: Time.now } }
      before { post_as grader, :create, params: params }
      it('should respond with 403') { expect(response.status).to eq 403 }
    end
    context '#edit' do
      let(:assignment) { create(:assignment) }
      before { post_as grader, :edit, params: { id: assignment.id } }
      it('should respond with 403') { expect(response.status).to eq 403 }
    end
    context '#batch_runs' do
      let(:assignment) { create(:assignment_for_tests) }
      before { get_as grader, :batch_runs, params: { id: assignment.id } }
      it('should respond with 403') { expect(response.status).to eq 403 }
    end
  end
  describe '#starter_file' do
    before(:each) { get_as user, :starter_file, params: params }
    let(:assignment) { create :assignment }
    let(:params) { { id: assignment.id } }
    context 'an admin' do
      let(:user) { create :admin }
      context 'the assignment exists' do
        it 'should render the starter_file view' do
          expect(response).to render_template(:starter_file)
        end
        it 'should render the assignment_content layout' do
          expect(response).to render_template(:assignment_content)
        end
        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end
      context 'the assignment does not exist' do
        let(:params) { { id: -1 } }
        it 'should return a 404 error' do
          is_expected.to respond_with(:not_found)
        end
      end
    end
    context 'a grader' do
      let(:user) { create :ta }
      it 'should return a 404 error' do
        is_expected.to respond_with(:not_found)
      end
    end
    context 'a student' do
      let(:user) { create :student }
      it 'should return a 404 error' do
        is_expected.to respond_with(:not_found)
      end
    end
  end
  describe '#populate_starter_file_manager' do
    before { get_as user, :populate_starter_file_manager, params: params }
    let(:assignment) { create :assignment }
    let(:params) { { id: assignment.id } }
    context 'an admin' do
      let(:user) { create :admin }
      it 'should contain the right values' do
        expected = { starterfileType: assignment.starter_file_type,
                     defaultStarterFileGroup: '',
                     files: [],
                     sections: [] }
        expect(JSON.parse(response.body)).to eq(expected.transform_keys(&:to_s))
      end
      context 'the file data' do
        let(:starter_file_group) { create :starter_file_group_with_entries, assignment: assignment }
        let(:params) { { id: starter_file_group.assignment.id } }
        it 'should contain the right keys' do
          file_data = JSON.parse(response.body)['files'].first.keys
          expect(file_data).to contain_exactly('id', 'name', 'entry_rename', 'use_rename', 'files')
        end
        it 'should contain the right values' do
          file_data = JSON.parse(response.body)['files'].first.slice('id', 'name', 'entry_rename', 'use_rename')
          grp = starter_file_group
          expected = { id: grp.id, name: grp.name, entry_rename: grp.entry_rename, use_rename: grp.use_rename }
          expect(file_data).to eq(expected.transform_keys(&:to_s))
        end
        it 'should contain the right file data' do
          file_names = JSON.parse(response.body)['files']
                           .first['files']
                           .map { |h| h['key'].split(File::Separator).first }
          expected_entries = starter_file_group.starter_file_entries.pluck('path')
          expect(file_names.to_set).to contain_exactly(*expected_entries)
        end
      end
      context 'the section data' do
        let(:starter_file_group) { create :starter_file_group, assignment: assignment }
        let(:section) { create :section }
        let(:ssfg) { create :section_starter_file_group, starter_file_group: starter_file_group, section: section }
        let(:params) { { id: ssfg.starter_file_group.assignment.id } }
        it 'should contain the right values' do
          file_data = JSON.parse(response.body)['sections'].first
          expected = { section_id: section.id,
                       section_name: section.name,
                       group_id: starter_file_group.id,
                       group_name: starter_file_group.name }
          expect(file_data).to eq(expected.transform_keys(&:to_s))
        end
      end
    end
    context 'a grader' do
      let(:user) { create :ta }
      it 'should return a 404 error' do
        is_expected.to respond_with(:not_found)
      end
    end
    context 'a student' do
      let(:user) { create :student }
      it 'should return a 404 error' do
        is_expected.to respond_with(:not_found)
      end
    end
  end
  describe '#update_starter_file' do
    subject { post_as user, :update_starter_file, params: params }
    let(:assignment) { create :assignment }
    let(:starter_file_group1) do
      create :starter_file_group, assignment: assignment, name: 'name', entry_rename: 'name', use_rename: false
    end
    let(:starter_file_group2) { create :starter_file_group, assignment: assignment }
    let(:section) { create :section }
    let(:base_params) do
      { id: assignment.id,
        assignment: { starter_file_type: :shuffle,
                      default_starter_file_group_id: starter_file_group2.id },
        sections: [{ section_id: section.id, group_id: starter_file_group1.id }],
        starter_file_groups: [{ id: starter_file_group1.id,
                                name: 'changed_name',
                                entry_rename: 'changed_rename',
                                use_rename: true }] }
    end
    let(:params) { base_params }
    context 'an admin' do
      let(:user) { create :admin }
      it 'should update starter_file_type' do
        expect { subject }.to change { assignment.reload.starter_file_type }.from('simple').to('shuffle')
      end
      it 'should update default_starter_file_group_id' do
        expect { subject }.to(
          change { assignment.reload.default_starter_file_group_id }.from(nil).to(starter_file_group2.id)
        )
      end
      context 'when a section exists' do
        it 'should update section starter file mappings' do
          expect { subject }.to(
            change { section.starter_file_group_for(assignment) }.from(starter_file_group2).to(starter_file_group1)
          )
        end
      end
      context 'when a section does not exist' do
        let(:params) do
          base_params[:sections].first[:section_id] = section.id + 1
          base_params
        end
        it 'should not update section starter file mappings' do
          subject
          expect(section.starter_file_group_for(assignment)).to eq starter_file_group2
        end
      end
      context 'when updating starter file attributes' do
        it 'should update name' do
          expect { subject }.to change { starter_file_group1.reload.name }.to('changed_name')
        end
        it 'should update entry_rename' do
          expect { subject }.to change { starter_file_group1.reload.entry_rename }.to('changed_rename')
        end
        it 'should update use_rename' do
          expect { subject }.to change { starter_file_group1.reload.use_rename }.to(true)
        end
        context 'when the starter file group does not exist' do
          let(:params) do
            base_params[:starter_file_groups].first[:id] = starter_file_group1.id + 1
            base_params
          end
          it 'should not update anything' do
            grp = starter_file_group1
            expect { subject }.not_to(change { [grp.reload.name, grp.entry_rename, grp.use_rename] })
          end
        end
      end
    end
    context 'a grader' do
      let(:user) { create :ta }
      it 'should return a 404 error' do
        subject
        expect(response.status).to eq(404)
      end
    end
    context 'a student' do
      let(:user) { create :student }
      it 'should return a 404 error' do
        subject
        expect(response.status).to eq(404)
      end
    end
  end
  describe '#download_starter_file_mappings' do
    subject { get_as user, :download_starter_file_mappings, params: params }
    let(:assignment) { create :assignment }
    let(:params) { { id: assignment.id } }
    context 'an admin' do
      let(:user) { create :admin }
      let!(:starter_file_group) { create :starter_file_group_with_entries, assignment: assignment }
      let!(:grouping) { create :grouping_with_inviter, assignment: assignment }
      let(:params) { { id: starter_file_group.assignment.id } }
      it 'should contain mappings' do
        expect(@controller).to receive(:send_data) do |file_content|
          mappings = file_content.split("\n")[1..-1].map { |m| m.split(',') }.sort
          expected = StarterFileEntry.pluck(:path).map { |p| [grouping.group.group_name, starter_file_group.name, p] }
          expect(mappings).to eq expected.sort
        end
        subject
      end
    end
    context 'a grader' do
      let(:user) { create :ta }
      it 'should return a 404 error' do
        subject
        expect(response.status).to eq(404)
      end
    end
    context 'a student' do
      let(:user) { create :student }
      it 'should return a 404 error' do
        subject
        expect(response.status).to eq(404)
      end
    end
  end
end
