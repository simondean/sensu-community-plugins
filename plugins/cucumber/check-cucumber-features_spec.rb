require_relative 'check-cucumber-features'
require_relative '../../spec_helper'

describe CheckCucumberFeatures do
  check_cucumber_features = nil

  before(:each) do
    check_cucumber_features = CheckCucumberFeatures.new
  end

  describe 'run()' do
    #it 'returns unknown if there are no features specified' do
    #  check_cucumber_features.should_receive('unknown').with('No features path specified')
    #  check_cucumber_features.run
    #end
    #
    #describe 'when features are specified' do
    #  before do
    #    check_cucumber_features.config[:features] = 'test_assets/features/'
    #  end

    it 'returns unknown if no cucumber command line is specified' do
      check_cucumber_features.should_receive('unknown').with('No cucumber command line specified')
      check_cucumber_features.run
    end

    describe 'when the Cucumber command line is specified' do
      before(:each) do
        check_cucumber_features.config[:command] = 'cucumber-js features/'
      end

      it 'returns ok if features are executed successfully' do
        check_cucumber_features.should_receive('execute_cucumber_features') { {:report => [], :exit_status => 0} }
        check_cucumber_features.should_receive('ok').with(no_args)
        check_cucumber_features.run
      end

      describe 'when there is an undefined step' do
        report = []

        before(:each) do
          report.push generate_feature(:undefined)
        end

        it 'returns warning' do
          check_cucumber_features.should_receive('execute_cucumber_features') do
            {:report => report, :exit_status => 0}
          end
          check_cucumber_features.should_receive('warning').with(no_args)
          check_cucumber_features.run
        end

        it 'still returns warning if another step is passing' do
          report.push generate_feature(:passing)
          check_cucumber_features.should_receive('execute_cucumber_features') do
            {:report => report, :exit_status => 0}
          end
          check_cucumber_features.should_receive('warning').with(no_args)
          check_cucumber_features.run
        end
      end

      describe 'when there is a pending step' do
        report = []

        before(:each) do
          report.push generate_feature(:pending)
        end

        it 'returns warning' do
          check_cucumber_features.should_receive('execute_cucumber_features') do
            {:report => report, :exit_status => 0}
          end
          check_cucumber_features.should_receive('warning').with(no_args)
          check_cucumber_features.run
        end

        it 'still returns warning if another step is passing' do
          report.push generate_feature(:passing)
          check_cucumber_features.should_receive('execute_cucumber_features') do
            {:report => report, :exit_status => 0}
          end
          check_cucumber_features.should_receive('warning').with(no_args)
          check_cucumber_features.run
        end
      end

      describe 'when there is a failed step' do
        report = []

        before(:each) do
          report.push generate_feature(:failed)
        end

        it 'returns critical' do
          check_cucumber_features.should_receive('execute_cucumber_features') do
            {:report => report, :exit_status => 0}
          end
          check_cucumber_features.should_receive('critical').with(no_args)
          check_cucumber_features.run
        end

        it 'still returns critical if another step is passing' do
          report.push generate_feature(:passing)
          check_cucumber_features.should_receive('execute_cucumber_features') do
            {:report => report, :exit_status => 0}
          end
          check_cucumber_features.should_receive('critical').with(no_args)
          check_cucumber_features.run
        end

        it 'still returns critical if another step is undefined' do
          report.push generate_feature(:undefined)
          check_cucumber_features.should_receive('execute_cucumber_features') do
            {:report => report, :exit_status => 0}
          end
          check_cucumber_features.should_receive('critical').with(no_args)
          check_cucumber_features.run
        end

        it 'still returns critical if another step is pending' do
          report.push generate_feature(:pending)
          check_cucumber_features.should_receive('execute_cucumber_features') do
            {:report => report, :exit_status => 0}
          end
          check_cucumber_features.should_receive('critical').with(no_args)
          check_cucumber_features.run
        end
      end
    end
  #  end
  end

  describe 'generate_check_name_from_scenario()' do
    it 'returns the scenario id' do
      scenario = {:id => 'text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces a forward slash with a period' do
      scenario = {:id => 'text/text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'replaces multiple forward slashes with periods' do
      scenario = {:id => 'text/text/text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text.text')
    end

    it 'does not replace hyphens' do
      scenario = {:id => 'text-text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text-text')
    end

    it 'does not replace periods' do
      scenario = {:id => 'text.text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'replaces every character (except letters, periods and hyphens) with hyphen' do
      id = ''
      (1..254).each {|ascii_code| id += ascii_code.chr}

      scenario = {:id => id}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ-_-abcdefghijklmnopqrstuvwxyz')
    end

    it 'avoid consecutive periods' do
      scenario = {:id => 'text//text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the start' do
      scenario = {:id => '-text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple hyphens at the start' do
      scenario = {:id => '--text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes a hyphen at the end' do
      scenario = {:id => 'text-'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple hyphens at the end' do
      scenario = {:id => 'text--'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces consecutive hyphens with a single hyphen' do
      scenario = {:id => 'text--text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text-text')
    end

    it 'removes a period at the start' do
      scenario = {:id => '.text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple periods at the start' do
      scenario = {:id => '..text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes a period at the end' do
      scenario = {:id => 'text.'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'removes multiple periods at the end' do
      scenario = {:id => 'text..'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text')
    end

    it 'replaces consecutive periods with a single period' do
      scenario = {:id => 'text..text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the start of a part' do
      scenario = {:id => 'text.-text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes multiple hyphens at the start of a part' do
      scenario = {:id => 'text.--text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes a hyphen at the end of a part' do
      scenario = {:id => 'text.-text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end

    it 'removes multiple hyphens at the end of a part' do
      scenario = {:id => 'text.--text'}
      check_name = check_cucumber_features.generate_check_name_from_scenario(scenario)
      expect(check_name).to eq('text.text')
    end
  end
end

def generate_feature(status)
  feature = {
        :elements => [
          {
            :steps => [
              {
                :result => {
                  :status => status.to_s
                }
              }
            ]
          }
        ]
      }

  feature
end