require 'test/unit'

begin
  require File.dirname(__FILE__) + '/../../../../config/environment'
rescue LoadError
  require 'rubygems'
  require 'activerecord'
  require 'actionpack'
end

# Search for fixtures first
fixture_path = File.dirname(__FILE__) + '/fixtures/'
begin
  Dependencies.load_paths.insert(0, fixture_path)
rescue
  $LOAD_PATH.unshift(fixture_path)
end

require 'active_record/fixtures'

require File.dirname(__FILE__) + '/../init'

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')
ActiveRecord::Base.configurations = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.establish_connection(ENV['DB'] || 'mysql')

load(File.dirname(__FILE__) + '/schema.rb')

#Test::Unit::TestCase.fixture_path = fixture_path

class Category < ActiveRecord::Base
  acts_as_tree_on_steroids :family_level => 1
end
