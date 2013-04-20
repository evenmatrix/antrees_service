class Contact < ActiveRecord::Base
  attr_accessor :affiliation
  attr_accessible :presence_type,:jid,:affiliation
  belongs_to :branch
  belongs_to :user
end
