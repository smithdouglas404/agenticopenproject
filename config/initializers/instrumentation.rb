ActiveSupport::Notifications
  .monotonic_subscribe("each_iteration.iteration") do |_, started, finished, _, tags|
  elapsed = finished - started

  max_iteration_runtime = 10.seconds
  if elapsed >= max_iteration_runtime
    Rails.logger.warn "[Iteration] job_class=#{tags[:job_class]} " \
    "each_iteration runtime exceeded limit of #{max_iteration_runtime}s"
  end
end
