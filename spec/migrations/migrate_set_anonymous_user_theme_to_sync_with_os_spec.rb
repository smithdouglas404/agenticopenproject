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

require "spec_helper"
require Rails.root.join("db/migrate/20251017111720_set_anonymous_user_theme_to_sync_with_os.rb")

RSpec.describe SetAnonymousUserThemeToSyncWithOs, type: :model do
  let(:anonymous_user) { User.anonymous }
  let(:pref) { anonymous_user.pref }

  describe "up migration" do
    it "sets the anonymous user theme to sync_with_os" do
      # Simulate default theme before migration
      pref.settings["theme"] = "light"
      pref.save!

      ActiveRecord::Migration.suppress_messages { described_class.migrate(:up) }

      pref.reload
      expect(pref.settings["theme"]).to eq("sync_with_os")
      expect(pref.sync_with_os_theme?).to be true
    end
  end

  describe "down migration" do
    it "reverts the anonymous user theme back to light" do
      pref.settings["theme"] = "sync_with_os"
      pref.save!

      ActiveRecord::Migration.suppress_messages { described_class.migrate(:down) }

      pref.reload
      expect(pref.settings["theme"]).to eq("light")
    end
  end
end
