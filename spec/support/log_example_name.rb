# frozen_string_literal: true

require "colored2"

class LogSpecNameFormatter
  RSpec::Core::Formatters.register self, :start, :example_started, :example_passed, :example_pending, :example_failed

  RULE = "=" * 80
  BIG_RULE = "#" * 80

  def initialize(*args); end

  def start(notification)
    log(BIG_RULE, ["", "RSpec", "Starting #{notification.count} examples".bold, "Time: #{Time.current}", ""], BIG_RULE)
  end

  def example_started(notification)
    log_start("rspec example started",
              notification.example.full_description,
              notification.example.location)
  end

  def example_passed(notification)
    log_end("rspec example passed".green.bold,
            notification.example.full_description)
  end

  def example_pending(notification)
    log_end("rspec example pending".yellow.bold,
            notification.example.full_description)
  end

  def example_failed(notification)
    log_end("rspec example failed".red.bold,
            notification.example.full_description,
            "bundle exec rspec #{notification.example.location}")
  end

  private

  def log_start(*messages)
    log(RULE, messages, "")
  end

  def log_end(*messages)
    log("", messages, RULE)
  end

  def log(header, messages, footer)
    lines = [
      header,
      *messages.map { "== #{it}" },
      footer
    ]
    Rails.logger.info lines.join("\n")
  end
end

RSpec.configure do |config|
  # outputs each rspec example description and result to rails test.log
  config.before(:suite) do
    config.add_formatter(LogSpecNameFormatter)
  end
end
