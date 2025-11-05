# frozen_string_literal: true

class EnsureAnonymousUserPreferenceExistsAndSetTheme < ActiveRecord::Migration[8.0]
  def up
    say "Ensure anonymous user has preferences and set theme to sync_with_os"

    execute <<~SQL.squish
      DO $$
      DECLARE
        anon_id INTEGER;
      BEGIN
        SELECT id INTO anon_id FROM users WHERE type = 'AnonymousUser' LIMIT 1;

        IF anon_id IS NOT NULL THEN
          IF EXISTS (SELECT 1 FROM user_preferences WHERE user_id = anon_id) THEN
            UPDATE user_preferences
            SET settings = settings || '{"theme": "sync_with_os"}'::jsonb,
                updated_at = NOW()
            WHERE user_id = anon_id;
          ELSE
            INSERT INTO user_preferences (user_id, settings, created_at, updated_at)
            VALUES (anon_id, '{"theme": "sync_with_os"}'::jsonb, NOW(), NOW());
          END IF;
        END IF;
      END
      $$;
    SQL
  end

  def down
    say "Rollback: reset anonymous user theme to light"

    execute <<~SQL.squish
      DO $$
      DECLARE
        anon_id INTEGER;
      BEGIN
        SELECT id INTO anon_id FROM users WHERE type = 'AnonymousUser' LIMIT 1;

        IF anon_id IS NOT NULL THEN
          UPDATE user_preferences
          SET settings = settings || '{"theme": "light"}'::jsonb,
              updated_at = NOW()
          WHERE user_id = anon_id;
        END IF;
      END
      $$;
    SQL
  end
end
