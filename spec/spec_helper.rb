# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../dummy/config/environment.rb', __FILE__)
require 'spree_dev_tools/rspec/spec_helper'
require 'rspec/active_model/mocks'

Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].sort.each { |f| require f }