class Conversation < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :user
  belongs_to :participant, :class_name => "User"
end
