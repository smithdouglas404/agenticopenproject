# frozen_string_literal: true

module FormFields
  module Primerized
    class BlockNoteEditorInput
      include Capybara::DSL

      def open_add_image_dialog
        editor = page.find("div[role='textbox']")
        editor.send_keys("/image")
        editor.send_keys(:enter)
      end

      def open_command_dialog
        editor = page.find("div[role='textbox']")
        editor.send_keys("/")
      end
    end
  end
end
