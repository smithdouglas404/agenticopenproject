module Webhooks
  module Outgoing
    class RequestWebhookService
      include ::OpenProjectErrorHelper

      attr_reader :current_user, :event_name, :webhook

      def initialize(webhook, event_name:, current_user:)
        @current_user = current_user
        @webhook = webhook
        @event_name = event_name
      end

      def call!(body:, headers:)
        begin
          response = OpenProject::SsrfProtection.post(
            webhook.url,
            headers:,
            body:
          )
        rescue StandardError => e
          op_handle_error(e.message, reference: :webhook_job)
          exception = e
        end

        log!(body:, headers:, response:, exception:)

        # We want to re-raise timeout exceptions
        # but log the request beforehand
        raise exception if exception.is_a?(Net::OpenTimeout) || exception.is_a?(Net::ReadTimeout)
      end

      def log!(body:, headers:, response:, exception:)
        log = ::Webhooks::Log.new(
          webhook:,
          event_name:,
          url: webhook.url,
          request_headers: headers,
          request_body: body,
          **response_attributes(response:, exception:)
        )

        unless log.save
          OpenProject.logger.error("Failed to save webhook log: #{log.errors.full_messages.join('. ')}")
        end
      end

      def response_attributes(response:, exception:)
        {
          response_code: response&.code&.to_i || -1,
          response_headers: response&.to_hash&.transform_keys { |k| k.underscore.to_sym },
          response_body: response&.body || exception&.message
        }
      end
    end
  end
end
