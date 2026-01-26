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

module Admin
  module Jiras
    class Form < ApplicationForm
      form do |client_form|
        client_form.text_field(
          name: :name,
          label: Jira.human_attribute_name(:name),
          required: true,
          input_width: :medium
        )

        client_form.text_field(
          name: :url,
          label: Jira.human_attribute_name(:url),
          required: true,
          input_width: :large,
          type: :url
        )

        client_form.text_field(
          name: :personal_access_token,
          label: Jira.human_attribute_name(:personal_access_token),
          required: true,
          input_width: :large
        )

        client_form.submit(
          name: :submit,
          label: model.persisted? ? I18n.t("admin.jira.form.button_save") : I18n.t("admin.jira.form.button_add"),
          scheme: :primary
        )
      end
    end
  end
end
