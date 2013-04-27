require 'rubygems'
require 'state_machine'

class Contact < ActiveRecord::Base
  attr_accessible :jid,:show,:affiliation,:user_id
  belongs_to :user
  belongs_to :branch
  scope :online, where(:state => 1)

  state_machine initial: :offline do
    state :offline, value: 0
    state :online, value: 1

    event :present do
      transition :offline => :online
    end

    event :absent do
      transition :online => :offline
    end
  end
end
