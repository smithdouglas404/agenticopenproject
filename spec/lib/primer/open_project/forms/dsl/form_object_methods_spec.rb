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
#
require "spec_helper"

RSpec.describe Primer::OpenProject::Forms::Dsl::FormObjectMethods, type: :forms do
  let(:form_object) { Primer::Forms::Dsl::FormObject.extend(described_class) }
  let(:builder) { instance_double(ActionView::Helpers::FormBuilder, object: model) }
  let(:form) { instance_double(ApplicationForm, model:, caption_template?: false) }
  let(:form_dsl) { form_object.new(builder:, form:) }

  let(:options) { {} }

  let(:model) { build_stubbed(:project) }

  subject(:field) { field_group.first }

  shared_examples_for "input class" do |input_class|
    it "instantiates correct input class" do
      expect(field).to be_a(input_class)
    end
  end

  describe "#fieldset_group" do
    let(:field_group) { form_dsl.fieldset_group(title: "Title", **options) }

    include_examples "input class", Primer::OpenProject::Forms::Dsl::FieldsetInputGroup
  end
end
