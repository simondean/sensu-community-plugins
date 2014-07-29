require_relative 'check-cucumber-features'
require_relative '../../spec_helper'

describe CheckCucumberFeatures, 'run' do
  check_cucumber_features = nil

  before(:each) do
    check_cucumber_features = CheckCucumberFeatures.new
  end

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