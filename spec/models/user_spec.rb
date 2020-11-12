describe User do
  it { is_expected.to have_many :memberships }
  it { is_expected.to have_many(:groupings).through(:memberships) }
  it { is_expected.to have_many(:notes).dependent(:destroy) }
  it { is_expected.to have_many :accepted_memberships }
  it { is_expected.to have_many(:key_pairs).dependent(:destroy) }
  it { is_expected.to validate_presence_of :user_name }
  it { is_expected.to validate_presence_of :last_name }
  it { is_expected.to validate_presence_of :first_name }
  it { is_expected.to allow_value('Student').for(:type) }
  it { is_expected.to allow_value('Admin').for(:type) }
  it { is_expected.to allow_value('Ta').for(:type) }
  it { is_expected.not_to allow_value('OtherTypeOfUser').for(:type) }
  it { is_expected.to validate_exclusion_of(:user_name).in_array([User::TEST_STUDENT_USER_NAME]) }

  describe 'uniqueness validation' do
    subject { create :admin }
    it { is_expected.to validate_uniqueness_of :user_name }
  end

  context 'A good User model' do
    it 'should be able to create a student' do
      create(:student)
    end
    it 'should be able to create an admin' do
      create(:admin)
    end
    it 'should be able to create a grader' do
      create(:ta)
    end
  end

  context 'User creation validations' do
    before :each do
      new_user = { user_name: '   ausername   ',
                   first_name: '   afirstname ',
                   last_name: '   alastname  ' }
      @user = Student.new(new_user)
      @user.type = 'Student'
    end

    it 'should strip all strings with white space from user name' do
      expect(@user.save).to eq true
      expect(@user.user_name).to eq 'ausername'
      expect(@user.first_name).to eq 'afirstname'
      expect(@user.last_name).to eq 'alastname'
    end
  end

  context 'Creating user with user name test_student' do
    let(:user_params) do
      { user_name: User::TEST_STUDENT_USER_NAME, first_name: 'test', last_name: 'student', type: user_type }
    end
    let(:user) { User.new(user_params) }
    let(:expected_error_message) { { user_name: ['is reserved'] } }
    context 'when the user type is Admin' do
      let(:user_type) { 'Admin' }
      it 'should raise an error' do
        expect(user.save).to eq false
        expect(user.errors.messages).to eq(expected_error_message)
      end
    end
    context 'when the user type is Ta' do
      let(:user_type) { 'Ta' }
      it 'should raise an error' do
        expect(user.save).to eq false
        expect(user.errors.messages).to eq(expected_error_message)
      end
    end
    context 'when the user type is Student' do
      let(:user_type) { 'Student' }
      it 'should raise an error' do
        expect(user.save).to eq false
        expect(user.errors.messages).to eq(expected_error_message)
      end
    end
    context 'when the user type is TestStudent' do
      let(:user_type) { 'TestStudent' }
      it 'should create the user' do
        expect(user.save).to eq true
        expect(user.user_name).to eq(User::TEST_STUDENT_USER_NAME)
      end
    end
  end

  context 'The repository permissions file' do
    context 'should be upated' do
      it 'when creating an admin' do
        expect(Repository.get_class).to receive(:__update_permissions).once
        create(:admin)
      end
      it 'when destroying an admin' do
        admin = create(:admin)
        expect(Repository.get_class).to receive(:__update_permissions).once
        admin.destroy
      end
    end
    context 'should not be updated' do
      it 'when creating a ta' do
        expect(Repository.get_class).not_to receive(:__update_permissions)
        create(:ta)
      end
      it 'when destroying a ta without memberships' do
        ta = create(:ta)
        expect(Repository.get_class).not_to receive(:__update_permissions)
        ta.destroy
      end
      it 'when creating a student' do
        expect(Repository.get_class).not_to receive(:__update_permissions)
        create(:student)
      end
      it 'when destroying a student without memberships' do
        student = create(:student)
        expect(Repository.get_class).not_to receive(:__update_permissions)
        student.destroy
      end
    end
  end
end
