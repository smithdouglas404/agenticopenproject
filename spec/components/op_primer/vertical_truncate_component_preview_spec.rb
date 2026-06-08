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

require "rails_helper"
require Rails.root.join("lookbook/previews/op_primer/vertical_truncate_component_preview").to_s

RSpec.describe OpPrimer::VerticalTruncateComponentPreview, type: :component do
  # TODO: replace this path shim with a cleaner mechanism for exercising
  # lookbook previews in specs (e.g. a shared support helper).
  #
  # Lookbook is disabled in the test environment, so its preview path (which hosts the
  # `render_with_template` ERB files) is not registered. Register it for these examples so
  # `render_preview` can resolve the templates, then restore the original paths.
  around do |example|
    path = Rails.root.join("lookbook/previews").to_s
    paths = ViewComponent::Base.previews.paths
    added = paths.exclude?(path)
    paths << path if added
    begin
      example.run
    ensure
      paths.delete(path) if added
    end
  end

  it "renders the default preview with a configurable line count" do
    render_preview(:default, from: described_class, params: { lines: 4 })

    expect(page).to have_css("div.op-vertical-truncate.op-vertical-truncate--lines-4")
  end
end
