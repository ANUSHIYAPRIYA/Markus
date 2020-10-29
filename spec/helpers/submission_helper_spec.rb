describe SubmissionsHelper do
  include SubmissionsHelper

  # Put some confidence in our submission filename sanitization
  context 'A new file when submitted' do
    context "containing characters outside what's allowed in a filename" do
      before :each do
        @filenames_to_be_sanitized = [ { expected: 'llll_', orig: 'llllé' },
                                       { expected: '________', orig: 'öä*?`ßÜÄ' },
                                       { expected: '', orig: nil },
                                       { expected: 'garbage-__.txt', orig: 'garbage-éæ.txt' },
                                       { expected: 'space_space.txt', orig: 'space space.txt' },
                                       { expected: '______.txt', orig: '      .txt' },
                                       { expected: 'garbage-__.txt', orig: 'garbage-éæ.txt' } ]
      end

      it 'have sanitized them properly' do
        @filenames_to_be_sanitized.each do |item|
          expect(sanitize_file_name(item[:orig])).to eq item[:expected]
        end
      end
    end

    context 'containing only valid characters in a filename' do
      before :each do
        @filenames_not_to_be_sanitized = %w(valid_file.sh
                                            valid_001.file.ext
                                            valid-master.png
                                            some__file___.org-png
                                            001.txt)
      end

      it 'NOT have sanitized away any of their characters' do
        @filenames_not_to_be_sanitized.each do |orig|
          expect(sanitize_file_name(orig)).to eq orig
        end
      end
    end
  end

  describe '#get_file_info' do
    let(:assignment) { create(:assignment) }
    let(:grouping) { create(:grouping, assignment: assignment) }
    let(:file_name) { 'test.zip' }
    before do
      grouping.access_repo do |repo|
        rev = repo.get_latest_revision
        Repository::RevisionFile.new(
          rev.revision_identifier,
          name: file_name,
          path: grouping.assignment.repository_folder,
          mime_type: 'application/zip'
        )
      end
    end
    it 'should generate and return the file url with correct assignment id' do
      file_info = {}
      grouping.access_repo do |repo|
        revision = repo.get_latest_revision
        full_path = File.join(grouping.assignment.repository_folder, '')
        file_obj = revision.tree_at_path(full_path)[file_name]
        dirname, basename = File.split(file_name)
        dirname = '' if dirname == '.'
        file_info = get_file_info(basename, file_obj, assignment.id, revision.revision_identifier, dirname, grouping.id)
      end
      expect(file_info[:url].match(%r{/assignments\/(\d*)/})[1]).to eq(assignment.id.to_s)
    end
  end
end
