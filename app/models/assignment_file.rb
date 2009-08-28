class AssignmentFile < ActiveRecord::Base
  belongs_to  :assignment
  
  validates_presence_of   :filename
  validates_uniqueness_of :filename, :scope => :assignment_id
  validates_format_of     :filename, :with => /^([\w\.{0,1}-])+$/, 
    :message => "must be alphanumeric, '.' or '-' only"
 
  # sanitize filename input before saving
  def before_save    
    filename.strip!
    filename.gsub(/^(..)+/, ".")
    filename.gsub(/[^\s]/, "") # replace spaces with 
    # replace all non alphanumeric, underscore or periods with underscore
    filename.gsub(/^[\W]+$/, '_')
  end
  
end
