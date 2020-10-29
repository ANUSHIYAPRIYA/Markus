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
    let(:grouping) { create(:grouping_with_inviter_and_submission, assignment: assignment) }
    let(:file_name) { 'test.zip' }
    let(:revision_identifier) { grouping.assignment.revision_identifier }
    let(:file_obj) do
      Repository::RevisionFile.new(
        revision_identifier,
        name: file_name,
        path: grouping.assignment.repository_folder,
        mime_type: 'application/zip'
      )
    end
    it 'should generate and return the file url with correct assignment id' do
      dirname, basename = File.split(file_name)
      dirname = '' if dirname == '.'
      file_info = get_file_info(basename, file_obj, assignment.id, revision_identifier, dirname, grouping.id)
      expect(file_info[:url].match(%r{/assignments\/(\d*)/})[1]).to eq(assignment.id.to_s)
    end
  end
end
