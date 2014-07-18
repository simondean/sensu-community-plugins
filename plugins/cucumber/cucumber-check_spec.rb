require_relative 'cucumber-check'
require_relative '../../spec_helper'

describe CucumberCheck, 'run' do

  it 'returns unknown if there are no features specified' do
    cucumber_check = CucumberCheck.new
    cucumber_check.should_receive('unknown').with('No features path specified')
    cucumber_check.run
  end

end
