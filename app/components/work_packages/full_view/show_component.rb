# frozen_string_literal: true

module WorkPackages
  module FullView
    class ShowComponent < ApplicationComponent
      include OpPrimer::ComponentHelpers
      include OpTurbo::Streamable
      include Redmine::MenuManager::MenuHelper

      def self.wrapper_key = :"work-package-full-view"

      def initialize(id:, tab: "activity")
        super

        @id = id
        @tab = tab
        @work_package = WorkPackage.visible.find_by(id:)
        @project = @work_package.project
      end

      def wrapper_uniq_by
        @id
      end

      def all_tabs
        @tabs ||=
          Redmine::MenuManager
            .items(:work_package_split_view, nil)
            .root
            .children
            .select do |node|
            allowed_node?(node, User.current, @project) && visible_node?(:work_package_split_view, node)
          end
      end

      def active?(node)
        @tab == node.name.to_s
      end

      def counter_for(node)
        node.badge(work_package: @work_package).to_i
      end
    end
  end
end
