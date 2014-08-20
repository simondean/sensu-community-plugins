#!/usr/bin/env ruby
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
require 'optparse'
require 'json'
require 'yaml'
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

  option :metric_handler,
    :description => "Handler to use for metric events",
    :short => '-m HANDLER',
    :long => '--metric-handler HANDLER'

  option :metric_prefix,
    :description => "Metric prefix to use with metric paths in sensu events",
    :short => '-p METRIC_PREFIX',
    :long => '--metric-prefix METRIC_PREFIX'

  option :command,
    :description => "Cucumber command line, including arguments",
    :short => '-c COMMAND',
    :long => '--command COMMAND'

  option :working_dir,
    :description => "Working directory to use with Cucumber",
    :short => '-w WORKING_DIR',
    :long => '--working-dir WORKING_DIR'

  process_env_option =
    lambda do |c|
      @env ||= {}
      name, value = c.split('=', 2)
      @env[name] = value
      @env
    end

  option :env,
    :description => "Environment variable to pass to Cucumber. Can be specified more than once to set multiple environment variables",
    :short => '-n NAME=VALUE',
    :long => '--env NAME=VALUE',
    :proc => process_env_option

  option :debug,
    :description => "Print debug information",
    :long => '--debug',
    :boolean => true

  def output(msg)
    puts msg
  end

  def execute_cucumber
    report = nil
    env = config[:env] || {}

    IO.popen(env, config[:command], :chdir => config[:working_dir]) do |io|
      report = io.read
    end

    {:report => report, :exit_status => $?.exitstatus}
  end

  def run
    if config[:name].nil?
      unknown_error 'No name specified'
      return
    end

    if config[:handler].nil?
      unknown_error 'No handler specified'
      return
    end

    if config[:metric_handler].nil?
      unknown_error 'No metric handler specified'
      return
    end

    if config[:metric_prefix].nil?
      unknown_error 'No metric prefix specified'
      return
    end

    if config[:command].nil?
      unknown_error 'No cucumber command line specified'
      return
    end

    if config[:working_dir].nil?
      unknown_error 'No working directory specified'
      return
    end

    result = execute_cucumber

    puts "Report: #{result[:report]}" if config[:debug]
    puts "Exit status: #{result[:exit_status]}" if config[:debug]

    unless [0, 1].include? result[:exit_status]
      unknown_error "Cucumber returned exit code #{result[:exit_status]}"
      return
    end

    report = JSON.parse(result[:report], :symbolize_names => true)

    outcome = :ok
    scenario_count = 0
    statuses = [:passed, :failed, :pending, :undefined]
    status_counts = {}
    statuses.each {|scenario_status| status_counts[scenario_status] = 0}
    sensu_events = []
    utc_timestamp = Time.now.getutc.to_i

    report.each do |feature|
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

            steps_output = []

            if element.has_key?(:steps)
              element[:steps].each_with_index do |step, index|
                has_result = step.has_key?(:result)
                step_status = has_result ? step[:result][:status] : ''
                step_output = {
                  'step' => "#{step_status.upcase} - #{index + 1} - #{step[:keyword]}#{step[:name]}"
                }

                if has_result && step[:result].has_key?(:error_message)
                  step_output['error'] = step[:result][:error_message]
                end

                steps_output << step_output
              end
            end

            scenario_output = {
              'status' => scenario_status.to_s,
              'steps' => steps_output
            }

            event_name = "#{config[:name]}.#{generate_name_from_scenario(element)}"

            scenario_status_code = case scenario_status
              when :passed
                OK
              when :failed
                CRITICAL
              when :pending, :undefined
                WARNING
            end

            sensu_event = {
              :name => event_name,
              :handlers => [config[:handler]],
              :status => scenario_status_code,
              :output => dump_yaml(scenario_output),
              :report => scenario_report
            }

            sensu_events << sensu_event

            metrics = generate_metrics_from_scenario(element, scenario_status, utc_timestamp)

            unless metrics.nil?
              metric_event = {
                :name => "#{event_name}.metrics",
                :type => 'metric',
                :handlers => [config[:metric_handler]],
                :output => metrics,
                :status => 0
              }
              sensu_events << metric_event
            end

            scenario_count += 1
            status_counts[scenario_status] += 1
          end
        end
      end
    end

    puts "Sensu events: #{JSON.pretty_generate(sensu_events)}" if config[:debug]

    errors = nil
    errors = raise_sensu_events(sensu_events) unless sensu_events.length == 0
    has_errors = !errors.nil? && errors.length > 0

    if has_errors
      outcome = :unknown
    elsif scenario_count == 0
      outcome = :warning
    end

    data = {
      'status' => outcome.to_s,
      'scenarios' => scenario_count
    }

    statuses.each do |status|
      data[status.to_s] = status_counts[status] if status_counts[status] > 0
    end

    data['errors'] = errors if has_errors

    data = dump_yaml(data)

    case outcome
      when :ok
        ok data
      when :warning
        warning data
      when :unknown
        unknown data
    end
  end

  def generate_name_from_scenario(scenario)
    name = scenario[:id]
    name += ";#{scenario[:profile]}" if scenario.has_key? :profile

    name = name.gsub(/\./, '-')
      .gsub(/;/, '.')
      .gsub(/[^a-zA-Z0-9\._-]/, '-')
      .gsub(/^\.+/, '')
      .gsub(/\.+$/, '')
      .gsub(/\.+/, '.')

    parts = []

    name.split('.').each do |part|
      part = part.gsub(/^-+/, '')
        .gsub(/-+$/, '')
        .gsub(/-+/, '-')

      parts << part unless part.length == 0
    end

    name = parts.join('.')
    name
  end

  def raise_sensu_events(sensu_events)
    errors = []

    sensu_events.each do |sensu_event|
      data = sensu_event.to_json

      begin
        send_sensu_event(data)
      rescue StandardError => error
        errors << {
          'message' => "Failed to raise event #{sensu_event[:name]}",
          'error' => {
            'message' => error.message,
            'backtrace' => error.backtrace
          }
        }
      end
    end

    errors
  end

  def send_sensu_event(data)
    socket = TCPSocket.new('127.0.0.1', 3030)
    socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

    index = 0
    length = data.length

    while index < length
      bytes_sent = socket.send data[index..-1], 0
      index += bytes_sent
    end

    socket.close
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def generate_metrics_from_scenario(scenario, scenario_status, utc_timestamp)
    metrics = []

    if scenario_status == :passed
      scenario_duration = 0

      if scenario.has_key?(:steps)
        has_step_durations = false
        scenario_metric_prefix = "#{config[:metric_prefix]}.#{generate_name_from_scenario(scenario)}"

        scenario[:steps].each.with_index do |step, step_index|
          if step.has_key?(:result) && step[:result].has_key?(:duration)
            has_step_durations = true
            step_duration = step[:result][:duration]
            step_duration = step_duration
            metrics << "#{scenario_metric_prefix}.step-#{step_index + 1}.duration #{step_duration} #{utc_timestamp}"
            scenario_duration += step_duration
          end
        end

        if has_step_durations
          scenario_metrics = [
            "#{scenario_metric_prefix}.duration #{scenario_duration} #{utc_timestamp}",
            "#{scenario_metric_prefix}.step-count #{scenario[:steps].length} #{utc_timestamp}"
          ]
          metrics.unshift scenario_metrics
        end
      end
    end

    if metrics.length == 0
      metrics = nil
    else
      metrics = metrics.join("\n")
    end

    metrics
  end

  def unknown_error(message)
    data = {
      'status' => 'unknown',
      'errors' => [
        {
          'message' => message
        }
      ]
    }
    unknown dump_yaml(data)
  end

  def dump_yaml(data)
    data.to_yaml.gsub(/^---\r?\n/, '')
  end

end
