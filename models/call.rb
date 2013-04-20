class Call < ActiveRecord::Base
  attr_accessible  :sid,:token,:caller_id,:callee_id,:branch_id
  belongs_to :caller, :class_name => "User",:foreign_key=>"caller_id"
  belongs_to :callee, :class_name => "User",:foreign_key=>"callee_id"
  belongs_to :branch

  state_machine initial: :inactive   do


  event :answer do
    transition :offer => :active
  end

  event :offer do
    transition :inactive => :offer
  end

  event :decline do
    transition :offer => :canceled
  end

  event :hold do
    transition :active => :inactive
  end

  event :continue do
    transition :inactive => :active
  end

  event :terminate do
    transition :offer => :canceled
    transition :active => :canceled
  end

 end

 def isCaller?(user)
   (self.caller==user)
 end
 
 def isCallee?(user)
   (self.callee==user)
 end
 
 def self.caller_calls(user,branch)
   where("caller_id = :caller_id AND branch_id=:branch_id",
    {:caller_id => user,:branch_id => branch})
 end
 
 def self.caller_calls(user,branch)
   where("caller_id = :caller_id AND branch_id=:branch_id",
    {:caller_id => user,:branch_id => branch})
 end

 def self.callee_calls(user,branch)
   where("callee_id = :callee_id AND branch_id=:branch_id",
    {:callee_id=> user,:branch_id => branch} )
 end
 
 def self.user_calls(user,branch)
   where("caller_id = :caller_id OR callee_id = :callee_id AND branch_id=:branch_id",
   { :caller_id => user,:callee_id=> user,:branch_id => branch })
 end
 
 def self.existing_call?(caller,callee,branch)
   !(where("caller_id = :caller_id AND callee_id = :callee_id AND branch_id=:branch_id",
   { :caller_id => caller,:callee_id=> callee,:branch_id => branch }).first.nil?)
 end

 def self.existing_call(caller,callee,branch)
   where("caller_id = :caller_id AND callee_id = :callee_id AND branch_id=:branch_id",
   { :caller_id => caller,:callee_id=> callee,:branch_id => branch }).first
 end

   def self.token
     token=nil
     begin
       token = SecureRandom.hex
     end while exists?(token: token)
     token
   end

   def self.session_id
     sid=nil
     begin
       sid = SecureRandom.random_number(49050050)
     end while exists?(sid: sid.to_s)
     sid.to_s
   end

end
