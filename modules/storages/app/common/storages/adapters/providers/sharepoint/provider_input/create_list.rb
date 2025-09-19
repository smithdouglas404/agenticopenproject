# frozen_string_literal: true

#-- copyright
#++

module Storages
  module Adapters
    module Providers
      module Sharepoint
        module ProviderInput
          CreateList = Data.define(:name, :description) do
            def initialize(name:, description: nil) = super
          end
        end
      end
    end
  end
end
