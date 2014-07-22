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
require 'json'

class CheckCucumberFeatures < Sensu::Plugin::Check::CLI
  OK = 0
  WARNING = 1
  CRITICAL = 2
  UNKNOWN = 3

  #option :features,
  #  :description => "Path of Cucumber features",
  #  :short => '-f FEATURES',
  #  :long => '--features FEATURES'
  #
  option :command,
    :description => "Cucumber command line, including arguments",
    :short => '-c COMMAND',
    :long => '--command COMMAND'

  option :debug,
    :description => "Print debug information",
    :long => '--debug',
    :boolean => true

  def execute_cucumber_features
    report = `#{config[:command]}`

    {:report => report, :exit_status => $?.exitstatus}
  end

  def run
    #if config[:features].nil?
    #  unknown "No features path specified"
    #else
    if config[:command].nil?
      unknown "No cucumber command line specified"
    else
      result = execute_cucumber_features

      outcome = OK

      result[:report].each do |feature|
        if feature.has_key? :elements
          feature[:elements].each do |element|
            if element.has_key? :steps
              element[:steps].each do |step|
                if step.has_key? :result
                  case step[:result][:status]
                    when 'undefined', 'pending'
                      outcome = WARNING
                  end
                end
              end
            end
          end
        end
      end

      case outcome
        when OK
          ok
        when WARNING
          warning
      end
    end
  end

end