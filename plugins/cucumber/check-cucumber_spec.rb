require_relative 'check-cucumber'
require_relative '../../spec_helper'

describe CheckCucumber do
  check_cucumber = nil

  before(:each) do
    check_cucumber = CheckCucumber.new
  end

  describe 'run()' do
    it 'returns unknown if no name is specified' do
      expect(check_cucumber).to receive('unknown').with('No name specified')
      check_cucumber.run
    end

    describe 'when the name is specified' do
      before(:each) do
        check_cucumber.config[:name] = 'example-name'
      end

      it 'returns unknown if no handler is specified' do
        expect(check_cucumber).to receive('unknown').with('No handler specified')
        check_cucumber.run
      end

      describe 'when the handler is specified' do
        before(:each) do
          check_cucumber.config[:handler] = 'example-handler'
        end

        it 'returns unknown if no metrics prefix is specified' do
          expect(check_cucumber).to receive('unknown').with('No metrics prefix specified')
          check_cucumber.run
        end

        describe 'when the metrics prefix is specified' do
          before(:each) do
            check_cucumber.config[:metrics_prefix] = 'example-metrics-prefix'
          end

          it 'returns unknown if no cucumber command line is specified' do
            expect(check_cucumber).to receive('unknown').with('No cucumber command line specified')
            check_cucumber.run
          end

          describe 'when the Cucumber command line is specified' do
            before(:each) do
              check_cucumber.config[:command] = 'cucumber-js features/'
            end

            describe 'when cucumber executes and provides a report' do
              report = nil

              before(:each) do
                report = []
                expect(check_cucumber).to receive('execute_cucumber') do
                  {:report => report, :exit_status => 0}
                end
              end

              describe 'when there are no steps' do
                it 'returns ok' do
                  expect(check_cucumber).to receive('ok').with('scenarios: 0')
                end
              end

              describe 'when there is a passing step' do
                before(:each) do
                  report << generate_feature(:scenarios => [{:step_statuses => :passed}])
                end

                it 'returns ok' do
                  expect(check_cucumber).to receive('ok').with('scenarios: 1, passed: 1')
                end

                it 'raises an ok event' do
                  sensu_event = generate_sensu_event(:status => :passed, :report => report)
                  expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event])
                end
              end

              describe 'when there is a passing step followed by a failing step' do
                before(:each) do
                  report << generate_feature(:scenarios => [{:step_statuses => [:passed, :failed]}])
                end

                it 'returns ok' do
                  expect(check_cucumber).to receive('ok').with('scenarios: 1, failed: 1')
                end

                it 'raises a critical event' do
                  sensu_event = generate_sensu_event(:status => :failed, :report => report)
                  expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event])
                end
              end

              describe 'when there is a passing step followed by a pending step' do
                before(:each) do
                  report << generate_feature(:scenarios => [{:step_statuses => [:passed, :pending]}])
                end

                it 'returns ok' do
                  expect(check_cucumber).to receive('ok').with('scenarios: 1, pending: 1')
                end

                it 'raises a warning event' do
                  sensu_event = generate_sensu_event(:status => :pending, :report => report)
                  expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event])
                end
              end

              describe 'when there is a passing step followed by a undefined step' do
                before(:each) do
                  report << generate_feature(:scenarios => [{:step_statuses => [:passed, :undefined]}])
                end

                it 'returns ok' do
                  expect(check_cucumber).to receive('ok').with('scenarios: 1, undefined: 1')
                end

                it 'raises a warning event' do
                  sensu_event = generate_sensu_event(:status => :undefined, :report => report)
                  expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event])
                end
              end

              describe 'when there are multiple scenarios' do
                before(:each) do
                  report << generate_feature(:scenarios => [{:step_statuses => :passed}, {:step_statuses => :passed}])
                end

                it 'returns ok' do
                  expect(check_cucumber).to receive('ok').with('scenarios: 2, passed: 2')
                end

                it 'raises multiple events' do
                  sensu_events = []
                  sensu_events << generate_sensu_event(:status => :passed, :scenario_index => 0, :report => report)
                  sensu_events << generate_sensu_event(:status => :passed, :scenario_index => 1, :report => report)
                  expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events)
                end
              end

              describe 'when there are multiple features' do
                before(:each) do
                  report << generate_feature(:feature_index => 0, :scenarios => [{:step_statuses => :passed}])
                  report << generate_feature(:feature_index => 1, :scenarios => [{:step_statuses => :passed}])
                end

                it 'returns ok' do
                  expect(check_cucumber).to receive('ok').with('scenarios: 2, passed: 2')
                end

                it 'raises multiple events' do
                  sensu_events = []
                  sensu_events << generate_sensu_event(:status => :passed, :feature_index => 0, :scenario_index => 0, :report => report)
                  sensu_events << generate_sensu_event(:status => :passed, :feature_index => 1, :scenario_index => 0, :report => report)
                  expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events)
                end
              end

              after(:each) do
                check_cucumber.run
              end
            end
          end
        end
      end
    end
  end

  describe 'generate_name_from_scenario()' do
    it 'returns the scenario id' do
      scenario = {:id => 'text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces a semi colon with a period' do
      scenario = {:id => 'text;text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'replaces multiple semi colons with periods' do
      scenario = {:id => 'text;text;text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text.text')
    end

    it 'does not replace hyphens' do
      scenario = {:id => 'text-text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text-text')
    end

    it 'does not replace periods' do
      scenario = {:id => 'text.text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'replaces every character (except letters, periods, hyphens and underscores) with hyphen' do
      id = ''
      (1..254).each {|ascii_code| id += ascii_code.chr}

      scenario = {:id => id}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('0123456789.ABCDEFGHIJKLMNOPQRSTUVWXYZ-_-abcdefghijklmnopqrstuvwxyz')
    end

    it 'avoid consecutive periods' do
      scenario = {:id => 'text;;text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the start' do
      scenario = {:id => '-text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple hyphens at the start' do
      scenario = {:id => '--text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes a hyphen at the end' do
      scenario = {:id => 'text-'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple hyphens at the end' do
      scenario = {:id => 'text--'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces consecutive hyphens with a single hyphen' do
      scenario = {:id => 'text--text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text-text')
    end

    it 'removes a period at the start' do
      scenario = {:id => '.text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple periods at the start' do
      scenario = {:id => '..text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes a period at the end' do
      scenario = {:id => 'text.'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple periods at the end' do
      scenario = {:id => 'text..'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces consecutive periods with a single period' do
      scenario = {:id => 'text..text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the start of a part' do
      scenario = {:id => 'text.-text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes multiple hyphens at the start of a part' do
      scenario = {:id => 'text.--text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the end of a part' do
      scenario = {:id => 'text.-text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes multiple hyphens at the end of a part' do
      scenario = {:id => 'text.--text'}
      check_name = check_cucumber.generate_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end
  end

  describe 'generate_metrics_from_scenario()' do
    scenario = nil

    before(:each) do
      check_cucumber.config[:metrics_prefix] = 'example-metrics-prefix'
      scenario = {:id => 'example-scenario-id', :steps => []}
    end

    it 'generates metrics for a single step' do
      scenario[:steps] << {:result => {:duration => 0.5}}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :passed)
      expected_metrics = [
        {:path => "example-metrics-prefix.example-scenario-id.duration", :value => 0.5},
        {:path => "example-metrics-prefix.example-scenario-id.step-1.duration", :value => 0.5}
      ]
      expect(metrics).to eq(expected_metrics)
    end

    it 'generates metrics for multiple steps' do
      scenario[:steps] << {:result => {:duration => 0.5}}
      scenario[:steps] << {:result => {:duration => 1.5}}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :passed)
      expected_metrics = [
        {:path => "example-metrics-prefix.example-scenario-id.duration", :value => 2},
        {:path => "example-metrics-prefix.example-scenario-id.step-1.duration", :value => 0.5},
        {:path => "example-metrics-prefix.example-scenario-id.step-2.duration", :value => 1.5}
      ]
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a scenario with no steps' do
      scenario.delete :steps
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :passed)
      expected_metrics = []
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a scenario with an empty array of steps' do
      scenario[:steps] = []
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :passed)
      expected_metrics = []
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a scenario with only steps that have no results' do
      scenario[:steps] << {}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :passed)
      expected_metrics = []
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a scenario with only steps that have no duration' do
      scenario[:steps] << {:result => {}}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :passed)
      expected_metrics = []
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a step with no result' do
      scenario[:steps] << {}
      scenario[:steps] << {:result => {:duration => 1.5}}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :passed)
      expected_metrics = [
        {:path => "example-metrics-prefix.example-scenario-id.duration", :value => 1.5},
        {:path => "example-metrics-prefix.example-scenario-id.step-2.duration", :value => 1.5}
      ]
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a step with no duration' do
      scenario[:steps] << {:result => {}}
      scenario[:steps] << {:result => {:duration => 1.5}}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :passed)
      expected_metrics = [
        {:path => "example-metrics-prefix.example-scenario-id.duration", :value => 1.5},
        {:path => "example-metrics-prefix.example-scenario-id.step-2.duration", :value => 1.5}
      ]
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a failed scenario' do
      scenario[:steps] << {:result => {:duration => 0.5}}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :failed)
      expected_metrics = []
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a pending scenario' do
      scenario[:steps] << {:result => {:duration => 0.5}}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :pending)
      expected_metrics = []
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores an undefined scenario' do
      scenario[:steps] << {:result => {:duration => 0.5}}
      metrics = check_cucumber.generate_metrics_from_scenario(scenario, :undefined)
      expected_metrics = []
      expect(metrics).to eq(expected_metrics)
    end
  end
end

def generate_feature(options = {})
  feature_index = options[:feature_index] || 0
  feature = {
      :id => "Feature-#{feature_index}",
      :name => "Feature #{feature_index}",
      :description => "This is Feature #{feature_index}",
      :line => 1,
      :keyword => "Feature",
      :uri => "features/feature-#{feature_index}.feature",
      :elements => []
  }

  scenario_index = 0

  Array(options[:scenarios]).each do |scenario_options|
    scenario = {
      :name => "Scenario #{scenario_index}",
      :id => "#{feature[:id]};scenario-#{scenario_index}",
      :line => 3,
      :keyword => "Scenario #{scenario_index}",
      :description => "This is Scenario #{scenario_index}",
      :type => "scenario",
      :steps => []
    }

    step_index = 0

    Array(scenario_options[:step_statuses]).each do |step_status|
      scenario[:steps] << {
        :name => "a passing pre-condition",
        :line => 4 + step_index,
        :keyword => "Given ",
        :result => {
          :duration => step_index + 0.5,
          :status => step_status.to_s
        },
        :match => {}
      }
      step_index += 1
    end

    feature[:elements] << scenario
    scenario_index += 1
  end

  feature
end

def deep_dup(obj)
  Marshal.load(Marshal.dump(obj))
end

def generate_sensu_event(options = {})
  feature_index = options[:feature_index] || 0
  scenario_index = options[:scenario_index] || 0

  feature = deep_dup(options[:report][feature_index])
  scenario = feature[:elements][scenario_index]
  feature[:elements] = [scenario]

  metrics = []

  if options[:status] == :passed
    scenario_duration = 0

    scenario[:steps].each.with_index do |step, step_index|
      metrics << {
        :path => "example-metrics-prefix.Feature-#{feature_index}.scenario-#{scenario_index}.step-#{step_index + 1}.duration",
        :value => step[:result][:duration]
      }
      scenario_duration += step[:result][:duration]
    end

    metrics.unshift({
      :path => "example-metrics-prefix.Feature-#{feature_index}.scenario-#{scenario_index}.duration",
      :value => scenario_duration
    })
  end

  data = {
    :status => options[:status],
    :report => [feature],
    :metrics => metrics
  }

  status_code_map = {
    :passed => 0,
    :failed => 2,
    :pending => 1,
    :undefined => 1
  }

  sensu_event = {
    :handlers => ['example-handler'],
    :name => "example-name.Feature-#{feature_index}.scenario-#{scenario_index}",
    :output => data.to_json,
    :status => status_code_map[options[:status]]
  }

  sensu_event
end
