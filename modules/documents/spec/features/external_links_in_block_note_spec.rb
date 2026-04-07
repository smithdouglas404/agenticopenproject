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
    paste_link_into_editor(text: "Example Site", url: "https://example.com")

    link = editor.shadow_root.find("a[target='_blank']", text: "Example Site", wait: 5)
    expect(link[:rel]).to include("noopener")
    expect(link[:rel]).to include("noreferrer")
  end

  it "sets aria-describedby on external links for accessibility" do
    paste_link_into_editor(text: "Accessible Link", url: "https://example.com")

    link = editor.shadow_root.find("a[target='_blank']", text: "Accessible Link", wait: 5)
    expect(link[:"aria-describedby"]).to include("open-blank-target-link-description")
  end

  it "does not rewrite internal links" do
    paste_link_into_editor(text: "Internal Link", url: root_url)

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
      paste_link_into_editor(text: "Captured Link", url: "https://example.com/page")

      link = editor.shadow_root.find("a[target='_blank']", text: "Captured Link", wait: 5)
      expect(link.native.property("href")).to include("/external_redirect?url=")
      expect(link.native.property("href")).to include("example.com")
    end
  end

  private

  # Simulates pasting a link into the BlockNote editor — a common user interaction
  # (e.g. copying a link from an email or browser and pasting it into a document).
  #
  # We use a synthetic ClipboardEvent because the alternative (Ctrl+K) requires the
  # formatting toolbar to be visible, which only happens when text is selected.
  # There is no reliable way to programmatically select text inside ProseMirror's
  # contenteditable in Capybara/Selenium tests. The synthetic event exercises the
  # same ProseMirror paste handler code path as a real Ctrl+V.
  def paste_link_into_editor(text:, url:)
    expect(page).to have_test_selector("blocknote-document-description")
    editor.element.click

    page.execute_script(<<~JS, url, text)
      const el = document.querySelector('op-block-note').shadowRoot.querySelector('div[role="textbox"]');
      const dt = new DataTransfer();
      dt.setData('text/html', `<a href="${arguments[0]}">${arguments[1]}</a>`);
      dt.setData('text/plain', arguments[1]);
      el.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
    JS
  end
end
