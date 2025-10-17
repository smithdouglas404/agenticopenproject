# frozen_string_literal: true

class SetAnonymousUserThemeToSyncWithOs < ActiveRecord::Migration[8.0]
  def up
    anonymous_user = User.anonymous
    return unless anonymous_user

    pref = anonymous_user.pref
    return unless pref

    pref.settings["theme"] = "sync_with_os"
    pref.save!
  end

  def down
    anonymous_user = User.anonymous
    return unless anonymous_user

    pref = anonymous_user.pref
    return unless pref

    pref.settings["theme"] = "light"
    pref.save!
  end
end
