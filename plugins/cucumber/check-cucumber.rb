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
require 'socket'

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
    :description => "Handler to use for sensu events",
    :short => '-h HANDLER',
    :long => '--handler HANDLER'

  option :metrics_prefix,
    :description => "Metrics prefix to use with metric paths in sensu events",
    :short => '-m METRICS_PREFIX',
    :long => '--metrics-prefix METRICS_PREFIX'

  option :command,
    :description => "Cucumber command line, including arguments",
    :short => '-c COMMAND',
    :long => '--command COMMAND'

  option :working_dir,
    :description => "Working directory to use with Cucumber",
    :short => '-w WORKING_DIR',
    :long => '--working-dir WORKING_DIR'

  option :debug,
    :description => "Print debug information",
    :long => '--debug',
    :boolean => true

  def execute_cucumber
    report = nil

    IO.popen(config[:command], :chdir => config[:working_dir]) do |io|
      report = io.read
    end

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

    if config[:metrics_prefix].nil?
      unknown "No metrics prefix specified"
      return
    end

    if config[:command].nil?
      unknown "No cucumber command line specified"
      return
    end

    if config[:working_dir].nil?
      unknown "No working directory specified"
      return
    end

    result = execute_cucumber

    outcome = OK
    scenario_count = 0
    statuses = [:passed, :failed, :pending, :undefined]
    status_counts = {}
    statuses.each {|scenario_status| status_counts[scenario_status] = 0}
    sensu_events = []

    result[:report].each do |feature|
      if feature.has_key? :elements
        feature[:elements].each do |element|
          if element[:type] == 'scenario'
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

            feature_clone = deep_dup(feature)
            feature_clone[:elements] = [deep_dup(element)]
            scenario_report = [feature_clone]

            metrics = generate_metrics_from_scenario(element, scenario_status)

            data = {
              :status => scenario_status,
              :report => scenario_report,
              :metrics => metrics
            }

            sensu_event = {
              :handlers => [config[:handler]],
              :name => "#{config[:name]}.#{generate_name_from_scenario(element)}",
              :output => data.to_json
            }

            case scenario_status
              when :passed
                sensu_event[:status] = OK
              when :failed
                sensu_event[:status] = CRITICAL
              when :pending, :undefined
                sensu_event[:status] = WARNING
            end

            scenario_count += 1
            status_counts[scenario_status] += 1

            sensu_events << sensu_event
          end
        end
      end
    end

    raise_sensu_events sensu_events unless sensu_events.length == 0

    message = "scenarios: #{scenario_count}"
    statuses.each do |status|
      message << ", #{status}: #{status_counts[status]}" unless status_counts[status] == 0
    end

    case outcome
      when OK
        ok message
    end
  end

  def generate_name_from_scenario(scenario)
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

  def raise_sensu_events(sensu_events)
    sensu_events.each do |sensu_event|
      data = sensu_event.to_json

      socket = UDPSocket.new
      socket.send data, 0, '127.0.0.1', 3030
      socket.close
    end
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def generate_metrics_from_scenario(scenario, scenario_status)
    metrics = []

    if scenario_status == :passed
      scenario_duration = 0

      if scenario.has_key?(:steps)
        has_step_durations = false

        scenario[:steps].each.with_index do |step, step_index|
          if step.has_key?(:result) && step[:result].has_key?(:duration)
            has_step_durations = true
            step_duration = step[:result][:duration]
            step_duration = step_duration
            metrics << {
              :path => "#{config[:metrics_prefix]}.#{generate_name_from_scenario(scenario)}.step-#{step_index + 1}.duration",
              :value => step_duration
            }
            scenario_duration += step_duration
          end
        end

        if has_step_durations
          metrics.unshift({
            :path => "#{config[:metrics_prefix]}.#{generate_name_from_scenario(scenario)}.duration",
            :value => scenario_duration
          })
        end
      end
    end

    metrics
  end

end
