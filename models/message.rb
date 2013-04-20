class Message < ActiveRecord::Base

  attr_accessible  :body
  belongs_to :sender, :class_name => "User"
  belongs_to :recipient ,:polymorphic=>true

  scope :messages, lambda { |user| messages_for(user) }

 def self.messages_for(user)
    where("sender_id = :user_id OR recipient_id = recipient)",
          { :user_id => user})
 end

end

