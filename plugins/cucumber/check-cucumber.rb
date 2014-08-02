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

class CheckCucumber < Sensu::Plugin::Check::CLI
  OK = 0
  WARNING = 1
  CRITICAL = 2
  UNKNOWN = 3

  option :name,
    :description => "Name to use in sensu events",
    :short => '-n NAME',
    :long => '--name NAME'

  option :handler,
    :description => "Handler to use in sensu events",
    :short => '-h HANDLER',
    :long => '--handler HANDLER'

  option :command,
    :description => "Cucumber command line, including arguments",
    :short => '-c COMMAND',
    :long => '--command COMMAND'

  option :debug,
    :description => "Print debug information",
    :long => '--debug',
    :boolean => true

  def execute_cucumber
    report = `#{config[:command]}`

    {:report => JSON.parse(report, :symbolize_names => true), :exit_status => $?.exitstatus}
  end

  def run
    if config[:name].nil?
      unknown "No name specified"
      return
    end

    if config[:handler].nil?
      unknown "No handler specified"
      return
    end

    if config[:command].nil?
      unknown "No cucumber command line specified"
      return
    end

    result = execute_cucumber

    outcome = OK
    scenario_count = 0

    result[:report].each do |feature|
      if feature.has_key? :elements
        feature[:elements].each do |element|
          scenario_status = :passed

          if element.has_key? :steps
            element[:steps].each do |step|
              if step.has_key? :result
                step_status = step[:result][:status]

                if ['failed', 'pending', 'undefined'].include? step_status
                  scenario_status = step_status.to_sym
                  break
                end
              end
            end
          end

          scenario_count += 1

          sensu_event = {
            :handlers => [config[:handler]],
            :name => "#{config[:name]}.#{generate_check_name_from_scenario(element)}",
            :output => ''
          }

          case scenario_status
            when :passed
              sensu_event[:status] = OK
            when :failed
              sensu_event[:status] = CRITICAL
              when :pending, :undefined
              sensu_event[:status] = WARNING
          end

          raise_sensu_event sensu_event
        end
      end
    end

    case outcome
      when OK
        ok "OK: #{scenario_count} #{scenario_count != 1 ? 'scenarios' : 'scenario'}"
    end
  end

  def generate_check_name_from_scenario(scenario)
    check_name = scenario[:id].gsub(/;/, '.')
      .gsub(/[^a-zA-Z0-9\._-]/, '-')
      .gsub(/^\.+/, '')
      .gsub(/\.+$/, '')
      .gsub(/\.+/, '.')

    parts = []

    check_name.split('.').each do |part|
      part = part.gsub(/^-+/, '')
        .gsub(/-+$/, '')
        .gsub(/-+/, '-')

      parts << part unless part.length == 0
    end

    check_name = parts.join('.')
    check_name
  end

  def raise_sensu_event(sensu_event)
  end

  def output(obj = nil)
    if obj.is_a?(String) || obj.is_a?(Exception)
      puts obj.to_s
    elsif obj.is_a?(Hash)
      puts ::JSON.generate(obj)
    end
  end

end
