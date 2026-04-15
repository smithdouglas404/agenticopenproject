# frozen_string_literal: true

FactoryBot.define do
  factory :long_running_task do
    task_type { :semantic_id_conversion }
  end
end
