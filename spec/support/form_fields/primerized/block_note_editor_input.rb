# frozen_string_literal: true

module FormFields
  module Primerized
    class BlockNoteEditorInput
      include Capybara::DSL

      def open_add_image_dialog
        editor = find_editor
        editor.send_keys("/image")
        editor.send_keys(:enter)
      end

      def open_command_dialog
        find_editor.send_keys("/")
      end

      def fill_in_with_content(content)
        editor = find_editor
        editor.send_keys(content)
      end
    end
  end
end
