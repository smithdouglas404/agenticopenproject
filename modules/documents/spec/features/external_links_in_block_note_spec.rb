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

RSpec.describe "External links in BlockNote editor",
               :js,
               :selenium,
               with_settings: { real_time_text_collaboration_enabled: true } do
  include_context "with hocuspocus"

  let(:admin) { create(:admin) }
  let(:document) { create(:document, :collaborative) }
  let(:editor) { FormFields::Primerized::BlockNoteEditorInput.new }

  before do
    login_as(admin)
    visit document_path(document)
  end

  it "editor remains interactive after ExternalLinksController connects" do
    expect(page).to have_test_selector("blocknote-document-description")
    editor.fill_in("Hello from the editor")
    expect(editor.content).to include("Hello from the editor")

    editor.element.send_keys(:enter)
    editor.fill_in("Still typing just fine")
    expect(editor.content).to include("Still typing just fine")
  end

  it "sets target and rel attributes on external links in the shadow DOM" do
    editor.paste_links(text: "Example Site", url: "https://example.com")

    link = editor.shadow_root.find("a[target='_blank']", text: "Example Site", wait: 5)
    expect(link[:rel]).to include("noopener")
    expect(link[:rel]).to include("noreferrer")
  end

  it "does not set aria-describedby inside contenteditable to avoid ProseMirror re-render loop" do
    editor.paste_links(text: "Accessible Link", url: "https://example.com")

    link = editor.shadow_root.find("a[target='_blank']", text: "Accessible Link", wait: 5)
    expect(link[:"aria-describedby"]).to be_nil.or eq("")
  end

  it "does not freeze when pasting content with multiple external links" do
    editor.paste_links(
      { text: "Link One", url: "https://example.com/one" },
      { text: "Link Two", url: "https://example.org/two" },
      { text: "Link Three", url: "https://other-site.com/three" },
      { text: "Link Four", url: "https://fourth-domain.net/four" },
      { text: "Link Five", url: "https://fifth-place.io/five" }
    )

    # Verify the editor remains interactive after pasting multiple links
    editor.fill_in(" Still typing after paste")
    expect(editor.content).to include("Still typing after paste")
  end

  it "does not rewrite internal links" do
    editor.paste_links(text: "Internal Link", url: root_url)

    link = editor.shadow_root.find("a", text: "Internal Link", wait: 5)
    expect(link.native.property("href")).not_to include("/external_redirect")
  end

  context "with capture enabled",
          with_ee: %i[capture_external_links],
          with_settings: {
            real_time_text_collaboration_enabled: true,
            capture_external_links: true
          } do
    it "rewrites external link href to /external_redirect" do
      editor.paste_links(text: "Captured Link", url: "https://example.com/page")

      link = editor.shadow_root.find("a[target='_blank']", text: "Captured Link", wait: 5)
      expect(link.native.property("href")).to include("/external_redirect?url=")
      expect(link.native.property("href")).to include("example.com")
    end
  end
end
