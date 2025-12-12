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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module CustomFields
  module Details
    class BaseForm < ApplicationForm
      ALLOWED_SUPPORTED_FORMATS_OPERATORS = %i[only except].freeze
      private_constant :ALLOWED_SUPPORTED_FORMATS_OPERATORS

      delegate :supported_formats_config, to: :class, private: true

      class << self
        def supports_formats(config = {})
          @supported_formats_config = config.transform_values { |formats| Array(formats).map(&:to_sym) }
        end

        def supported_formats_config
          @supported_formats_config ||= {}
        end
      end

      def render?
        supported_format?
      end

      private

      def instructions_for(attribute)
        I18n.t(attribute, scope: %i[custom_fields instructions])
      end

      def supported_format?
        @supported_format ||= begin
          field_format = model.field_format.to_sym
          case supported_formats_config
          in { only: } then only.include?(field_format)
          in { except: } then except.exclude?(field_format)
          else true
          end
        end
      end
    end
  end
end
