# frozen_string_literal: true

require 'rspec'

Dir[File.join(__dir__, 'support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Чтобы тесты были стабильнее по времени (если где-то Time.now)
  config.disable_monkey_patching!
end
