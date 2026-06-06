# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Documents
  module VersionsTab
    class ItemComponent < ApplicationComponent
      include ApplicationHelper
      include OpPrimer::ComponentHelpers
      include OpTurbo::Streamable

      alias_method :journal, :model

      options :document, :max_version

      def author
        journal.user
      end

      def latest?
        journal.version == max_version
      end

      def version_url
        return document_path(document) if latest?

        document_path(document, version: journal.id)
      end

      def content_changed?
        journal.version == 1 ||
          journal.details.key?("content_binary") ||
          journal.details.key?("description")
      end

      def change_details
        return [I18n.t("documents.versions.created")] if journal.version == 1

        details = []
        details << I18n.t("documents.versions.content_updated") if journal.details.key?("content_binary")
        details << I18n.t("documents.versions.description_updated") if journal.details.key?("description")
        details << I18n.t("documents.versions.title_updated") if journal.details.key?("title")
        details << I18n.t("documents.versions.type_updated") if journal.details.key?("type_id")
        details
      end

      def version_label
        label = I18n.t("documents.versions.version_label", version: journal.version)
        label += " (#{I18n.t('documents.versions.current')})" if latest?
        label
      end
    end
  end
end
