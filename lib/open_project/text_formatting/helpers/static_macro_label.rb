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

module OpenProject::TextFormatting
  module Helpers
    # Composes the anchor text for a work-package quickinfo macro rendered
    # in a static-HTML channel (mailers, server-side previews) — channels
    # that cannot hydrate the JS-driven `<opce-macro-wp-quickinfo>` widget
    # and so flatten the macro to an `<a>` whose text must carry enough
    # context for a reader to recognise the reference: type, optional
    # status, the identifier label, and the subject.
    #
    # Shared between the text-reference path (`LinkHandlers::WorkPackages`)
    # and the envelope path (`Filters::MentionFilter`) so both render the
    # same shape for the same WP.
    module StaticMacroLabel
      def self.call(work_package, label:, detailed:)
        parts = []
        parts << work_package.status&.name if detailed
        parts << work_package.type&.name
        parts << label
        "#{parts.compact.join(' ')}: #{work_package.subject}"
      end
    end
  end
end
