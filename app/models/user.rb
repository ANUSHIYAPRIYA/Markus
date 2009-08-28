require 'fastercsv'

# We always assume the following fields exists:
# => :user_name, :last_name, :first_name
# If there are added columns, add the default values to default_values
class User < ActiveRecord::Base
  # Group relationships  
  has_many :memberships
  has_many :groupings, :through => :memberships  

  has_many :accepted_memberships, :class_name => "Membership", :conditions => {:membership_status => [StudentMembership::STATUSES[:accepted], StudentMembership::STATUSES[:inviter]]}
    
  validates_presence_of     :user_name, :last_name, :first_name
  validates_uniqueness_of   :user_name
  
  validates_format_of       :type,          :with => /Student|Admin|Ta/
      
  # role constants
  STUDENT = 'Student'
  ADMIN = 'Admin'
  TA = 'Ta'
  
  # Authentication------------------------------------------------------
  
  # Verifies if user is allowed to enter MarkUs
  # Returns user object representing the user with the given login.
  def self.authorize(login)
    # fetch login in database to see if it is registered.
    find_by_user_name(login)
  end
  
  # Authenticates login against its password 
  # through a script specified by VALIDATE_FILE
  def self.authenticated?(login, password)
    # Do not allow the following characters in usernames/passwords
    # Right now, this is \n and \0 only, since username and password
    # are delimited by \n and C programs use \0 to terminate strings
    not_allowed_regexp = Regexp.new(/[\n\0]+/)
    if !(not_allowed_regexp.match(login) || not_allowed_regexp.match(password))
      # Open a pipe and write to stdin of the program specified by VALIDATE_FILE. 
      # We could read something from the programs stdout, but there is no need
      # for that at the moment (you would do it by e.g. pipe.readlines)
      pipe = IO.popen(VALIDATE_FILE, "w+")
      pipe.puts("#{login}\n#{password}") # write to stdin of VALIDATE_FILE
      pipe.close
      return $?.exitstatus == 0
    else
      return false
    end
  end
  
  
  #TODO: make these proper associations. They work fine for now but 
  # they'll be slow in production
  def active_groupings
    self.groupings.find(:all, :conditions => ["memberships.membership_status != :u", { :u => StudentMembership::STATUSES[:rejected]}])
  end


  # Group methods ------------------------------------------------------
  
  # Helper methods -----------------------------------------------------
    
  def admin?
    self.class == Admin
  end

  def ta?
    self.class == Ta
  end
  
  def student?
    self.class == Student
  end
  
  # Submission helper methods -------------------------------------------------
  
  def submission_for(aid)
    grouping = grouping_for(aid)
    if grouping.nil?
      return nil
    end
    return grouping.get_submission_used
  end
  
  # Classlist parsing --------------------------------------------------------
  def self.generate_csv_list(user_list)
     file_out = FasterCSV.generate do |csv|
       user_list.each do |user|
         # csv format is user_name,last_name,first_name
         user_array = [user.user_name,user.last_name,user.first_name]
         csv << user_array
       end
     end
     return file_out
  end
  
  def self.upload_user_list(user_class, user_list)
    num_update = 0
    result = {}
    result[:invalid_lines] = []  # store lines that were not processed    
    # read each line of the file and update classlist
    User.transaction do
      processed_users = []
      FasterCSV.parse(user_list, :skip_blanks => true, :row_sep => :auto) do |row|
        # don't know how to fetch line so we concat given array
        next if FasterCSV.generate_line(row).strip.empty?
        if processed_users.include?(row[0])
          result[:invalid_lines] = I18n.t('csv_upload_user_duplicate', {:user_name => row[0]})
        else
          if User.add_user(user_class, row).nil?
            result[:invalid_lines] << row.join(",")
          else
            num_update += 1
            processed_users.push(row[0])
          end
        end
      end # end prase
    end
    result[:upload_notice] = "#{num_update} user(s) added/updated."     
    return result
  end

 def self.add_user(user_class, row)
    # convert each line to a hash with FIELDS as corresponding keys
    # and create or update a user with the hash values
    #return nil if values.length < UPLOAD_FIELDS.length
    user_attributes = {}
    # Loop through the resulting array as key, value pairs
   
    user_class::CSV_UPLOAD_ORDER.zip(row) do |key, val|
      # append them to the hash that is returned by User.get_default_ta/student_attrs
      user_attributes[key] = val
    end
    
    # Is there already a Student with this User number?
    current_user = user_class.find_or_create_by_user_name(user_attributes[:user_name])
    current_user.attributes = user_attributes

    if !current_user.save
      return nil
    end
    
    return current_user
  end
end
