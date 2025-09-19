# frozen_string_literal: true

#-- copyright
#++

require "spec_helper"
require_module_spec_helper

module Storages
  module Adapters
    module Providers
      module Sharepoint
        module Commands
          RSpec.describe CreateListCommand, :webmock do
            let(:input_data) do
              ProviderInput::CreateList.new(
                name: "OpenProject Test",
                description: "A document library used in testing the Create List Command"
              )
            end

            let(:auth_strategy) { Registry["sharepoint.authentication.userless"].call }

            it "creates a list"
            it "returns a Results::File for the list drive"

            describe "error handling" do
              it "returns a conflict error if a list wiht the same name already exists"
            end

            private

            def delete_created_list(name)
              # fetch lists ids
              # issue a delete on the list id
              # list id != drive id
              name
            end
          end
        end
      end
    end
  end
end
