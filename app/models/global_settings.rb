class GlobalSettings < ActiveRecord::Base

  attr_accessible :smtp_timeout, :asynchronous, :bing_api, :beef_url, :reports_refresh, :singleton

  validates :site_url, uri: true
  validates :command_apache_restart, :presence => true, :length => {:maximum => 255}
  validates :command_apache_vhosts, :presence => true, :length => {:maximum => 255}
  validates :sites_enabled_path, :presence => true, :length => {:maximum => 255}
  validates :smtp_timeout, :presence => true, :length => {:maximum => 2},
            :numericality => {:greater_than_or_equal_to => 1, :less_than_or_equal_to => 20}

  validates_inclusion_of :singleton, in: [0]

  def self.instance
    begin
      find(1)
    rescue ActiveRecord::RecordNotFound
      row = GlobalSettings.new
      row.id = 1
      row.singleton = 0
      row.save!
      row
    end
  end

  def self.asynchronous?
    instance.asynchronous?
  end
end
