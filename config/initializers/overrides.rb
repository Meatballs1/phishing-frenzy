require 'digest'

class Victim < ActiveRecord::Base
  def generate_uid
    Digest::SHA256.hexdigest((0...8).map { (65 + rand(26)).chr }.join)
  end
end
