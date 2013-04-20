class Affiliation < ActiveRecord::Base
  belongs_to :entity ,:polymorphic=>true
  belongs_to :user
  validates_uniqueness_of :entity_id, :scope => [:user_id,:type]

  before_create :generate_security_code

  def generate_security_code
    begin
      code = rand(999999)
      write_attribute :code, code
    end until code > 0
  end
end

class Ownership <  Affiliation
end

class Administration <  Affiliation
  belongs_to :entity ,:polymorphic=>true, :counter_cache => true
end

class Membership <  Affiliation
  belongs_to :entity ,:polymorphic=>true, :counter_cache => true
end

class Management <  Affiliation
end
