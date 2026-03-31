# frozen_string_literal: true

RSpec.configure do |c|
  c.before(:each, content_type: :json, type: :request) do |_ex|
    header("Content-Type", "application/json")
  end
end
