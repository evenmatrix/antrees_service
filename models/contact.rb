require 'rubygems'
require 'state_machine'
class Contact < ActiveRecord::Base
  attr_accessible :jid, :presence,:show,:affiliation,:user_id
  belongs_to :user
  belongs_to :branch
  scope :online, where(:presence => "available")
end
