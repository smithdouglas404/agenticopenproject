# frozen_string_literal: true

#-- copyright
#++

module Storages
  module Adapters
    module Providers
      module Sharepoint
        module Commands
          class CreateListCommand < Base
            def call(auth_strategy:, input_data:)
              Authentication[auth_strategy].call(storage: @storage) do |_http|
                create_list(input_data).bind do |list_json|
                  get_drive_id(list_json).bind { parse_response(it) }
                end
              end
            end

            private

            def create_list(input_data)
              handle_response(http.post(request_uri, json: payload(input_data)))
            end

            def get_lists
              # Internal::ListsQuery =>
            end

            def handle_response(response)
              error = Results::Error.new(source: self.class, payload: response)

              case response
              in { status: 200 }
                Success(response.json(symbolize_keys: true))
              else
                Failure(error.with(code: :error))
              end
            end

            def payload(input_data)
              { displayName: input_data.name,
                description: input_data.description,
                list: { template: "documentLibrary" } }
            end

            def request_uri
              endpoint_uri = UrlBuilder.url(base_uri, "/v1.0/sites", host_uri.host)
              "#{endpoint_uri}:#{site_path}:/lists"
            end
          end
        end
      end
    end
  end
end
