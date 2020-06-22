describe ExamTemplatePolicy do
  include PolicyHelper
  describe 'When the user is admin' do
    subject { described_class.new(user: user) }
    let(:user) { build(:admin) }
    context 'Admin can manage exam templates' do
      it { is_expected.to pass :manage? }
    end
    context 'Admin can edit, update, download, destroy exam templates' do
      it { is_expected.to pass :modify? }
    end
  end
  describe 'When the user is TA' do
    subject { described_class.new(user: user) }
    let(:user) { create(:ta) }
    context 'When TA is allowed to edit, update, download, destroy exam templates' do
      before do
        create(:grader_permission, user_id: user.id, manage_exam_templates: true)
      end
      it { is_expected.to pass :modify? }
    end
    context 'When TA is not allowed to edit, update, download, destroy exam templates' do
      before do
        create(:grader_permission, user_id: user.id, manage_exam_templates: false)
      end
      it { is_expected.not_to pass :modify? }
    end
    context 'TA cannot manage exam templates' do
      it { is_expected.not_to pass :manage? }
    end
  end
end