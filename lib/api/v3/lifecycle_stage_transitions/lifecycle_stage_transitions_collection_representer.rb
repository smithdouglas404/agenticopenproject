# frozen_string_literal: true

module API
  module V3
    module LifecycleStageTransitions
      class LifecycleStageTransitionsCollectionRepresenter < ::API::Decorators::UnpaginatedCollection
        element_decorator ::API::V3::LifecycleStageTransitions::LifecycleStageTransitionRepresenter
      end
    end
  end
end
