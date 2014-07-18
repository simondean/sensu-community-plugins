#!/usr/bin/env ruby
#
#
# ===
#
# DESCRIPTION:
#   A check that executes Cucumber tests
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#
# Copyright 2014 Simon Dean <simon@simondean.org>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CucumberCheck < Sensu::Plugin::Check::CLI

  option :features,
    :description => "Path of Cucumber features",
    :short => '-f FEATURES',
    :long => '--features FEATURES'

  option :debug,
    :description => "Print debug information",
    :long => '--debug',
    :boolean => true

  def run
    unknown "No features path specified"
  end

end