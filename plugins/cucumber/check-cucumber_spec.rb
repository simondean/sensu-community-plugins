require_relative 'check-cucumber'
require_relative '../../spec_helper'

describe CheckCucumber do
  check_cucumber = nil

  before(:each) do
    check_cucumber = CheckCucumber.new
  end

  describe 'run()' do
    it 'returns unknown if no name is specified' do
      check_cucumber.should_receive('unknown').with('No name specified')
      check_cucumber.run
    end

    describe 'when the name is specified' do
      before(:each) do
        check_cucumber.config[:name] = 'example-name'
      end

      it 'returns unknown if no handler is specified' do
        check_cucumber.should_receive('unknown').with('No handler specified')
        check_cucumber.run
      end

      describe 'when the handler is specified' do
        before(:each) do
          check_cucumber.config[:handler] = 'example-handler'
        end

        it 'returns unknown if no cucumber command line is specified' do
          check_cucumber.should_receive('unknown').with('No cucumber command line specified')
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
              check_cucumber.should_receive('execute_cucumber') do
                {:report => report, :exit_status => 0}
              end
            end

            describe 'when there are no steps' do
              it 'returns ok' do
                check_cucumber.should_receive('ok').with('OK: 0 scenarios')
              end
            end

            describe 'when there is a passing step' do
              before(:each) do
                report << generate_feature(:scenario_statuses => :passed, :scenario_id => 'Feature;scenario')
              end

              it 'returns ok' do
                check_cucumber.should_receive('ok').with('OK: 1 scenario')
              end

              it 'raises an ok event' do
                sensu_event = {
                  :handlers => ['example-handler'],
                  :name => 'example-name.Feature.scenario',
                  :output => '',
                  :status => 0
                }
                check_cucumber.should_receive('raise_sensu_event').with(sensu_event)
              end
            end

            describe 'when there is a passing step followed by a failing step' do
              before(:each) do
                report << generate_feature(:scenario_statuses => [:passed, :failed], :scenario_id => 'Feature;scenario')
              end

              it 'returns ok' do
                check_cucumber.should_receive('ok').with('OK: 1 scenario')
              end

              it 'raises a critical event' do
                sensu_event = {
                  :handlers => ['example-handler'],
                  :name => 'example-name.Feature.scenario',
                  :output => '',
                  :status => 2
                }
                check_cucumber.should_receive('raise_sensu_event').with(sensu_event)
              end
            end

            describe 'when there is a passing step followed by a pending step' do
              before(:each) do
                report << generate_feature(:scenario_statuses => [:passed, :pending], :scenario_id => 'Feature;scenario')
              end

              it 'returns ok' do
                check_cucumber.should_receive('ok').with('OK: 1 scenario')
              end

              it 'raises a warning event' do
                sensu_event = {
                  :handlers => ['example-handler'],
                  :name => 'example-name.Feature.scenario',
                  :output => '',
                  :status => 1
                }
                check_cucumber.should_receive('raise_sensu_event').with(sensu_event)
              end
            end

            describe 'when there is a passing step followed by a undefined step' do
              before(:each) do
                report << generate_feature(:scenario_statuses => [:passed, :undefined], :scenario_id => 'Feature;scenario')
              end

              it 'returns ok' do
                check_cucumber.should_receive('ok').with('OK: 1 scenario')
              end

              it 'raises a warning event' do
                sensu_event = {
                  :handlers => ['example-handler'],
                  :name => 'example-name.Feature.scenario',
                  :output => '',
                  :status => 1
                }
                check_cucumber.should_receive('raise_sensu_event').with(sensu_event)
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

  describe 'generate_check_name_from_scenario()' do
    it 'returns the scenario id' do
      scenario = {:id => 'text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces a semi colon with a period' do
      scenario = {:id => 'text;text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'replaces multiple semi colons with periods' do
      scenario = {:id => 'text;text;text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text.text')
    end

    it 'does not replace hyphens' do
      scenario = {:id => 'text-text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text-text')
    end

    it 'does not replace periods' do
      scenario = {:id => 'text.text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'replaces every character (except letters, periods, hyphens and underscores) with hyphen' do
      id = ''
      (1..254).each {|ascii_code| id += ascii_code.chr}

      scenario = {:id => id}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('0123456789.ABCDEFGHIJKLMNOPQRSTUVWXYZ-_-abcdefghijklmnopqrstuvwxyz')
    end

    it 'avoid consecutive periods' do
      scenario = {:id => 'text;;text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the start' do
      scenario = {:id => '-text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple hyphens at the start' do
      scenario = {:id => '--text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes a hyphen at the end' do
      scenario = {:id => 'text-'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple hyphens at the end' do
      scenario = {:id => 'text--'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces consecutive hyphens with a single hyphen' do
      scenario = {:id => 'text--text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text-text')
    end

    it 'removes a period at the start' do
      scenario = {:id => '.text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple periods at the start' do
      scenario = {:id => '..text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes a period at the end' do
      scenario = {:id => 'text.'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple periods at the end' do
      scenario = {:id => 'text..'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces consecutive periods with a single period' do
      scenario = {:id => 'text..text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the start of a part' do
      scenario = {:id => 'text.-text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes multiple hyphens at the start of a part' do
      scenario = {:id => 'text.--text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the end of a part' do
      scenario = {:id => 'text.-text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes multiple hyphens at the end of a part' do
      scenario = {:id => 'text.--text'}
      check_name = check_cucumber.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end
  end
end

def generate_feature(options = {})
  feature = {
        :elements => [
          {
            :id => options[:scenario_id],
            :steps => []
          }
        ]
      }

  Array(options[:scenario_statuses]).each do |scenario_status|
    feature[:elements][0][:steps] << {
      :result => {
        :status => scenario_status.to_s
      }
    }
  end

  feature
end
